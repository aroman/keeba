# Copyright (C) 2013 Avi Romanoff <aviromanoff at gmail.com>

# Identifies the appropriate MongoDB connection
# URI to use based on the environment.
#
# If the `NODE_ENV` environment variable is set to `production`,
# database URI identified in this order:
#
# 1. contents of `MONGO_PRODUCTION_URI` env variable
# 2. contents of `MONGOLAB_URI` env variable
#
# If the `NODE_ENV` envrionment variable is **not** set or is
# set to anything other than `production`, database URI is
# identified in this order:
#
# 1. contents of `MONGO_DEV_URI` env variable
# 2. *mongodb://127.0.0.1:27017/keeba*
getMongoURI = ->
  if process.env.NODE_ENV == 'production' # We're in production mode
    if process.env.MONGO_PRODUCTION_URI # Production DB URI manually specified
      return process.env.MONGO_PRODUCTION_URI
    if process.env.MONGOLAB_URI # Production DB URI automatically set by MongoLab Heroku addon
      return process.env.MONGOLAB_URI

  else # We're in development mode
    if process.env.MONGO_DEV_URI # Development DB URI manually specified
      return process.env.MONGO_DEV_URI
    else # Development DB URI *not* manually specified; fall back to default development database URI
      return "mongodb://127.0.0.1:27017/keeba"

module.exports =
  EMAIL_USERNAME: "" # Email username for GMail 500 mailer
  EMAIL_PASSWORD: "" # Email password for GMail 500 mailer
  ADMIN_EMAIL: "" # Recipient email for GMail 500 mailer
  MONGO_URI: getMongoURI()
  SESSION_SECRET: "" # Express session secret
  VALID_USERNAME: "" # Valid username on jbha.org homework portal, for testing
  VALID_PASSWORD: "" # Password for above purpose