# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

jbha = require "./jbha"

process.on 'message', (message) ->
    if message.action = "refresh"
        jbha.Client.refresh message.token, message.options, (err, res) ->
            process.send [err, res]
            process.exit 0