# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

# Node modules
os         = require "os"
cp         = require "child_process"
url        = require "url"
http       = require "http"

# 3rd party modules
_          = require "underscore"
hbpc       = require "handlebars-precompiler"
colors     = require "colors"
connect    = require "connect"
express    = require "express"
ssockets   = require "session.socket.io"
socketio   = require "socket.io"
redis      = require "socket.io/node_modules/redis"
RedisStore = require "socket.io/lib/stores/redis"
MongoStore = require("connect-mongo")(express)

# Internal modules
jbha       = require "./jbha"
logging    = require "./logging"
secrets    = require "./secrets"
pkg_info = require "./package.json"

# Create machinery
app = express()
server = http.createServer app
io = socketio.listen server, log: false
logger = new logging.Logger "SRV"

# Never allow WebSockets
io.set 'transports', [
  'xhr-polling'
  'jsonp-polling'
  'htmlfile'
]

redis_url = url.parse process.env.REDISTOGO_URL
redis_pass = redis_url.auth.split(":")[1]
pub = redis.createClient redis_url.port, redis_url.hostname
sub = redis.createClient redis_url.port, redis_url.hostname
store = redis.createClient redis_url.port, redis_url.hostname
pub.auth redis_pass, -> console.log "Pub UP!"
sub.auth redis_pass, -> console.log "Sub UP!"
store.auth redis_pass, -> console.log "Store UP!"

# Use redis
io.set 'store', new RedisStore
  redisPub: pub
  redisSub: sub
  redisClient: store

mode = null
port = null
color = null
mongo_uri = null

app.configure 'development', ->
  mode = 'development'
  port = process.env.PORT || 8888
  color = 'magenta'
  mongo_uri = secrets.MONGO_STAGING_URI
  io.set "log level", 3
  io.set "logger", new logging.Logger "SIO"
  # app.use express.logger()
  app.locals.pretty = true # Enable Jade pretty-printing

app.configure 'production', ->
  mode = 'production'
  port = process.env.PORT || 80
  color = 'green'
  mongo_uri = secrets.MONGO_PRODUCTION_URI
  app.set 'view options', pretty: false

sessionStore = new MongoStore
  db: 'keeba'
  url: mongo_uri
  stringify: false
  clear_interval: 60 * 60 * 5, # Every 5 hours
  ->
    server.listen port
    logger.info "Keeba #{pkg_info.version} serving in #{mode[color]} mode on port #{port.toString().bold}."

cookie_parser = express.cookieParser secrets.SESSION_SECRET
ss = new ssockets io, sessionStore, cookie_parser

app.configure ->
  app.use cookie_parser
  app.use express.bodyParser()
  hbpc.watchDir "#{__dirname}/views/templates", "#{__dirname}/static/js/templates.min.js", ['handlebars']
  app.use express.session(store: sessionStore)
  app.use app.router
  app.use express.static "#{__dirname}/static"
  app.use express.errorHandler(dumpExceptions: true, showStack: true)
  app.set 'view engine', 'jade'
  app.set 'views', "#{__dirname}/views"

logger.info "Using database: #{mongo_uri}"

app.locals.version = pkg_info.version
app.locals.development_build = mode is 'development'

# Redirect requests coming from
# unsupported browsers to landing
# page for old browsers.
browserCheck = (req, res, next) ->
  ua = req.headers['user-agent']
  if ua.indexOf("MSIE") isnt -1
    regex = /MSIE\s(\d{1,2}\.\d)/.exec(ua)
    version = Number(regex[1])
    if version < 9
      return res.redirect "/unsupported"
  next()

ensureSession = (req, res, next) ->
  if not req.session.token
    res.redirect "/?whence=#{req.url}"
  else
    next()

hydrateSettings = (req, res, next) ->
  jbha.Client.read_settings req.session.token, (err, settings) ->
    req.settings = settings
    if not settings
      req.session.destroy()
      return res.redirect "/"
    next()

app.get "/", browserCheck, (req, res) ->
  if req.session.token
    jbha.Client.read_settings req.session.token, (err, settings) ->
      res.redirect "/app"
  else
    res.render "index"
      failed: false
      appmode: false
      email: null

app.post "/", (req, res) ->
  email = req.body.email
  password = req.body.password
  whence = req.query.whence
  jbha.Client.authenticate email, password, (err, response) ->
    if err
      res.render "index"
        failed: true
        appmode: false
        email: email
    else
      req.session.token = response.token
      if response.account.is_new
        res.redirect "/setup"
      else if response.account.migrate
        res.redirect "/migrate"
      else
        if whence
          res.redirect whence
        else
          res.redirect "/app"
 
app.get "/about", (req, res) ->
  res.render "about"
    appmode: false

app.get "/help", (req, res) ->
  res.render "help"
    appmode: false

app.get "/unsupported", (req, res) ->
  res.render "unsupported"
    appmode: false

app.get "/feedback", (req, res) ->
  jbha.Client.read_feedbacks (err, feedbacks) ->
    res.render "feedback"
      feedbacks: feedbacks
      appmode: false

app.get "/logout", (req, res) ->
  req.session.destroy()
  res.redirect "/"

app.get "/migrate", ensureSession, hydrateSettings, (req, res) ->
  if !req.settings.migrate
    res.redirect "/"
  else
    res.render "migrate"
      appmode: false
      nickname: req.settings.nickname

app.post "/migrate", ensureSession, hydrateSettings, (req, res) ->
  if !req.settings.migrate
    res.redirect "/app"
  else
    jbha.Client.migrate req.session.token, req.query.nuke, () ->
      res.redirect "/app"

app.get "/setup", ensureSession, hydrateSettings, (req, res) ->
  if req.settings.is_new
    res.render "setup"
      appmode: false
      settings: JSON.stringify req.settings
  else
    res.redirect "/"

app.post "/setup", ensureSession, hydrateSettings, (req, res) ->
  settings = req.settings
  settings.firstrun = true

  if req.body.nickname
    settings.nickname = req.body.nickname
  jbha.Client.update_settings req.session.token, settings, ->
    res.redirect "/app"

app.get "/app*", ensureSession, hydrateSettings, (req, res) ->
  jbha.Client.by_course req.session.token, (err, courses) ->
    if !req.settings || req.settings.is_new
      res.redirect "/setup"
    else if req.settings.migrate
      res.redirect "/migrate"
    else
      res.render "app"
        appmode: true
        courses: JSON.stringify courses
        firstrun: req.settings.firstrun
        feedback_given: req.settings.feedback_given
        nickname: req.settings.nickname
        settings: JSON.stringify req.settings
        info: pkg_info

workers = {}

ss.on "connection", (err, socket, session) ->
  token = session.token
  socket.join token.username

  L = (message, urgency="debug") ->
    logger[urgency] "#{token.username.underline} :: #{message}"

  # Syncs model state to all connected sessions,
  # EXCEPT the one that initiated the sync.
  sync = (model, method, data) ->
    event_name = "#{model}/#{data._id}:#{method}"
    socket.broadcast.to(token.username).emit(event_name, data)

  # Broadcasts a message to all connected sessions,
  # INCLUDING the one that initiated the message.
  broadcast = (message, data) ->
    io.sockets.in(token.username).emit(message, data)

  keepAlive = () ->
    jbha.Client.keep_alive token, (err) ->
      L "Kept remote session alive", "info"

  # Poll the school server every 25 minutes so
  # they don't drop our session due to inactivity.
  keep_alive_id = setInterval(keepAlive, 1500000)

  # Stop polling after the socket disconnects.
  # This does not happen automatically.
  socket.on "disconnect", () ->
    clearInterval(keep_alive_id)

  # Spawn a new node instance to handle a refresh
  # request. It's CPU-bound, so it blocks this thread.
  # Only allow one worker per global username presence.
  socket.on "refresh", (options) ->
    worker = workers[token.username]
    if worker
      L "Worker with pid #{worker.pid} replaced", 'warn'
      worker.kill('SIGHUP')
    worker = workers[token.username] = cp.fork "#{__dirname}/worker.js", [], env: process.env

    L "Worker with pid #{worker.pid} spawned", 'debug'

    worker.send
      action: "refresh"
      token: token
      options: options

    # Let connected clients know a refresh was started
    broadcast "refresh:start"

    setTimeout () ->
      worker.kill('SIGKILL')
    , 30000

    worker.on "message", (message) ->
      # Let connected clients know a refresh ended 
      broadcast "refresh:end", 
        err: message[0]
        res: message[1]

    worker.on "exit", (code, signal) ->
      delete workers[token.username]

      # Obsoleted by new process
      return if signal is 'SIGHUP'

      if code isnt 0
        if signal is 'SIGKILL'
          L "Worker with pid #{worker.pid} timed out and was killed", 'error'
          broadcast "refresh:end",
            err: "Worker timed out"
        else
          L "Worker with pid #{worker.pid} crashed", 'error'
          broadcast "refresh:end",
            err: "Worker crashed"
      else
        L "Worker with pid #{worker.pid} exited successfully", 'debug'

  socket.on "settings:read", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.read_settings token, (err, settings) ->
      cb null, settings

  socket.on "settings:update", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.update_settings token, data, ->
      # Hardcode the 0 for a singleton pattern. (See client model).
      socket.broadcast.to(token.username).emit("settings/0:update", data)
      cb null

  socket.on "course:create", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.create_course token, data, (err, course) ->
      socket.broadcast.to(token.username).emit("courses:create", course)
      cb null, course

  socket.on "courses:read", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.by_course token, (err, courses) ->
      cb null, courses

  socket.on "course:update", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.update_course token, data, ->
    sync "course", "update", data
    cb null

  socket.on "course:delete", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.delete_course token, data, ->
    sync "course", "delete", data
    cb null
      
  socket.on "assignments:create", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.create_assignment token, data, (err, course, assignment) ->
      socket.broadcast.to(token.username).emit("course/#{course._id}:create", assignment)
      cb null, assignment

  socket.on "assignments:update", (data, cb) ->
    jbha.Client.update_assignment token, data, ->
    sync "assignments", "update", data
    cb null if _.isFunction cb

  socket.on "assignments:delete", (data, cb) ->
    return unless _.isFunction cb
    jbha.Client.delete_assignment token, data, ->
    sync "assignments", "delete", data
    cb null

  socket.on "feedback", (message, cb) ->
    return unless _.isFunction cb
    jbha.Client.create_feedback token, message, cb

  socket.on "d/a", (account, cb) ->
    return unless _.isFunction cb
    return cb null unless token.username is "avi.romanoff"
    jbha.Client._delete_account token, account, (err) ->
      cb null

  socket.on "stats", (cb) ->
    return unless _.isFunction cb
    cb
      loadavg: os.loadavg()
      totalmem: os.totalmem()
      free: os.freemem()