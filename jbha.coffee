# Copyright (C) 2013 Avi Romanoff <aviromanoff at gmail.com>

# Contains API to interface with the jbha.org/students
# homework portal, providing authentication and parsing.
# Automatically re-authenicates sessions if expired,
# hence the need for storing the user's password
# in his temporary session.

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

  # Authenticates a user to the jbha.org homework
  # website, and returns their existing Keeba account
  # or creates a new one this is their first log-in
  # via Keeba.
  # Generates 'token' objects, which contain
  # all the neccessary information for making
  # authenticated requests via this API.
  # Contains a user's username, password, and PHP
  # session cookie for the remote session.
  authenticate: (username, password, cb) ->
    username = username.toLowerCase()

    post_data = querystring.stringify
      Email: "#{username}@jbha.org"
      Passwd: password
      Action: "login"

    options =
      hostname: "www.jbha.org"
      path: "/students/index.php"
      method: 'POST'
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Content-Length': post_data.length

    req = http.request options, (res) ->
      res.resume()

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

  # Performs a full pull of the latest homework data
  # from the school website.
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

            # Iterate over the DOM and parse the headings (e.g individual links
            # and assignments), saving them to the database if needed.
            (course, wf_callback) ->
              parse_item = (element, item_callback) ->
                # Looks like: ``Syllabus`` or ``Due May 08, 2012: Test: Macbeth``
                item_title = $(element).text()

                # The name of the div which this heading links to
                # e.g ``toggle-cont-28066`` or ``toggle-dept-cont-27``
                # (The raw href looks like ``javascript:arrow_down_right('toggle-cont-26199'``)
                item_content = $("#" + element.attribs.href.match(/'(.*)'/)[1])

                if item_title.match /Due \w{3} \d{1,2}\, \d{4}:/ # It's an assignment
                  # Grab _their_ assignment id
                  assignment_id = element.attribs.href.match(/\d+/)[0]

                  splits = item_title.split ":"
                  assignment_title = splits.slice(1).join(":").trim()
                  # Parse the date and store it as a UTC UNIX timestamp
                  assignment_date = moment.utc(splits.slice(0, 1)[0], "[Due] MMM DD, YYYY").valueOf()
                  # Details can be full HTML, so use the target content as such
                  assignment_details = item_content.html()

                  # If there is some text content -- not just empty tags, we assume
                  # there are relevant assignment details and sanitize them.
                  if item_content.text()
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
                    created_by_move = assignment_from_db.date.valueOf() isnt assignment_date and
                      assignment_from_db.title isnt assignment_title
                    # ANY of the assignment's data were changed. (i.e fetched date/title/details
                    # aren't the same as previously stored date/title/details)
                    updated = assignment_from_db.date.valueOf() isnt assignment_date or
                      assignment_from_db.title isnt assignment_title or
                      assignment_from_db.details isnt assignment_details
                    if not created_by_move
                      # We know we don't need to create a new assignment,
                      # but do we need to update an existing one?
                      if updated
                        assignment_from_db.date = assignment_date
                        assignment_from_db.title = assignment_title
                        assignment_from_db.details = assignment_details
                        L token.username, "Assignment updated!", "warn"
                        assignment_from_db.save (err) ->
                          item_callback err
                        return 
                      else
                        # We neither need to create an new assignment or update 
                        # an existing one, so move onto the next assignment.
                        return item_callback null

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
                    # If we identified a create-by-move assignment, rename the old jbha_id
                    # to indicate that it's no longer valid -- that it's been replaced.
                    if created_by_move
                      L token.username, "Create-by-move detected on assignment with jbha_id #{assignment_id}!", 'warn'
                      assignment_from_db.jbha_id += "-#{assignment_from_db._id}"
                      assignment_from_db.save (err) ->
                        item_callback err
                    else
                      item_callback err
                else # It's a link/syllabus/something-like-that
                  # If there's no item content, we don't care about this info item.
                  if not item_content.text()
                    return item_callback null

                  info_item_title = item_title.trim()
                  info_item_tab = $("a[href='#" + item_content.parent().attr('id') + "']").text()

                  # Details can be full HTML, so use the target content as such
                  info_item_content = item_content.html().trim()

                  # Make jbha.org relative links absolute.
                  info_item_content = info_item_content.replace /href="\/(.*?)"/, 'href="http://www.jbha.org/$1"'

                  # Get the tab with the jbha_id we're currently parsing,
                  # if one exists, or return ``undefined``.
                  info_item_from_db = _.find course.info_items, (info_item) ->
                    true if info_item_tab is info_item.tab and info_item_title is info_item.title

                  # If the info item was already downloaded (at some point)
                  # to this account.
                  if info_item_from_db
                    if info_item_from_db.content is info_item_content
                      return item_callback null
                    # Info item content is different, so remove the existing one
                    # from the db before adding the new one.
                    else
                      course.info_items.pull info_item_from_db

                  course.info_items.push
                    tab: info_item_tab
                    title: info_item_title
                    content: info_item_content
                  course.save (err) ->
                      item_callback err

              async.forEach $('a[href^="javascript:arrow_down_right"]:not([class])'), parse_item, (err) =>
                wf_callback err, course

          ], (err, course) ->
            course.save (err) ->
              L token.username, "Synchronized course [#{course.title}]"
              course_callback err

      async.forEach courses, parse_course, (err) ->
        Account.update _id: token.username,
          updated: Date.now()
          is_new: false
          (err) ->
            cb err, token, new_assignments: new_assignments

  # Internal function -- used by refresh.
  _parse_courses: (token, cb) ->
    @_authenticated_request token, "homework.php", (err, new_token, $) ->
      token = new_token
      courses = []

      parse_course = (element, fe_callback) ->
        course_id = $(element).attr('href').match(/\d+/)[0]
        courses.push
          title: $(element).text()
          id: course_id
        fe_callback null

      # Any link that has a href containing the
      # substring ``?course_id=`` in it.
      async.forEach $('a[href*="?course_id="]'), parse_course, (err) ->
        cb token, courses

  # Internal function -- used by refresh & _parse_courses.
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
      res.resume()
      res.on 'end', =>
        $ = cheerio.load(body)
        # Handle re-authing if we've been logged out
        if $('a[href="/students/?Action=logout"]').length is 0
          L token.username, "Session expired; re-authenticating", "info"
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

  # Used in test suite to suppress log output.
  suppress_logging: ->
    L = -> # pass
