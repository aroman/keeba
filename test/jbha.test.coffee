# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

should = require("chai").should()
jbha   = require "../jbha"

USERNAME = "avi.romanoff"
PASSWORD = "kakster96"

TEST_ACC_NAME = "test.account"

describe "account", () ->

  token = null
  new_settings =
    nickname: "Dr. " + Math.random()
    firstrun: false
    details: true

  describe "create", () ->
    it 'should create without error', (done) ->
      jbha.Client._create_account TEST_ACC_NAME, (err, res) ->
        should.not.exist err
        res.account._id.should.equal TEST_ACC_NAME
        res.account.is_new.should.equal true
        res.account.firstrun.should.equal true
        res.token.username.should.equal TEST_ACC_NAME
        should.exist(res.token.cookie)
        token = res.token
        done()

  describe "update", () ->
    it 'should read without error', (done) ->
      jbha.Client.update_settings token, new_settings, (err) ->
        should.not.exist err
        done()

  describe "read", () ->
    it 'should read without error', (done) ->
      jbha.Client.read_settings token, (err, settings) ->
        should.not.exist err
        settings.nickname.should.equal new_settings.nickname
        settings.firstrun.should.equal new_settings.firstrun
        settings.firstrun.should.equal new_settings.firstrun
        settings.is_new.should.equal true
        done()

  describe "delete", () ->
    it 'should delete without error', (done) ->
      jbha.Client._delete_account token, TEST_ACC_NAME, (err) ->
        should.not.exist err
        done()