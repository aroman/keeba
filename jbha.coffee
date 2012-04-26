# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

querystring = require "querystring"
mongoose = require "mongoose"
http = require "http"
cheerio = require "cheerio"
_ = require "underscore"

String::capitalize = ->
  @charAt(0).toUpperCase() + @slice 1

# We're on Jitsu
if process.env.SUBDOMAIN
  mongoose.connect "mongodb://nodejitsu:378b5f1b3674ee7f5d2b40b42fda0464@staff.mongohq.com:10095/nodejitsudb762603282243"
else
  mongoose.connect "mongodb://localhost/keeba"

AccountSchema = new mongoose.Schema
  _id: String
  accessed: Date
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
  updated: # Start off at the beginning of UNIX time so it's initially stale.
    type: Date
    default: new Date 0

Account = mongoose.model 'account', AccountSchema

# jbha_id is the content id for a course
# or assignment on the jbha.org website's
# database. It is used as a unique index
# to ensure that doing a fetch does not 
# result in duplicates being stored.
CourseSchema = new mongoose.Schema
  owner: String
  title: String
  jbha_id:
    type: String
    index:
      unique: false
      sparse: true
  teacher: String
  assignments: [{ type: mongoose.Schema.ObjectId, ref: 'assignment' }]
  details: String

Course = mongoose.model 'course', CourseSchema

AssignmentSchema = new mongoose.Schema
  owner: String
  date: Number
  title: String
  details: String
  jbha_id:
    type: String
    index:
      unique: true
      sparse: true
  archived:
    type: Boolean
    default: false
  done:
    type: Boolean
    default: false

Assignment = mongoose.model 'assignment', AssignmentSchema

Jbha = exports

Jbha.Client =

  # Logs a user into the homework website.
  # Returns ``true`` to ``cb`` if authentication was successful.
  # Returns ``false`` to ``cb`` if authentication failed.
  authenticate: (username, password, cb) ->
    username = username.toLowerCase()

    post_data = querystring.stringify
      Email: "#{username}@jbha.org"
      Passwd: password
      Action: "login"

    console.log "#{username} :: #{password}"

    options =
      host: "www.jbha.org"
      path: "/students/index.php"
      method: 'POST'
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Content-Length': post_data.length

    req = http.request options, (res) ->
      res.on 'end', ->
        if res.headers.location is "/students/homework.php"
          Account.where('_id', username).run (err, docs) ->
            account = docs[0] or new Account()
            account.accessed = Date.now()
            account.nickname = username.split('.')[0].capitalize()
            account._id = username
            account.save()
            cookie = res.headers['set-cookie'][1].split(';')[0]
            cb
              success: true
              token:
                cookie: cookie
                username: username
              is_new: account.is_new
        else
          cb success: false


    req.write post_data
    req.end()

  # Used ONLY for debugging/testing
  _create_account: (username, cb) ->
    account = new Account()
    account.accessed = Date.now()
    account._id = username
    account.nickname = "TestAccount"
    account.save()
    cb
      token:
        cookie: "1235TESTCOOKIE54321"
        username: account._id

  delete_account: (token, cb) ->
    Account
      .where('_id', token.username)
      .remove ->
        Course
          .where('owner', token.username)
          .remove ->
            Assignment
              .where('owner', token.username)
              .remove cb

  read_settings: (token, cb) ->
    Account
      .where('_id', token.username)
      .select(['initial_view', 'nickname', 'details', 'is_new', 'firstrun', 'updated'])
      .run (err, docs) ->
        cb(docs[0])

  update_settings: (token, settings, cb) ->
    Account.update _id: token.username,
      nickname: settings.nickname
      details: settings.details
      firstrun: settings.firstrun,
      cb

  by_course: (token, cb) ->
    Course
      .where('owner', token.username)
      .populate('assignments', ['title', 'archived', 'details', 'date', 'done', 'jbha_id'])
      .exclude(['owner', 'jbha_id'])
      .run (err, courses) ->
        cb courses

  # NEVER EVER CALL THIS
  drop_collections: () ->
    Course.collection.drop();
    Account.collection.drop();
    Assignment.collection.drop();

  create_assignment: (token, data, cb) ->
    Course
      .findById(data.course)
      .run (err, course) ->
        data.owner = token.username
        # FIXME: People can add their own fields
        delete data.course
        assignment = new Assignment(data)
        assignment.save (err) ->
          course.assignments.push assignment
          course.save()
          # TODO: Don't hard-code success
          cb(null, course, assignment)

  create_course: (token, data, cb) ->
    data.owner = token.username
    course = new Course(data)
    course.save (err) ->
      cb(null, course)

  update_assignment: (token, assignment, cb) ->
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
      cb

  delete_assignment: (token, assignment, cb) ->
    Assignment
      .where('owner', token.username)
      .where('_id', assignment._id)
      .remove cb

  update_course: (token, course, cb) ->
    Course.update {
        owner: token.username
        _id: course._id
      },
      {
        title: course.title
        teacher: course.teacher
      },
      cb

  delete_course: (token, course, cb) ->
    Course
      .where('owner', token.username)
      .where('_id', course._id)
      .remove cb

  refresh: (token, options, cb) ->
  
    @._parse_courses token.cookie, (courses) =>

      parsed_courses = 0
      new_assignments = 0
      _.each courses, (course_data) =>
          # Get the DOM tree for the specific course we're doing.
          @._authenticated_request token.cookie, "course-detail.php?course_id=#{course_data.id}", ($) ->
            Course
              .where('owner', token.username)
              .where('jbha_id', course_data.id)
              .populate('assignments', ['jbha_id'])
              .run (err, course) ->
                if not course[0]
                  course = new Course()
                  course.owner = token.username
                  course.title = course_data.title
                  course.jbha_id = course_data.id
                  course.teacher = $("h1.normal").text().split(":").slice(0)[0]
                else
                  course = course[0]

                jbha_ids = _.pluck(course.assignments, "jbha_id")

                parsed_assignments = 0
                assignments_to_parse = $('a[href^="javascript:arrow_down_right"]')
                assignments_to_parse.each ->
                  text_blob = $(@).text();
                  # Skips over extraneous and unwanted matched objects,
                  # like course policies and stuff.
                  if text_blob.match /Due \w{3} \d{1,2}\, \d{4}:/
                    splits = text_blob.split ":"
                    assignment_title = splits.slice(1)[0].trim()
                    assignment_date = Date.parse splits.slice(0, 1)
                    # Parse _their_ assignment id.
                    assignment_id = $(@).attr('href').match(/\d+/)[0]
                    # Parse the details of the assignment as HTML -- **not** as text.
                    assignment_details = $("#toggle-cont-#{assignment_id}").html();

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
                  else
                    # XXX BUG BUG BUG BUG CRUFT CRUFT CRUFT
                    # Basically we need to have this logic redundant from the end call.
                    # Not cool. Should refactor out to mutually accessable local
                    if ++parsed_assignments is assignments_to_parse.length
                      course.save ->
                        # Last course of current account
                        if ++parsed_courses is courses.length
                          Account.update _id: token.username,
                            updated: Date.now()
                            is_new: false
                            (err) ->
                              # TODO Don't hard-code success.
                              cb
                                success: true
                                new_assignments: new_assignments
                        console.log "[#{token.username}] [#{parsed_courses}/#{courses.length}] Parsed empty course [#{course.title}]"
                    return

                  assignment = new Assignment()
                  assignment.owner = token.username
                  assignment.title = assignment_title
                  assignment.jbha_id = assignment_id
                  assignment.details = assignment_details
                  assignment.date = assignment_date

                  # The assignment wasn't in the database
                  if assignment.jbha_id not in jbha_ids
                    new_assignments++
                    course.assignments.push assignment
                    # If we're set to mark assignments in the past as complete
                    if options and options.archive_if_old
                      if assignment_date < Date.now()
                        assignment.done = true
                        assignment.archived = true

                  assignment.save ->
                    # Last assignment of current course
                    if ++parsed_assignments is assignments_to_parse.length
                      course.save (err) ->
                        # Last course of current account
                        if ++parsed_courses is courses.length
                          Account.update _id: token.username,
                            updated: Date.now()
                            is_new: false
                            (err) ->
                              # TODO Don't hard-code success.
                              cb
                                success: true
                                new_assignments: new_assignments
                        console.log "[#{token.username}] [#{parsed_courses}/#{courses.length}] Parsed course [#{course.title}]"

  _authenticated_request: (cookie, resource, callback) ->
    err = null

    if not cookie
      err = "Authentication error: No session cookie"

    options =
      host: "www.jbha.org"
      method: 'GET'
      path: "/students/#{resource}"
      headers:
        'Cookie': cookie

    req = http.request options, (res) ->
      body = null
      res.on 'data', (chunk) ->
        body += chunk
      res.on 'end', ->
        callback cheerio.load(body)

    req.end()

  _parse_courses: (cookie, callback) ->
    @_authenticated_request cookie, "homework.php", ($) ->
      courses = []
      # Any link that has a href containing the 
      # substring ``?course_id=`` in it.
      $('a[href*="?course_id="]').each ->
        courses.push
          title: $(@).text()
          id: $(@).attr('href').match(/\d+/)[0]
      callback courses