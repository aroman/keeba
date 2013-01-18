_            = require "underscore"
http         = require "http"
async        = require "async"
colors       = require "colors"
moment       = require "moment"
cheerio      = require "cheerio"
querystring  = require "querystring"

config       = require "./config"
logging      = require "./logging"
models       = require "./models"

Account = models.Account
Course = models.Course
Assignment = models.Assignment

logger = new logging.Logger "JBHA"

L = (prefix, message, urgency="debug") ->
  logger[urgency] "#{prefix.underline} :: #{message}"

module.exports = 

  # Logs a user into the homework website.
  # Returns ``true`` to ``cb`` if authentication was successful.
  # Returns ``false`` to ``cb`` if authentication failed.
  authenticate: (username, password, cb) ->
    username = username.toLowerCase()

    # Don't let Acquire log in...
    if username is "acquire"
      return cb new Error "Invalid login"

    post_data = querystring.stringify
      Email: "#{username}@jbha.org"
      Passwd: password
      Action: "login"

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
          L username, "Remote authentication succeeded", "info"
          Account
            .findOne()
            .where('_id', username)
            .exec (err, account_from_db) ->
              if err
                return cb err
              account = account_from_db or new Account()
              token =
                cookie: res.headers['set-cookie'][1].split(';')[0]
                username: username
                password: password
              if account_from_db
                cb null, account, token
              else
                account.nickname = username.split('.')[0]
                account._id = username
                account.save (err) ->
                  if err
                    return cb err
                  cb null, account, token
        else
          L username, "Remote authentication failed", "warn"
          cb new Error "Invalid login"

    req.on 'error', (err) ->
      return cb err

    req.write post_data
    req.end()

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
            (course_from_db, wf_callback) ->
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
            (course, wf_callback) ->
              parse_assignment = (element, assignment_callback) ->
                # Looks like: ``Due May 08, 2012: Test: Macbeth``
                text_blob = $(element).text()
                # Skips over extraneous and unwanted matched objects,
                # like course policies and stuff.
                if text_blob.match /Due \w{3} \d{1,2}\, \d{4}:/
                  # Parse _their_ assignment id
                  assignment_id = $(element).attr('href').match(/\d+/)[0]

                  splits = text_blob.split ":"
                  assignment_title = splits.slice(1).join(":").trim()
                  # DEPRECATE: Silently update assignment titles
                  # that were created under the old (wrong) parsing
                  # scheme if they differ.
                  assignment_title_old_algo = splits.slice(1)[0].trim()
                  # Parse the date and store it as a UTC UNIX timestamp
                  assignment_date = moment.utc(splits.slice(0, 1)[0], "[Due] MMM DD, YYYY").valueOf()
                  # Parse the details of the assignment as HTML -- **not** as text.
                  assignment_details = $("#toggle-cont-#{assignment_id}").html()

                  # If there is some text content -- not just empty tags, we assume
                  # there are relevant assignment details and sanitize them.
                  if $("#toggle-cont-#{assignment_id}").text()
                    # Crudely sanitize details to prevent common rendering screwups
                    regexes = [
                      /\<h\d{1}\>/gi, # Remove instances of "<h>"
                      /\<\/h\d{1}\>/gi, # Remove instances of "</h>"
                      /style="([\s\S]*?)"/gi, # Strip inline element styles
                      /<!--[\s\S]*?-->/g # Strip HTML/XML comments
                    ]
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

                  # If the assignment was already downloaded (at some point)
                  # to this account.
                  if assignment_from_db
                    # Heuristic for assuming that an assignment has been "created-by-move".
                    # See #25 on GitHub
                    moved = assignment_from_db.date.valueOf() isnt assignment_date and
                        assignment_from_db.title isnt assignment_title
                    if not moved
                      # DEPRECATE: Silently bump parsing mistakes if needed
                      if assignment_from_db.title == assignment_title_old_algo &&
                        assignment_title_old_algo != assignment_title
                          assignment_from_db.title = assignment_title
                          return assignment_from_db.save (err) ->
                            L token.username, "Fixed bum parse job on title: " + assignment_title, 'warn'
                            assignment_callback err
                      else
                        return assignment_callback null

                  assignment = new Assignment()
                  assignment.owner = token.username
                  assignment.title = assignment_title
                  assignment.jbha_id = assignment_id
                  assignment.details = assignment_details
                  assignment.date = assignment_date

                  # Add the assignment (really just the assignment ObjectId)
                  # onto the course's assignments array.
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
                      L token.username, "Create-by-move detected on assignment with jbha_id #{assignment_id}!", 'warn'
                      assignment_from_db.jbha_id += "-#{assignment_from_db._id}"
                      assignment_from_db.save (err) ->
                        assignment_callback err
                    else
                      assignment_callback err
                else
                  assignment_callback err

              async.forEach $('a[href^="javascript:arrow_down_right"]'), parse_assignment, (err) =>
                wf_callback err, course

          ], (err, course) ->
            course.save (err) ->
              L token.username, "Parsed course [#{course.title}]"
              course_callback err

      async.forEach courses, parse_course, (err) ->
        Account.update _id: token.username,
          updated: Date.now()
          is_new: false
          (err) ->
            cb err, token, new_assignments: new_assignments

  _parse_courses: (token, cb) ->
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
        cb token, courses

  _authenticated_request: (token, resource, cb) ->

    cookie = token.cookie
    if not cookie
      return cb new Error "Authentication error: No session cookie"

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
          @authenticate token.username, token.password, (err, account, token) =>
            if err
              return cb err
            # Now that we're re-auth'd, repeat the request
            @_authenticated_request token, resource, cb
        else
          cb null, token, $

    req.on 'error', (err) ->
      return cb err

    req.end()

  # Used in testing to suppress log output.
  suppress_logging: ->
    L = -> # pass