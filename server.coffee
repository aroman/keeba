# Copyright (C) 2012 Avi Romanoff <aviromanoff at gmail.com>

fs = require('fs')
express = require "express"
socketio = require "socket.io"
connect = require "connect"
cp = require "child_process"
_ = require "underscore"
parseCookie = connect.utils.parseCookie 
Session = connect.middleware.session.Session
MemoryStore = express.session.MemoryStore

jbha = require "./jbha"

package_info = null

app = express.createServer()
sessionStore = new MemoryStore()

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

fs.readFile "#{__dirname}/../package.json", "utf-8", (err, data) ->
  package_info = JSON.parse data
  app.listen 80

io = socketio.listen app

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
  jbha.Client.authenticate email, password, (response) ->
    if not response.success
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

# TODO: Logout page
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

io.set "log level", 2
io.set "transports", [
  'websocket'
  'xhr-polling'
  'jsonp-polling'
]

workers = {}

io.set "authorization", (data, accept) ->
  if data.headers.cookie
    data.cookie = parseCookie data.headers.cookie
    data.sessionID = data.cookie['express.sid']
    data.sessionStore = sessionStore
    sessionStore.get data.sessionID, (err, session) ->
      if err
        accept err.message.toString(), false
      else
        data.session = new Session data, session
        accept null, true
  else
    accept "No cookie transmitted.", false

io.sockets.on "connection", (socket) ->
  token = socket.handshake.session.token
  socket.join token.username

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
    worker.send
      action: "refresh"
      token: token
      options: options
    worker.on "message", (res) ->
      cb res

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