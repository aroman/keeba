# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

jbha = require "./jbha"

process.on 'message', (message) ->
  if message.action = "refresh"
    jbha.Client.refresh message.token, message.options, (err, new_token, res) ->
      process.send [err, new_token, res]
      process.exit 0