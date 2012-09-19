sys = require "sys"

argv = require("optimist")
  .usage("Mark accounts for migration if they were last updated before a given date.")
  .alias('d', 'date')
  .describe('d', "Date up to which all all accounts will be marked as needing to migrate")
  .demand('d')
  .argv
  
jbha = require "./jbha"

process.stdout.write "WARNING! This operation will affect the database. Continue? [y/n]: "

process.openStdin().once "data", (data) ->
  # Ignore linefeed
  if data.toString()[0] is "y"
    jbha.Client._migrationize argv.d, (err, numAffected) ->
      if err
        console.log "ERROR: #{err}"
      else
        console.log "Success: #{numAffected} accounts marked for migration."
      process.exit()
  else
    process.exit()