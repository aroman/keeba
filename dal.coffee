# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

async        = require "async"
colors       = require "colors"
moment       = require "moment"

config       = require "./config"
models       = require "./models"
logging      = require "./logging"

Account = models.Account
Course = models.Course
Assignment = models.Assignment

logger = new logging.Logger "API"

L = (prefix, message, urgency="debug") ->
  logger[urgency] "#{prefix.underline} :: #{message}"

module.exports =

  # Used for debugging; normal account creation happens in jbha module
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
      .select('nickname details is_new firstrun updated migrate')
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

  _call_if_truthy: (err, func) ->
    if err
      func err
      return true

  # Used in testing to suppress log output.
  _suppress_logging: ->
    L = -> # pass