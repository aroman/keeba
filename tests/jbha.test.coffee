# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

tap = require('tap')
jbha = require('../jbha')

client = jbha.Client

USERNAME = "avi.romanoff"
PASSWORD = "kakster96"

tap.test "invalid credentials", (t) ->

  client.authenticate "joe.biden", "foobar", (response) ->
    t.notOk response.success, "response.success is false"
    t.end()

tap.test "account functions", (t) ->

  test_username = "test.account"

  new_settings =
    nickname: "Dr. " + Math.random()
    firstrun: false

  client._create_account test_username, (response) ->

    token = response.token
    t.ok token, "test account token is ok"
    t.equal token.username, test_username, "token username is test username"

    t.test "update settings", (t) ->
      client.update_settings token, new_settings, (response) ->
        t.equal response, null, "No error"
        t.end()

    t.test "read settings", (t) ->
      client.read_settings token, (settings) ->
        t.equal settings._id, test_username, "settings username is test username"
        t.equal settings.nickname, new_settings.nickname, "settings nickname is #{new_settings.nickname}"
        t.equal new_settings.firstrun, settings.firstrun, "settings firstrun is #{new_settings.firstrun}"
        t.ok settings.is_new, "settings is_new is true"
        t.end()

    t.test "create assignment", (t) ->
      t.end()

    t.test "delete account", (t) ->
      client.delete_account token, (response) ->
        t.equal response, null, "No error"
        t.end()

tap.test "valid credentials", (t) ->

  client.authenticate USERNAME, PASSWORD, (response) ->

    t.ok response.success, "response.success is true"
    t.ok response.token, "response.token exists"
    token = response.token

    t.test "parsing courses", (t) ->
      client._parse_courses token.cookie, (courses) ->
        t.type courses, Array, "courses is an Array"
        t.end()

    t.test "parsing homework", (t) ->
      client.refresh token, (response) ->
        t.ok response.success, "response.success = true"
        t.end()

    t.test "getting assignments by course", (t) ->
      client.by_course token, (courses) ->
        t.type courses, Object, "courses is an Object"
        t.end()

tap.tearDown ->
  process.exit()