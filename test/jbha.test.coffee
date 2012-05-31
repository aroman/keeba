# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

should  = require("chai").should()

jbha    = require "../jbha"
secrets = require "../secrets"

jbha.silence()

describe "account", () ->

  token = null
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
    it 'should read without error', (done) ->
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

describe "authentication", () ->

  describe "valid credentials", () ->
    it 'should succeed', (done) ->
      jbha.Client.authenticate secrets.VALID_USERNAME, secrets.VALID_PASSWORD, (err, res) ->
        should.not.exist err
        done()

  describe "invalid credentials", () ->
    it 'should fail', (done) ->
      jbha.Client.authenticate 'joe.biden', 'flobots', (err, res) ->
        should.exist err
        done()