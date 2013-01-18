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
      if err
        return cb err
      token =
        cookie: "1235TESTCOOKIE54321"
        username: doc._id
      cb null, doc, token

  read_settings: (username, cb) ->
    Account
      .findOne()
      .where('_id', username)
      .select('nickname details is_new firstrun updated migrate')
      .exec cb

  update_settings: (username, settings, cb) ->
    Account.update _id: username,
      nickname: settings.nickname
      details: settings.details
      firstrun: settings.firstrun
      migrate: settings.migrate,
      cb

  # Used for debugging; currently no public delete function.
  _delete_account: (username, account, cb) ->
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

  migrate: (username, nuke, cb) ->
    finish = ->
      Account.update _id: username,
        migrate: false,
        cb

    if nuke
      async.parallel [
        (callback) ->
          Course
            .where('owner', username)
            .remove callback
        (callback) ->
          Assignment
            .where('owner', username)
            .remove callback
      ], finish
    else
      finish()

  # JSON-ready dump of an account's courses and assignments
  by_course: (username, cb) ->
    Course
      .where('owner', username)
      .populate('assignments', 'title archived details date done jbha_id')
      .select('-owner -jbha_id')
      .exec (err, courses) =>
        if err
          return cb err
        cb err, courses

  create_assignment: (username, data, cb) ->
    async.waterfall [

      (wf_callback) ->
        Course
          .findById(data.course)
          .exec wf_callback

      (course, wf_callback) ->
        assignment = new Assignment()
        assignment.owner = username
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

  update_assignment: (username, assignment, cb) ->
    # Pull the assignment from the current course,
    # push it onto the new one, save it,
    # and finally update the assignment fields.
    async.waterfall [

      (wf_callback) ->
        Course.update {
          owner: username
          assignments: assignment._id
        },
        {
          $pull: {assignments: assignment._id}
        },
        {},
        wf_callback

      (wf_callback) ->
        Course
          .findOne()
          .where('owner', username)
          .where('_id', assignment.course)
          .exec wf_callback

      (course, wf_callback) ->
        course.assignments.addToSet assignment._id
        course.save wf_callback

    ], (err) ->
      if err
        return cb err
      Assignment.update {
          owner: username
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

  delete_assignment: (username, assignment, cb) ->
    Assignment
      .where('owner', username)
      .where('_id', assignment._id)
      .remove cb

  create_course: (username, data, cb) ->
    course = new Course()
    course.owner = username
    course.title = data.title
    course.teacher = data.teacher
    course.save cb

  update_course: (username, course, cb) ->
    Course.update {
        owner: username
        _id: course._id
      },
      {
        title: course.title
        teacher: course.teacher
      },
      # Don't pass along numAffected and raw to
      # the callback -- just return the err argument.
      (err, numAffected, raw) ->
        cb err

  delete_course: (username, course, cb) ->
    Course
      .where('owner', username)
      .where('_id', course._id)
      .remove cb

  # Used in testing to suppress log output.
  suppress_logging: ->
    L = -> # pass