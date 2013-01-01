// Generated by CoffeeScript 1.4.0
(function() {
  var MongoStore, app, browserCheck, color, colors, connect, cookie_parser, cp, ensureSession, express, http, hydrateSettings, io, jbha, logger, logging, mode, mongo_uri, port, secrets, server, sessionStore, socketio, ss, ssockets, workers, _;

  cp = require("child_process");

  http = require("http");

  _ = require("underscore");

  colors = require("colors");

  connect = require("connect");

  express = require("express");

  ssockets = require("session.socket.io");

  socketio = require("socket.io");

  MongoStore = require("connect-mongo")(express);

  jbha = require("./jbha");

  logging = require("./logging");

  secrets = require("./secrets");

  app = express();

  server = http.createServer(app);

  io = socketio.listen(server, {
    log: false
  });

  logger = new logging.Logger("SRV");

  io.set('transports', ['xhr-polling', 'jsonp-polling', 'htmlfile']);

  mode = null;

  port = null;

  color = null;

  mongo_uri = null;

  app.configure('development', function() {
    mode = 'development';
    port = process.env.PORT || 8888;
    color = 'magenta';
    mongo_uri = secrets.MONGO_STAGING_URI;
    io.set("log level", 3);
    io.set("logger", new logging.Logger("SIO"));
    app.use(express.logger('dev'));
    return app.locals.pretty = true;
  });

  app.configure('production', function() {
    mode = 'production';
    port = process.env.PORT || 80;
    color = 'green';
    mongo_uri = secrets.MONGO_PRODUCTION_URI;
    return app.set('view options', {
      pretty: false
    });
  });

  sessionStore = new MongoStore({
    db: 'keeba',
    url: mongo_uri,
    stringify: false
  }, function() {
    logger.debug("Connected to database");
    server.listen(port);
    logger.info("Running in " + mode[color] + " mode on port " + (port.toString().bold) + ".");
    return logger.info("Rav Keeba has taken the bima . . .  ");
  });

  cookie_parser = express.cookieParser(secrets.SESSION_SECRET);

  ss = new ssockets(io, sessionStore, cookie_parser);

  app.configure(function() {
    app.use(cookie_parser);
    app.use(express.bodyParser());
    app.use(express.session({
      cookie: {
        maxAge: 604800000
      },
      store: sessionStore
    }));
    app.use(app.router);
    app.use(express["static"]("" + __dirname + "/static"));
    app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
    app.set('view engine', 'jade');
    return app.set('views', "" + __dirname + "/views");
  });

  logger.info("Using database: " + mongo_uri);

  app.locals.revision = process.env.GIT_REV;

  app.locals.development_build = mode === 'development';

  app.use(function(err, req, res, next) {
    console.error(err.stack);
    return res.send(500, "Yikes! Something broke.");
  });

  browserCheck = function(req, res, next) {
    var regex, ua, version;
    ua = req.headers['user-agent'];
    if (ua.indexOf("MSIE") !== -1) {
      regex = /MSIE\s(\d{1,2}\.\d)/.exec(ua);
      version = Number(regex[1]);
      if (version < 10) {
        return res.redirect("/unsupported");
      }
    }
    return next();
  };

  ensureSession = function(req, res, next) {
    if (!req.session.token) {
      return res.redirect("/?whence=" + req.url);
    } else {
      return next();
    }
  };

  hydrateSettings = function(req, res, next) {
    return jbha.Client.read_settings(req.session.token, function(err, settings) {
      req.settings = settings;
      if (!settings) {
        req.session.destroy();
        return res.redirect("/");
      }
      return next();
    });
  };

  app.get("/", browserCheck, function(req, res) {
    if (req.session.token) {
      return res.redirect("/app");
    } else {
      return res.render("index", {
        failed: false,
        email: null
      });
    }
  });

  app.post("/", function(req, res) {
    var email, password, whence;
    email = req.body.email;
    password = req.body.password;
    whence = req.query.whence;
    return jbha.Client.authenticate(email, password, function(err, response) {
      if (err) {
        return res.render("index", {
          failed: true,
          email: email
        });
      } else {
        req.session.token = response.token;
        if (response.account.is_new) {
          return res.redirect("/setup");
        } else if (response.account.migrate) {
          return res.redirect("/migrate");
        } else {
          if (whence) {
            return res.redirect(whence);
          } else {
            return res.redirect("/app");
          }
        }
      }
    });
  });

  app.get("/about", function(req, res) {
    return res.render("about");
  });

  app.get("/help", function(req, res) {
    return res.render("help");
  });

  app.get("/unsupported", function(req, res) {
    return res.render("unsupported");
  });

  app.get("/logout", function(req, res) {
    req.session.destroy();
    return res.redirect("/");
  });

  app.get("/migrate", ensureSession, hydrateSettings, function(req, res) {
    if (!req.settings.migrate) {
      return res.redirect("/");
    } else {
      return res.render("migrate", {
        nickname: req.settings.nickname
      });
    }
  });

  app.post("/migrate", ensureSession, hydrateSettings, function(req, res) {
    if (!req.settings.migrate) {
      return res.redirect("/app");
    } else {
      return jbha.Client.migrate(req.session.token, req.query.nuke, function() {
        return res.redirect("/app");
      });
    }
  });

  app.get("/setup", ensureSession, hydrateSettings, function(req, res) {
    if (req.settings.is_new) {
      return res.render("setup", {
        settings: JSON.stringify(req.settings)
      });
    } else {
      return res.redirect("/");
    }
  });

  app.post("/setup", ensureSession, hydrateSettings, function(req, res) {
    var settings;
    settings = req.settings;
    settings.firstrun = true;
    if (req.body.nickname) {
      settings.nickname = req.body.nickname;
    }
    return jbha.Client.update_settings(req.session.token, settings, function() {
      return res.redirect("/app");
    });
  });

  app.get("/app*", ensureSession, hydrateSettings, function(req, res) {
    return jbha.Client.by_course(req.session.token, function(err, courses) {
      if (!req.settings || req.settings.is_new) {
        return res.redirect("/setup");
      } else if (req.settings.migrate) {
        return res.redirect("/migrate");
      } else {
        return res.render("app", {
          courses: JSON.stringify(courses),
          firstrun: req.settings.firstrun,
          feedback_given: req.settings.feedback_given,
          nickname: req.settings.nickname,
          settings: JSON.stringify(req.settings)
        });
      }
    });
  });

  workers = {};

  ss.on("connection", function(err, socket, session) {
    var L, broadcast, saveSession, sync, token;
    if (!session) {
      return socket.disconnect();
    }
    token = session.token;
    socket.join(token.username);
    saveSession = function(cb) {
      return sessionStore.set(socket.handshake.signedCookies['connect.sid'], session, cb);
    };
    L = function(message, urgency) {
      if (urgency == null) {
        urgency = "debug";
      }
      return logger[urgency]("" + token.username.underline + " :: " + message);
    };
    sync = function(model, method, data) {
      var event_name;
      event_name = "" + model + "/" + data._id + ":" + method;
      return socket.broadcast.to(token.username).emit(event_name, data);
    };
    broadcast = function(message, data) {
      return io.sockets["in"](token.username).emit(message, data);
    };
    socket.on("refresh", function(options) {
      var worker;
      worker = workers[token.username];
      if (worker) {
        L("Worker with pid " + worker.pid + " replaced", 'warn');
        worker.kill('SIGHUP');
      }
      worker = workers[token.username] = cp.fork("" + __dirname + "/worker.js", [], {
        env: process.env
      });
      L("Worker with pid " + worker.pid + " spawned", 'debug');
      worker.send({
        action: "refresh",
        token: token,
        options: options
      });
      broadcast("refresh:start");
      setTimeout(function() {
        return worker.kill('SIGKILL');
      }, 30000);
      worker.on("message", function(message) {
        session.token = token = message[1];
        saveSession();
        return broadcast("refresh:end", {
          err: message[0],
          res: message[2]
        });
      });
      return worker.on("exit", function(code, signal) {
        delete workers[token.username];
        if (signal === 'SIGHUP') {
          return;
        }
        if (code !== 0) {
          if (signal === 'SIGKILL') {
            L("Worker with pid " + worker.pid + " timed out and was killed", 'error');
            return broadcast("refresh:end", {
              err: "Worker timed out"
            });
          } else {
            L("Worker with pid " + worker.pid + " crashed", 'error');
            return broadcast("refresh:end", {
              err: "Worker crashed"
            });
          }
        } else {
          return L("Worker with pid " + worker.pid + " exited successfully", 'debug');
        }
      });
    });
    socket.on("settings:read", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.read_settings(token, function(err, settings) {
        return cb(null, settings);
      });
    });
    socket.on("settings:update", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.update_settings(token, data, function() {
        socket.broadcast.to(token.username).emit("settings/0:update", data);
        return cb(null);
      });
    });
    socket.on("course:create", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.create_course(token, data, function(err, course) {
        socket.broadcast.to(token.username).emit("courses:create", course);
        return cb(null, course);
      });
    });
    socket.on("courses:read", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.by_course(token, function(err, courses) {
        return cb(null, courses);
      });
    });
    socket.on("course:update", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.update_course(token, data, function(err) {
        sync("course", "update", data);
        return cb(null);
      });
    });
    socket.on("course:delete", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.delete_course(token, data, function(err) {
        sync("course", "delete", data);
        return cb(null);
      });
    });
    socket.on("assignments:create", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.create_assignment(token, data, function(err, course, assignment) {
        socket.broadcast.to(token.username).emit("course/" + course._id + ":create", assignment);
        return cb(null, assignment);
      });
    });
    socket.on("assignments:update", function(data, cb) {
      return jbha.Client.update_assignment(token, data, function(err) {
        sync("assignments", "update", data);
        if (_.isFunction(cb)) {
          return cb(null);
        }
      });
    });
    socket.on("assignments:delete", function(data, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      return jbha.Client.delete_assignment(token, data, function(err) {
        sync("assignments", "delete", data);
        return cb(null);
      });
    });
    return socket.on("d/a", function(account, cb) {
      if (!_.isFunction(cb)) {
        return;
      }
      if (token.username !== "avi.romanoff") {
        return cb(null);
      }
      return jbha.Client._delete_account(token, account, function(err) {
        return cb(null);
      });
    });
  });

}).call(this);
