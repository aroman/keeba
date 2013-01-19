# (C) 2013 Avi Romanoff <aviromanoff at gmail.com> 

# Purely vanity module which displays
# the last `n` number of active accounts
# as based on Account.updated.

colors   = require "colors"
mongoose = require "mongoose"
moment   = require "moment"

config   = require "./config"
models   = require "./models"

Account = models.Account

mongoose.connect config.MONGO_URI

argv = require("optimist")
  .usage("Show recently active users.\nUsage: $0 -n [num]")
  .alias('n', 'num')
  .demand('n')
  .describe('n', "Number of recently active users to show")
  .argv

num_shown = argv.n

Account
  .find()
  .sort('-updated')
  .select('_id updated nickname')
  .exec (err, docs) ->
    if docs.length < num_shown
      showing = docs.length
    else
      showing = num_shown
    console.log "Showing most recently active #{String(showing).red} of #{String(docs.length).red} accounts"
    for doc in docs[0..num_shown]
      name = doc._id
      nickname = doc.nickname
      date = moment(doc.updated)
      console.log "\n#{name.bold} (#{nickname})"
      console.log date.format("» M/D").yellow + " @ " + date.format("h:mm:ss A").cyan + " (#{date.fromNow().green})"
    process.exit(0)