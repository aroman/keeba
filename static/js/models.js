// Copyright (C) 2013 Avi Romanoff <aviromanoff at gmail.com>

// Contains the models used for both the actual
// app itself as well as the setup page.

// Represents a specific assignment which is part
// of a CourseModel (is part of an AssignmentCollection).
CourseAssignment = Backbone.RelationalModel.extend({

  idAttribute: "_id",
  urlRoot: 'assignments',

  initialize: function () {
    // If we had an id at initialization
    // (meaning a page-bootstrapped-model), then
    // we can bind immediately. Otherwise
    // we don't have an id to listen for on the server
    // and bindToServer will have to be called manually
    // after we're sure there is one.
    if (this.id) {
      this.bindToServer();
    }
    this.on('change:done change:date', window.app.updateUpcoming, app);
  },

  defaults: function () {
    return {
      title: "",
      details: "",
      date: moment().utc().valueOf(),
      done: false,
      archived: false
    };
  },

  bindToServer: function () {
    this.ioBind('update', this.set);
    this.ioBind('delete', this.destroy);
    this.on('destroy', this.ioUnbindAll);
  },

  validate: function (attrs) {
    var errors = [];

    if (!attrs.title) {
      errors.push({
        attr: 'title',
        message: "must have a title"
      });
    }

    // If the date is false-y, but NOT NaN,
    // which would indicate a failed parse 
    // attempt, so we let it fall through
    // to the else block.
    if (!attrs.date && !_.isNaN(attrs.date)) {
      errors.push({
        attr: 'date',
        message: "must have a date"
      });
    } else {
      if (_.isNaN(attrs.date)) {
        errors.push({
          attr: 'date',
          message: "invalid date (format: mm/dd/yy)"
        });
      }
    }

    return _.any(errors) ? errors : null;
  },

});

// Collection of CourseAssignments
// Used in CourseModel to collect a course's assignments.
AssignmentCollection = Backbone.QueryCollection.extend({

  comparator: function (assignment) {
    return assignment.get('date');
  }

});

// Collection of CourseAssignments (collected via
// a single AssignmentCollection)
// Represents a specific course and contains the
// assignments for that course.
CourseModel = Backbone.RelationalModel.extend({

  idAttribute: "_id",
  urlRoot: 'course',
  url: function () {
    return this.urlRoot + '/' + this.id;
  },

  initialize: function () {
    // See parallel comment on CourseAssignment
    if (this.id) {
      this.bindToServer();
    }
  },

  defaults: function () {
    return {
      title: "",
      teacher: ""
    };
  },

  bindToServer: function () {
    this.ioBind('create', this.addAssignment);
    this.ioBind('update', this.set);
    this.ioBind('delete', this.destroy);
    this.bind('delete', this.ioUnbindAll);
    this.bind('add:assignments', this.triggerGlobalAdd, this);
    this.bind('remove:assignments', window.app.updateUpcoming, this);
  },

  addAssignment: function (assignment) {
    var to_add = new CourseAssignment (assignment);
    this.get('assignments').add(to_add);
    this.trigger('add:assignments', to_add);
  },

  triggerGlobalAdd: function (derp) {
    console.log("triggerGlobalAdd");
    app.trigger('global:add:assignments');
    window.app.updateUpcoming();
  },

  relations: [
    {
      type: Backbone.HasMany,
      key: 'assignments',
      relatedModel: 'CourseAssignment',
      collectionType: 'AssignmentCollection',
      reverseRelation: {
        key: 'course',
        includeInJSON: "_id"
      }
    }
  ],

  assignment_query: function (start, end, done_selector) {
    var query = {
      date: {
        $between: [start, end]
      }
    };
    if (done_selector === "only done") {
      query.done = true;
    }
    else if (done_selector === "only undone") {
      query.done = false;
    }
    else if (done_selector === "any") {
      // Do nothing. Simply omit the criterion.
    } else {
      // Invalid argument; panic.
      alert("Avi dun goofed!");
    }
    return this.get('assignments').query(query);
  },

  validate: function (attrs) {
    var errors = [];

    if (!attrs.title) {
      errors.push({
        attr: 'title',
        message: "must have a title"
      });
    }
    
    return _.any(errors) ? errors : null;
  },

});

// Collection of CourseModels
// Represents the collection of all the courses
// which the user is a part of.
CourseCollection = Backbone.QueryCollection.extend({

  model: CourseModel,
  url: 'courses',

  initialize: function () {
    var that = this;
    window.socket.on('courses:create', function (course) {
      var added = that.add(course);
      that.trigger('add', added);
    });
  },

  comparator: function (course) {
    return course.get('title').toLowerCase();
  },
  
  get_assignments: function (start, end, only_done) {
    var assignments = this.map(function (model) {
      return model.assignment_query(start, end, only_done);
    });
    return _.flatten(assignments, true);
  }

});

// Represents the data which is displayed in the banner
// at the top of the app and setup pages.
Status = Backbone.Model.extend({

  defaults: function () {
    return {
      heading: "Loading...",
      message: "Keeba is crunching some data, hold on a sec.",
      kind: "info",
      closable: false
    };
  }

});

// Represents a user's account settings
// This model is a singleton -- there should be only
// one instance of it per account.
Settings = Backbone.Model.extend({

  urlRoot: 'settings',

  initialize: function () {
    this.ioBind('update', this.set);
  },

  validate: function (attrs) {
    var errors = [];

    if (!attrs.nickname) {
      errors.push({
        attr: 'nickname',
        message: "must have a nickname"
      });
    }
    
    return _.any(errors) ? errors : null;
  },

  getUpdatedAt: function () {
    return moment.utc(settings.get('updated'));
  },

  defaults: function () {
    return {
      id: 0 // My trick for a model "singleton" pattern.
    };
  }

});