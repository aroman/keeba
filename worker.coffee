# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

mongoose = require "mongoose"

jbha   = require "./jbha"
config = require "./config"

mongoose.connect config.MONGO_URI

process.on 'message', (message) ->
  if message.action = "refresh"
    jbha.refresh message.token, message.options, (err, new_token, res) ->
      process.send [err, new_token, res]
      process.exit()