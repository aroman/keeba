# (C) 2012 Avi Romanoff <aviromanoff at gmail.com> 

module.exports =
  MONGO_PRODUCTION_URI: process.env.MONGOLAB_URI || "mongodb://keeba:usinglatin@ds033477.mongolab.com:33477/keeba-production"
  MONGO_STAGING_URI: process.env.STAGING_URI || "mongodb://keeba:stagedevel@ds033767.mongolab.com:33767/keeba-staging"
  # MONGO_STAGING_URI: process.env.STAGING_URI || "mongodb://keeba:keeba@ds037647-a.mongolab.com:37647/godhavemercy"
  SESSION_SECRET: "asethabalana"
  VALID_USERNAME: "avi.romanoff"
  VALID_PASSWORD: "kakster96"