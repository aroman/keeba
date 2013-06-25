# (C) 2012 Avi Romanoff <aviromanoff at gmail.com> 

# Command that marks all accounts last updated before
# a given date as needing to migrate by setting the
# `migrate` field to true on each affected Account.

sys      = require "sys"
colors   = require "colors"
mongoose = require "mongoose"
moment   = require "moment"

config   = require "./config"
models   = require "./models"

Account = models.Account

mongoose.connect config.MONGO_URI

argv = require("optimist")
  .usage("Mark accounts for migration if they were last updated before a given date.")
  .alias('d', 'date')
  .describe('d', "Date up to which all accounts will be marked as needing to migrate (ex: 2/25/13)")
  .demand('d')
  .argv

process.stdout.write "WARNING! This operation will affect the database. Continue? [y/n]: "

process.openStdin().once "data", (data) ->
  # Ignore linefeed
  if data.toString()[0] is "y"
    date = argv.d
    Account
      .update {updated: {$lt: moment(date).toDate()}},
        {migrate: true},
        {multi: true},
        (err, numAffected) =>
          if err
            console.log "ERROR: #{err}"
            process.exit(1)
          else
            console.log "Success: #{numAffected} accounts marked for migration."
            process.exit()
  else
    process.exit()