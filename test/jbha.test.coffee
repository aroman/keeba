# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

should   = require("chai").should()
mongoose = require "mongoose"

jbha     = require "../jbha"
dal      = require "../dal"
config   = require "../config"

mongoose.connect config.MONGO_URI

jbha.suppress_logging()
dal.suppress_logging()

describe "jbha", ->

  token = null

  describe "valid credentials", ->
    it 'should succeed', (done) ->
      jbha.authenticate config.VALID_USERNAME, config.VALID_PASSWORD, (err, account, _token) ->
        should.exist account
        should.exist _token
        should.not.exist err
        token = _token
        done()

  describe "invalid credentials", ->
    it 'should fail', (done) ->
      jbha.authenticate 'joe.biden', 'flobots', (err, res) ->
        should.exist err
        done()

describe "dal", ->

  token = null

  mock_settings =
    _id: String(Math.random())
    nickname: "Dr. " + Math.random()
    firstrun: false
    details: true

  describe "create", ->
    it 'should create without error', (done) ->
      dal._create_account mock_settings._id, (err, account, _token) ->
        should.not.exist err
        account._id.should.equal mock_settings._id
        account.is_new.should.equal true
        account.firstrun.should.equal true
        _token.username.should.equal mock_settings._id
        should.exist _token.cookie
        token = _token
        done()

  describe "update", ->
    it 'should update without error', (done) ->
      dal.update_settings token.username, mock_settings, (err) ->
        should.not.exist err
        done()

  describe "read", ->
    it 'should read without error', (done) ->
      dal.read_settings token.username, (err, settings) ->
        should.not.exist err
        settings.nickname.should.equal mock_settings.nickname
        settings.firstrun.should.equal mock_settings.firstrun
        settings.details.should.equal mock_settings.details
        settings.is_new.should.equal true
        done()

  describe "delete", ->
    it 'should delete without error', (done) ->
      dal._delete_account token.username, mock_settings._id, (err) ->
        should.not.exist err
        done()

  fixture =
    title: "Counting to " + Math.random()
    teacher: "Mr. " + Math.random()
    assignments: []

  fixture_updated =
    title: fixture.title + " ***"
    teacher: fixture.teacher + " ***"
    assignments: []

  describe "create course", ->
    it 'should create without error', (done) ->
      dal.create_course token.username, fixture, (err, course) ->
        should.not.exist err
        course.title.should.equal fixture.title
        course.teacher.should.equal fixture.teacher
        course.assignments.should.be.an 'array'
        course.assignments.should.be.empty
        fixture._id = fixture_updated._id = course._id
        done()

  describe "create assignment with details", ->
    it 'should be kosher', (done) ->
      assignment_fixture =
        course: fixture._id
        title: "Stop sleeping and warn others"
        details: "Eat that ASAP Rocky"
        date: new Date().valueOf()
      dal.create_assignment token.username, assignment_fixture, (err, course, assignment) ->
        should.not.exist err
        course.assignments.length.should.equal 1
        assignment.title.should.equal assignment_fixture.title
        assignment.details.should.equal assignment_fixture.details
        assignment.date.should.equal assignment_fixture.date
        done()

  describe "delete assignment without details", ->
    it 'should be kosher', (done) ->
      assignment_fixture =
        course: fixture._id
        title: "This is ground control to Major Tom"
        details: null
        date: new Date().valueOf()
      dal.create_assignment token.username, assignment_fixture, (err, course, assignment) ->
        should.not.exist err
        course.assignments.length.should.equal 2
        assignment.title.should.equal assignment_fixture.title
        should.not.exist assignment.details
        assignment.date.should.equal assignment_fixture.date
        done()

  describe "read courses", ->
    it 'should read without error', (done) ->
      dal.by_course token.username, (err, courses) ->
        should.not.exist err
        courses.should.be.an 'array'
        courses.length.should.be.above 0
        done()

  describe "update course", ->
    it 'should update without error', (done) ->
      dal.update_course token.username, fixture, (err) ->
        should.not.exist err
        done()

  describe "delete course", ->
    it 'should delete without error', (done) ->
      dal.delete_course token.username, fixture_updated, (err) ->
        should.not.exist err
        done()