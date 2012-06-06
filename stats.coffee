argv = require("optimist")
  .usage("Show recently active users.\nUsage: $0 -n [num]")
  .alias('n', 'num')
  .demand('n')
  .describe('n', "Number of recently active users to show")
  .argv

jbha = require "./jbha"

jbha.Client._stats argv.n, (err) ->
  process.exit()