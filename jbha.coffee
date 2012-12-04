# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

_            = require "underscore"
async        = require "async"
http         = require "http"
colors       = require "colors"
cheerio      = require "cheerio"
mongoose     = require "mongoose"
moment       = require "moment"
querystring  = require "querystring"

logging      = require "./logging"
secrets      = require "./secrets"

if process.env.NODE_ENV is "production"
  mongo_uri = secrets.MONGO_PRODUCTION_URI
else
  mongo_uri = secrets.MONGO_STAGING_URI

mongoose.connect mongo_uri, () ->
  # console.log "Connection established"

String::capitalize = ->
  @charAt(0).toUpperCase() + @slice 1

AccountSchema = new mongoose.Schema
  _id: String
  nickname: String
  is_new:
    type: Boolean
    default: true
  firstrun:
    type: Boolean
    default: true
  details:
    type: Boolean
    default: true
  migrate:
    type: Boolean
    default: false
  feedback_given:
    type: Boolean
    default: false
  updated: # Start off at the beginning of UNIX time so it's initially stale.
    type: Date
    default: new Date 0
  {strict: true}

Account = mongoose.model 'account', AccountSchema

# jbha_id is the content id for a course
# or assignment on the jbha.org website's
# database. It is used as a unique index
# to ensure that doing a fetch does not
# result in duplicates being stored.
CourseSchema = new mongoose.Schema
  owner: String
  title: String
  teacher: String
  jbha_id:
    type: String
    index:
      unique: false
      sparse: true
  assignments: [{ type: mongoose.Schema.ObjectId, ref: 'assignment' }]

Course = mongoose.model 'course', CourseSchema

AssignmentSchema = new mongoose.Schema
  owner: String
  date: Number
  title: String
  details: String
  jbha_id:
    type: String
    index:
      unique: false
      sparse: true
  archived:
    type: Boolean
    default: false
  done:
    type: Boolean
    default: false

Assignment = mongoose.model 'assignment', AssignmentSchema

logger = new logging.Logger "API"

Jbha = exports

L = (prefix, message, urgency="debug") ->
  logger[urgency] "#{prefix.underline} :: #{message}"

exports.silence = () ->
  L = () ->
    # pass

Jbha.Client =

  # Logs a user into the homework website.
  # Returns ``true`` to ``cb`` if authentication was successful.
  # Returns ``false`` to ``cb`` if authentication failed.
  authenticate: (username, password, cb) ->
    username = username.toLowerCase()

    # Don't let Acquire log in...
    if username is "acquire"
      @_call_if_truthy "Invalid login", cb

    post_data = querystring.stringify
      Email: "#{username}@jbha.org"
      Passwd: password
      Action: "login"
      
    # console.log post_data

    options =
      host: "www.jbha.org"
      path: "/students/index.php"
      method: 'POST'
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Content-Length': post_data.length

    req = http.request options, (res) =>
      res.on 'end', () =>
        if res.headers.location is "/students/homework.php"
          L username, "Remote authentication succeeded", "info"
          # TODO: Don't explicitly pass settings as kwargs,
          # pass the entire settings object for DRY sake.
          Account
            .findOne()
            .where('_id', username)
            .exec (err, account_from_db) =>
              return if @_call_if_truthy err, cb
              cookie = res.headers['set-cookie'][1].split(';')[0]
              account = account_from_db or new Account()
              res =
                token:
                  cookie: cookie
                  username: username
                  password: password
                account: account
              if account_from_db
                cb null, res
              else
                account.nickname = username.split('.')[0].capitalize()
                account._id = username
                account.save (err) =>
                  return if @_call_if_truthy err, cb
                  cb null, res

        else
          L username, "Remote authentication failed", "warn"
          @_call_if_truthy "Invalid login", cb

    req.write post_data
    req.end()

  # Used ONLY for testing
  _create_account: (username, cb) ->
    account = new Account()
    account._id = username
    account.nickname = "TestAccount"
    account.save (err, doc) =>
      return if @_call_if_truthy err, cb
      cb null,
        account:
          doc
        token:
          cookie: "1235TESTCOOKIE54321"
          username: doc._id

  read_settings: (token, cb) ->
    Account
      .findOne()
      .where('_id', token.username)
      .select('nickname details is_new firstrun updated migrate feedback_given')
      .exec cb

  update_settings: (token, settings, cb) ->
    Account.update _id: token.username,
      nickname: settings.nickname
      details: settings.details
      firstrun: settings.firstrun
      migrate: settings.migrate,
      cb

  _delete_account: (token, account, cb) ->
    async.parallel [
      (callback) ->
        Account
          .where('_id', account)
          .remove callback
      (callback) ->
        Course
          .where('owner', account)
          .remove callback
      (callback) ->
        Assignment
          .where('owner', account)
          .remove callback
    ], cb

  migrate: (token, nuke, cb) ->
    finish = () ->
      Account.update _id: token.username,
        migrate: false,
        cb

    if nuke
      async.parallel [
        (callback) ->
          Course
            .where('owner', token.username)
            .remove callback
        (callback) ->
          Assignment
            .where('owner', token.username)
            .remove callback
      ], finish
    else
      finish()

  # JSON-ready dump of an account's courses and assignments
  by_course: (token, cb) ->
    Course
      .where('owner', token.username)
      .populate('assignments', 'title archived details date done jbha_id')
      .select('-owner -jbha_id')
      .exec (err, courses) =>
        @_call_if_truthy(err, cb)
        cb err, courses

  create_assignment: (token, data, cb) ->
    async.waterfall [

      (wf_callback) ->
        Course
          .findById(data.course)
          .exec wf_callback

      (course, wf_callback) ->
        assignment = new Assignment()
        assignment.owner = token.username
        assignment.title = data.title
        assignment.date = data.date
        assignment.details = data.details
        assignment.save (err) ->
          wf_callback err, course, assignment

      (course, assignment, wf_callback) ->
        course.assignments.addToSet assignment
        course.save (err) ->
          wf_callback err, course, assignment

    ], (err, course, assignment) ->
      cb err, course, assignment

  update_assignment: (token, assignment, cb) ->
    # Pull the assignment from the current course,
    # push it onto the new one, save it,
    # and finally update the assignment fields.
    async.waterfall [
      (wf_callback) ->
        Course.update {
          owner: token.username
          assignments: assignment._id
        },
        {
          $pull: {assignments: assignment._id}
        },
        {},
        (err) ->
          wf_callback()
      (wf_callback) ->
        Course
          .findOne()
          .where('owner', token.username)
          .where('_id', assignment.course)
          .exec wf_callback
      (course, wf_callback) ->
        course.assignments.addToSet assignment._id
        course.save wf_callback
    ], (err) ->
      Assignment.update {
          owner: token.username
          _id: assignment._id
        },
        {
          title: assignment.title
          date: assignment.date
          details: assignment.details
          done: assignment.done
          archived: assignment.archived
        },
        {},
        cb

  delete_assignment: (token, assignment, cb) ->
    Assignment
      .where('owner', token.username)
      .where('_id', assignment._id)
      .remove cb

  create_course: (token, data, cb) ->
    course = new Course()
    course.owner = token.username
    course.title = data.title
    course.teacher = data.teacher
    course.save cb

  update_course: (token, course, cb) ->
    Course.update {
        owner: token.username
        _id: course._id
      },
      {
        title: course.title
        teacher: course.teacher
      },
      (err, numAffected, raw) ->
        cb err

  delete_course: (token, course, cb) ->
    Course
      .where('owner', token.username)
      .where('_id', course._id)
      .remove cb

  create_feedback: (token, message, cb) ->
    feedback = new Feedback()
    feedback._id = token.username
    feedback.message = message
    feedback.save (err) ->
      return cb err if err
      Account.update _id: token.username,
        feedback_given: true,
        (err) ->
          return cb err if err
          cb null

  read_feedbacks: (cb) ->
    Feedback
    .find()
    .exec (err, feedbacks) ->
      if err
        cb err.err
      else
        cb null, feedbacks

  refresh: (token, options, cb) ->

    @_parse_courses token, (new_token, courses) =>
      token = new_token
      # Counter for the number of assignments that were
      # added that didn't exist in the database before.
      new_assignments = 0

      parse_course = (course_data, course_callback) =>
        # Get the DOM of the course webpage
        @_authenticated_request token, "course-detail.php?course_id=#{course_data.id}", (err, new_token, $) =>
          token = new_token
          async.waterfall [

            # Query the database for the course
            (wf_callback) =>
              Course
                .findOne()
                .where('owner', token.username)
                .where('jbha_id', course_data.id)
                .populate('assignments')
                .exec wf_callback

            # Pass the course along, or create a new
            # one if it didn't exist in the database.
            (course_from_db, wf_callback) =>
              if not course_from_db
                course = new Course()
                course.owner = token.username
                course.title = course_data.title
                course.jbha_id = course_data.id
                course.teacher = $("h1.normal").text().split(":").slice(0)[0]
              else
                course = course_from_db
              wf_callback null, course

            # Iterate over the DOM and parse the assignments, saving
            # them to the database if needed.
            (course, wf_callback) =>
              parse_assignment = (element, assignment_callback) =>
                # Looks like: ``Due May 08, 2012: Test: Macbeth``
                text_blob = $(element).text()
                # Skips over extraneous and unwanted matched objects,
                # like course policies and stuff.
                if text_blob.match /Due \w{3} \d{1,2}\, \d{4}:/
                  # Parse _their_ assignment id
                  assignment_id = $(element).attr('href').match(/\d+/)[0]

                  splits = text_blob.split ":"
                  assignment_title = splits.slice(1)[0].trim()
                  # Parse the date and store it as a UTC UNIX timestamp
                  assignment_date = moment.utc(splits.slice(0, 1)[0], "[Due] MMM DD, YYYY").valueOf()
                  # Parse the details of the assignment as HTML -- **not** as text.
                  assignment_details = $("#toggle-cont-#{assignment_id}").html()

                  # If there is some text content -- not just empty tags, we assume
                  # there are relevant assignment details and sanitize them.
                  if $("#toggle-cont-#{assignment_id}").text()
                    # These regexes are sanitizers that:
                    #
                    # - Strip all header elements.
                    # - Strip all in-line element styles.
                    regexes = [/\<h\d{1}\>/gi, /\<\/h\d{1}\>/gi, /style="(.*?)"/gi]
                    for regex in regexes
                      assignment_details = assignment_details.replace regex, ""
                    # Make jbha.org relative links absolute.
                    assignment_details = assignment_details.replace /href="\/(.*?)"/, 'href="http://www.jbha.org/$1"'
                  else 
                    # If there's no assignment details, set it to null.
                    assignment_details = null

                  # Get the assignment with the jbha_id we're currently parsing,
                  # if one exists, or return ``undefined``.
                  assignment_from_db = _.find course.assignments, (assignment) ->
                    true if assignment.jbha_id is assignment_id

                  if assignment_from_db
                    # Heuristic for assuming that an assignment has been "created-by-move".
                    # See #25
                    moved = assignment_from_db.date.valueOf() isnt assignment_date and
                        assignment_from_db.title isnt assignment_title
                    if not moved
                      assignment_callback null
                      return

                  assignment = new Assignment()
                  assignment.owner = token.username
                  assignment.title = assignment_title
                  assignment.jbha_id = assignment_id
                  assignment.details = assignment_details
                  assignment.date = assignment_date

                  # Add the assignment (really just the assignment ObjectId)
                  # on to the course's assignments array.
                  course.assignments.push assignment

                  # Increment the new assignments counter
                  new_assignments++

                  # Mark assignments in the past as done and archived
                  # if the option was specified.
                  if options and options.archive_if_old
                    if assignment_date < Date.now()
                      assignment.done = true
                      assignment.archived = true
                  assignment.save (err) ->
                    # If we identified a moved assignment, rename the old jbha_id
                    # to indicate that it's no longer valid -- that it's been replaced.
                    if moved
                      L token.username, "Move detected on assignment with jbha_id #{assignment_id}!", 'warn'
                      assignment_from_db.jbha_id += "-#{assignment_from_db._id}"
                      assignment_from_db.save (err) ->
                        assignment_callback err
                    else
                      assignment_callback err
                else
                  assignment_callback err

              async.forEach $('a[href^="javascript:arrow_down_right"]'), parse_assignment, (err) =>
                wf_callback err, course

          ], (err, course) =>
            course.save (err) =>
              L token.username, "Parsed course [#{course.title}]"
              course_callback err

      async.forEach courses, parse_course, (err) ->
        Account.update _id: token.username,
          updated: Date.now()
          is_new: false
          (err) =>
            cb err, token, new_assignments: new_assignments

  _authenticated_request: (token, resource, callback) ->

    cookie = token.cookie
    if not cookie
      callback "Authentication error: No session cookie"

    options =
      host: "www.jbha.org"
      method: 'GET'
      path: "/students/#{resource}"
      headers:
        'Cookie': cookie

    req = http.request options, (res) =>
      body = null
      res.on 'data', (chunk) ->
        body += chunk
      res.on 'end', =>
        $ = cheerio.load(body)
        # Handle re-authing if we've been logged out
        if $('a[href="/students/?Action=logout"]').length is 0
          L token.username, "Session expired; re-authenticating", "warn"
          @authenticate token.username, token.password, (err, res) ->
            token = res.token
            callback null, token, $
        else
          callback null, token, $

    req.on 'error', (err) ->
      callback err

    req.end()

  _parse_courses: (token, callback) ->
    @_authenticated_request token, "homework.php", (err, new_token, $) ->
      token = new_token
      courses = []

      blacklist = ['433', '665']

      parse_course = (element, fe_callback) ->
        course_id = $(element).attr('href').match(/\d+/)[0]
        if course_id not in blacklist
          courses.push
            title: $(element).text()
            id: course_id
        fe_callback null

      # Any link that has a href containing the
      # substring ``?course_id=`` in it.
      async.forEach $('a[href*="?course_id="]'), parse_course, (err) ->
        callback token, courses

  _call_if_truthy: (err, func) ->
    if err
      func err
      return true

  _migrationize: (date, callback) ->
    Account
      .update {updated: {$lt: moment(date).toDate()}},
        {migrate: true},
        {multi: true},
        (err, numAffected) =>
          return if @_call_if_truthy err, callback
          callback null, numAffected
      
  _stats: (num_shown=Infinity, callback) ->
    Account
      .find()
      .sort('-updated')
      .select('_id updated nickname')
      .exec (err, docs) ->
        if docs.length < num_shown
          showing = docs.length
        else
          showing = num_shown
        console.log "Showing most recently active #{String(showing).red} of #{String(docs.length).red} accounts"
        for doc in docs[1..num_shown]
          name = doc._id
          nickname = doc.nickname
          date = moment(doc.updated)
          console.log "\n#{name.bold} (#{nickname})"
          console.log date.format("» M/D").yellow + " @ " + date.format("h:mm:ss A").cyan + " (#{date.fromNow().green})"
        callback()