# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

fs        = require "fs"
cp        = require "child_process"
_         = require "underscore"
connect   = require "connect"
express   = require "express"
socketio  = require "socket.io"

jbha      = require "./jbha"
ansi      = require "./ansi"
logging   = require "./logging"

package_info = null
logger = new logging.Logger "SRV"

app = express.createServer()
sessionStore = new express.session.MemoryStore()

app.configure ->
  app.use express.cookieParser()
  app.use express.bodyParser()
  # app.use express.logger()
  app.use express.session
    store: sessionStore
    secret: "lolerskates"
    key: "express.sid"
  app.use app.router
  app.use express.static "#{__dirname}/static"
  app.use express.errorHandler(dumpExceptions: true, showStack: true)
  app.set 'view engine', 'jade'
  app.set 'views', "#{__dirname}/views"
  app.set 'view options', pretty: true
  return

# TODO: Better staging mode support/detection
staging = process.cwd().indexOf("staging") isnt -1

if staging
  app.listen 8888
else
  if process.getuid() isnt 0
    logger.error "Need root to serve on port 80 (production)"
    process.exit(1)
  app.listen 80

io = socketio.listen app, log: false

fs.readFile "#{__dirname}/package.json", "utf-8", (err, data) ->
  package_info = JSON.parse data

  if staging
    logger.info "Keeba #{package_info.version} serving in 
#{ansi.PURPLE}staging#{ansi.END} mode on port #{ansi.BOLD}8888#{ansi.END}."
  else
    logger.info "Keeba #{package_info.version} serving in 
#{ansi.PRODUCTION}production#{ansi.END} mode on port #{ansi.BOLD}80#{ansi.END}."

app.dynamicHelpers
  version: (req, res) ->
    return package_info.version

app.get "/", (req, res) ->
  token = req.session.token
  if token
    jbha.Client.read_settings token, (settings) ->
      res.redirect "/app"
  else
    res.render "index"
      failed: false
      appmode: false
      email: null

app.post "/", (req, res) ->
  email = req.body.email
  password = req.body.password
  jbha.Client.authenticate email, password, (err, response) ->
    if err
      res.render "index"
        failed: true
        appmode: false
        email: email
    else
      req.session.token = response.token
      if response.is_new
        res.redirect "/setup"
      else
        res.redirect "/"
 
app.get "/about", (req, res) ->
  res.render "about"
    appmode: false

app.get "/blog", (req, res) ->
  fs.readFile "#{__dirname}/blog.json", "utf-8", (err, data) ->
    res.render "blog"
      appmode: false
      blog: JSON.parse data

app.get "/logout", (req, res) ->
  req.session.destroy()
  res.redirect "/"

ensureSession = (req, res, next) ->
  req.token = req.session.token
  if not req.token
    res.redirect "/"
  else
    next()

hydrateSettings = (req, res, next) ->
  jbha.Client.read_settings req.token, (settings) ->
    req.settings = settings
    if not settings
      req.session.destroy()
      return res.redirect "/"
    next()

app.get "/setup", ensureSession, hydrateSettings, (req, res) ->
  if req.settings.is_new
    res.render "setup"
      appmode: false
      settings: JSON.stringify req.settings
  else
    res.redirect "/"

app.post "/setup", ensureSession, (req, res) ->
  settings = {
      nickname: req.body.nickname
      firstrun: true
  }
  jbha.Client.update_settings req.token, settings, ->
      res.redirect "/"

app.get "/app*", ensureSession, hydrateSettings, (req, res) ->
  jbha.Client.by_course req.token, (courses) ->
    if !req.settings || req.settings.is_new
      res.redirect "/setup"
    else
      res.render "app"
        appmode: true
        courses: JSON.stringify courses
        firstrun: req.settings.firstrun
        nickname: req.settings.nickname
        settings: JSON.stringify req.settings
        info: package_info

io.set "log level", 3
io.set "logger", new logging.Logger "SIO"
io.set "transports", [
  'websocket'
  'xhr-polling'
  'jsonp-polling'
]

io.set "authorization", (data, accept) ->
  if data.headers.cookie
    data.cookie = connect.utils.parseCookie data.headers.cookie
    data.sessionID = data.cookie['express.sid']
    data.sessionStore = sessionStore
    sessionStore.get data.sessionID, (err, session) ->
      if err
        accept err.message.toString(), false
      else
        data.session = new connect.middleware.session.Session data, session
        accept null, true
  else
    accept "No cookie transmitted.", false

workers = {}

io.sockets.on "connection", (socket) ->
  token = socket.handshake.session.token
  socket.join token.username

  L = (message, urgency="debug") ->
    console.log ("Pass") 
    # logger[urgency] "#{ansi.BOLD_START}#{token.username}#{ansi.BOLD_END} :: #{message}"

  sync = (model, method, data) ->
    event_name = "#{model}/#{data._id}:#{method}"
    socket.broadcast.to(token.username).emit(event_name, data)

  # Spawn a new node instance to handle a refresh
  # request. It's CPU-bound, so it blocks this thread.
  # This probably won't scale well past ~10 concurrent
  # workers. The parsing engine should probably be
  # written in a more performant language, but this'll
  # do for now.
  socket.on "refresh", (options, cb) ->
    # If they omitted the options param, then expect
    # the callback as the first arg.
    if _.isFunction(options)
      cb = options
    worker = workers[token.username]
    if worker
      worker.kill()
    worker = workers[token.username] = cp.fork "#{__dirname}/worker.js"

    logger.debug "herp herp herp"

    L "Worker with pid #{worker.pid} spawned", 'debug'

    worker.send
      action: "refresh"
      token: token
      options: options

    setTimeout () ->
      worker.kill('SIGKILL')
    , 30000

    worker.on "exit", (code, signal) ->
      if code isnt 0
        if signal is 'SIGKILL'
          L "Worker with pid #{worker.pid} timed out and was killed", 'error'
          cb "Worker timed out"
        else
          L "Worker with pid #{worker.pid} crashed", 'error'
          cb "Worker crashed"
      else
        L "Worker with pid #{worker.pid} exited successfully", 'debug'

    worker.on "message", (message) ->
      err = message[0]
      res = message[1]
      cb err, res

  socket.on "settings:read", (data, cb) ->
    jbha.Client.read_settings token, (settings) ->
      cb null, settings

  socket.on "settings:update", (data, cb) ->
    jbha.Client.update_settings token, data, ->
      # Hardcode the 0 for a singleton pattern. (See client model)
      socket.broadcast.to(token.username).emit("settings/0:update", data)
      cb null

  socket.on "course:create", (data, cb) ->
    jbha.Client.create_course token, data, (err, course) ->
      socket.broadcast.to(token.username).emit("courses:create", course)
      cb null, course

  socket.on "courses:read", (data, cb) ->
    jbha.Client.by_course token, (courses) ->
      cb null, courses

  socket.on "course:update", (data, cb) ->
    jbha.Client.update_course token, data, (err) ->
      sync "course", "update", data
      cb null

  socket.on "course:delete", (data, cb) ->
    jbha.Client.delete_course token, data, (err) ->
      sync "course", "delete", data
      cb null
      
  socket.on "assignments:create", (data, cb) ->
    jbha.Client.create_assignment token, data, (err, course, assignment) ->
      socket.broadcast.to(token.username).emit("course/#{course._id}:create", assignment)
      cb null, assignment

  socket.on "assignments:update", (data, cb) ->
    jbha.Client.update_assignment token, data, (err) ->
      sync "assignments", "update", data
      cb null

  socket.on "assignments:delete", (data, cb) ->
    jbha.Client.delete_assignment token, data, (err) ->
      sync "assignments", "delete", data
      cb null

  socket.on "delete account", (cb) ->
    jbha.Client.delete_account token, (err) ->
      cb null