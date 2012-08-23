# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

should  = require("chai").should()

jbha    = require "../jbha"
secrets = require "../secrets"

jbha.silence()

token = null

describe "authentication", () ->

  describe "valid credentials", () ->
    it 'should succeed', (done) ->
      jbha.Client.authenticate secrets.VALID_USERNAME, secrets.VALID_PASSWORD, (err, res) ->
        should.exist res.token
        should.not.exist err
        token = res.token
        done()

  describe "invalid credentials", () ->
    it 'should fail', (done) ->
      jbha.Client.authenticate 'joe.biden', 'flobots', (err, res) ->
        should.exist err
        done()

describe "accounts", () ->

  mock_settings =
    _id: String(Math.random())
    nickname: "Dr. " + Math.random()
    firstrun: false
    details: true

  describe "create", () ->
    it 'should create without error', (done) ->
      jbha.Client._create_account mock_settings._id, (err, res) ->
        should.not.exist err
        res.account._id.should.equal mock_settings._id
        res.account.is_new.should.equal true
        res.account.firstrun.should.equal true
        res.token.username.should.equal mock_settings._id
        should.exist res.token.cookie
        token = res.token
        done()

  describe "update", () ->
    it 'should update without error', (done) ->
      jbha.Client.update_settings token, mock_settings, (err) ->
        should.not.exist err
        done()

  describe "read", () ->
    it 'should read without error', (done) ->
      jbha.Client.read_settings token, (err, settings) ->
        should.not.exist err
        settings.nickname.should.equal mock_settings.nickname
        settings.firstrun.should.equal mock_settings.firstrun
        settings.details.should.equal mock_settings.details
        settings.is_new.should.equal true
        done()

  describe "delete", () ->
    it 'should delete without error', (done) ->
      jbha.Client._delete_account token, mock_settings._id, (err) ->
        should.not.exist err
        done()

describe "homework", () ->

  fixture =
    title: "Counting to " + Math.random()
    teacher: "Mr. " + Math.random()
    assignments: []

  fixture_updated =
    title: fixture.title + " ***"
    teacher: fixture.teacher + " ***"
    assignments: []

  describe "create course", () ->
    it 'should create without error', (done) ->
      jbha.Client.create_course token, fixture, (err, course) ->
        should.not.exist err
        course.title.should.equal fixture.title
        course.teacher.should.equal fixture.teacher
        course.assignments.should.be.an 'array'
        course.assignments.should.be.empty
        fixture._id = fixture_updated._id = course._id
        done()

  describe "create assignment with details", () ->
    it 'should be kosher', (done) ->
      assignment_fixture =
        course: fixture._id
        title: "Stop sleeping and warn others"
        details: "Eat that ASAP Rocky"
        date: new Date().valueOf()
      jbha.Client.create_assignment token, assignment_fixture, (err, course, assignment) ->
        should.not.exist err
        course.assignments.length.should.equal 1
        assignment.title.should.equal assignment_fixture.title
        assignment.details.should.equal assignment_fixture.details
        assignment.date.should.equal assignment_fixture.date
        done()

  describe "delete assignment without details", () ->
    it 'should be kosher', (done) ->
      assignment_fixture =
        course: fixture._id
        title: "This is ground control to Major Tom"
        details: null
        date: new Date().valueOf()
      jbha.Client.create_assignment token, assignment_fixture, (err, course, assignment) ->
        should.not.exist err
        course.assignments.length.should.equal 2
        assignment.title.should.equal assignment_fixture.title
        should.not.exist assignment.details
        assignment.date.should.equal assignment_fixture.date
        done()

  describe "read courses", () ->
    it 'should read without error', (done) ->
      jbha.Client.by_course token, (err, courses) ->
        should.not.exist err
        courses.should.be.an 'array'
        courses.length.should.be.above 0
        done()

  describe "update course", () ->
    it 'should update without error', (done) ->
      jbha.Client.update_course token, fixture, (err) ->
        should.not.exist err
        done()

  describe "delete course", () ->
    it 'should delete without error', (done) ->
      jbha.Client.delete_course token, fixture_updated, (err) ->
        should.not.exist err
        done()