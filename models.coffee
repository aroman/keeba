# Copyright (C) 2013 Avi Romanoff <aviromanoff at gmail.com>

# Contains the Mongoose models used server-side
# for the app. Note that these models are NOT
# identical to the Backbone models used on the 
# client, though there is a great deal of overlap.

mongoose = require 'mongoose'

AccountSchema = new mongoose.Schema
  _id: String
  nickname: String
  is_new:
    type: Boolean
    default: true
  firstrun:
    type: Boolean
    default: true
  details:
    type: Boolean
    default: false
  migrate:
    type: Boolean
    default: false
  updated: 
    type: Date
    default: new Date 0 # Start off at the beginning of UNIX time so it's initially stale.

CourseSchema = new mongoose.Schema
  owner: String
  title: String
  teacher: String
  jbha_id: # content id as found on the jbha.org homework website
    type: String
    index:
      unique: false
      sparse: true
  assignments: [{ type: mongoose.Schema.ObjectId, ref: 'assignment' }]

AssignmentSchema = new mongoose.Schema
  owner: String
  date: Number
  title: String
  details: String
  jbha_id: # content id as found on the jbha.org homework website
    type: String
    index:
      unique: false
      sparse: true
  archived:
    type: Boolean
    default: false
  done:
    type: Boolean
    default: false

module.exports =
  Account: mongoose.model 'account', AccountSchema
  Course: mongoose.model 'course', CourseSchema
  Assignment: mongoose.model 'assignment', AssignmentSchema