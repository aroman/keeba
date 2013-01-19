# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

# This module is spawned as a child process
# and enables the running jbha.refresh as
# an entirely separate process, as it is
# crash prone due to the unpredictability
# of HTML parsing and HTTP requests.

mongoose = require "mongoose"

jbha   = require "./jbha"
config = require "./config"

mongoose.connect config.MONGO_URI

process.on 'message', (message) ->
  if message.action = "refresh"
    jbha.refresh message.token, message.options, (err, new_token, res) ->
      process.send [err, new_token, res]
      process.exit()