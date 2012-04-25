jbha = require "./jbha"

process.on 'message', (message) ->
    if message.action = "refresh"
        jbha.Client.refresh message.token, message.options, (res) ->
            process.send res
            process.exit 0