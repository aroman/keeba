# (C) 2012 Avi Romanoff <aviromanoff at gmail.com> 
# Based on socket.io-node's MIT licensed logger.

_ = require 'underscore'

ansi = require "./ansi"

class Logger

  constructor: (@prefix='') ->
    _.each @_levels, (name) =>
      @[name] = =>
        @_log.apply(@, [name].concat(_.toArray(arguments)))

  _levels: [
    'error'
    'warn'
    'info'
    'debug'
  ]

  _colors: [
    ansi.RED
    ansi.YELLOW
    ansi.BLUE
    ansi.GREY
  ]

  _pad: (str) ->
    max = 0
    for level in @_levels
      max = Math.max(max, level.length)

    if str.length < max
      return str + new Array(max - str.length + 1).join(' ')

    return str

  _log: (type) ->
    index = @_levels.indexOf(type)
    console.log.apply(
      console,
       ["  " + @_colors[index] + @._pad(type) + " - " + ansi.END + ansi.BOLD + @prefix + ansi.END].concat(_.toArray(arguments)[1..]))

module.exports = {Logger: Logger}