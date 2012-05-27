StatusView = Backbone.View.extend({

  el: "#status",
  children: null, // Optimization to use a cache for animating.

  events: {
    "click a.link-action": "handleLink"
  },


  initialize: function (options) {
    this.render();
    this.model.bind('change', this.render, this);
    settings.bind('change:nickname', this.render, this);
  },

  render: function () {
    if (this.model.get('addable')) {
      app.setFavicon('zap-highlight');
    }
    this.children = this.$el.html(status_template(this.model.toJSON())).children();
    return this;
  },

  alert: function () {
    this.children.effect("bounce", {times: 2}, 300);
  },

  handleLink: function () {
    var that = this;
    // Reset all the data to a clean
    // pull from the server
    courses.fetch({success: function () {
      // Re-render the current view (it will be destroyed
      // when fetch()ing the CourseCollection).
      router.current_view.render();
      that.model.set({addable: false});
      app.num_new = 0;
      app.setFavicon('zap');
      app.update_timer = setInterval(app.updateUpdatedAt, 20000);
    }});
  }

});

SettingsView = Backbone.View.extend({

  el: $("#settings-modal"),

  events: {
    "click button#save": "save"
  },

  initialize: function () {
    this.model.bind('change', this.render, this);
  },

  show: function () {
    this.$el.modal({
      backdrop: 'static'
    });
  },

  save: function () {
    var that = this;
    this.model.save({
      nickname: this.$("#nickname").val(),
      details: this.$("#details").is(':checked')
    },
    {
      error: function (model, errors) {
        _.each(errors, function (error) {
          var control_group = that.$("#" + error.attr).parents(".control-group");
          control_group.addClass('error');
          control_group.find('.help-inline').text(error.message);
        });
      },
      success: function () {
        that.$el.modal('hide');
      }
    });
  },

  render: function () {
    var context = {
      details: this.model.get('details'),
      nickname: this.model.get('nickname')
    };
    this.$(".modal-body").html(settings_template(context));
    return this;
  }

});

AddAssignmentView = Backbone.View.extend({

  el: $("#add-assignment-modal"),
  template: undefined,
  parent_date: undefined,
  parent_course: undefined,

  events: {
    "click button":  "add",
    "hidden":        "remove"
  },

  initialize: function (options) {
    this.template = options.template;
    this.parent_date = options.date;
    this.parent_course = options.course;
    this.render();
  },

  show: function () {
    this.$el.modal({
      backdrop: 'static'
    });
  },

  add: function () {
    var that = this;

    // Disable all form elements to prevent
    // double-submissions.
    this.$(":input").prop('disabled', true);

    // If the date isn't blank, parse it.
    // If it is, just leave it false-y and let
    // validation mark it as missing.
    var date = this.$("#date").val();
    if (date) {
      date = moment(date, DATE_EDIT_FORMAT).valueOf();
    }

    var course_id = this.parent_course || this.$("#course").val();

    window.courses.get(course_id).get('assignments').create({
      title: this.$("#title").val(),
      details: this.$("#details").val(),
      date: date
    },
    {
      error: function (model, errors) {
        _.each(errors, function (error) {
          var control_group = that.$("#" + error.attr).parents(".control-group");
          control_group.addClass('error');
          control_group.find('.help-inline').text(error.message);
        });
        that.$(":input").prop('disabled', false);
      },
      success: function (model) {
        model.bindToServer();
        that.$el.modal('hide');
        that.$(":input").prop('disabled', false);
      }
    });
  },

  render: function () {
    this.$(".modal-body").html(this.template({
      title: '',
      details: '',
      date: this.parent_date,
      hard_course: this.parent_course
    }));
    this.$("#date").datepicker();
    return this;
  }

});

EditAssignmentView = Backbone.View.extend({

  el: $("#edit-assignment-modal"),
  template: undefined,

  events: {
    "click button#save":      "save",
    "click button#delete":    "_delete",
    "hidden":                 "remove"
  },

  initialize: function (options) {
    this.template = options.template;
    // this.model.on('change', this.render, this);
    this.render();
  },

  show: function () {
    this.$el.modal({
      keyboard: false,
      backdrop: 'static'
    });
  },

  save: function () {
    var that = this;
    var date = this.$("#date").val();

    // Disable all form elements to prevent
    // double-submissions.
    this.$(":input").prop('disabled', true);

    // If the date isn't blank, parse it.
    // If it is, just leave it false-y and let
    // validation mark it as missing.
    if (date) {
      date = moment(date, DATE_EDIT_FORMAT).valueOf();
    }

    this.model.save({
      title: this.$("#title").val(),
      details: this.$("#details").val(),
      course: this.$("#course").val(),
      date: date
    },
    {
      error: function (model, errors) {
        _.each(errors, function (error) {
          var control_group = that.$("#" + error.attr).parents(".control-group");
          control_group.addClass('error');
          control_group.find('.help-inline').text(error.message);
        });
        that.$(":input").prop('disabled', false);
      },
      success: function () {
        that.$el.modal('hide');
        that.$(":input").prop('disabled', false);
      }
    });
  },

  _delete: function () {
    var that = this;
    this.model.destroy({
      wait: true,
      success: function () {
        this.$(".tooltip").remove();
        that.$el.modal('hide');
      }
    });
  },

  render: function () {
    this.$(".modal-body").html(this.template(this.model.toJSON()));
    this.$("#date").datepicker();
    this.$('[rel=tooltip]').tooltip();
    return this;
  }

});

AddCourseView = Backbone.View.extend({
  el: $("#add-course-modal"),
  template: edit_course_template,

  events: {
    "click button#add":    "add",
    "hidden":              "remove"
  },

  initialize: function (options) {
    this.render();
  },

  show: function () {
    this.$el.modal({
      backdrop: 'static'
    });
  },

  add: function () {
    var that = this;

    // Disable all form elements to prevent
    // double-submissions.
    this.$(":input").prop('disabled', true);

    window.courses.create({
      title: this.$("#title").val(),
      teacher: this.$("#teacher").val()
    },
    {
      error: function (model, errors) {
        _.each(errors, function (error) {
          var control_group = that.$("#" + error.attr).parents(".control-group");
          control_group.addClass('error');
          control_group.find('.help-inline').text(error.message);
        });
        that.$(":input").prop('disabled', false);
      },
      success: function (model) {
        model.bindToServer();
        that.$el.modal('hide');
        that.$(":input").prop('disabled', false);
        // Switch to newly navigated course
        router.navigate("courses/" + model.id, true);
      }
    });
  },

  render: function () {
    // Empty context needed for template reuse
    // (Handlebars doesn't like undefined vars)
    this.$(".modal-body").html(this.template({
      title: '',
      teacher: ''
    }));
    return this;
  }

});

EditCourseView = Backbone.View.extend({

  el: $("#edit-course-modal"),
  template: edit_course_template, 

  events: {
    "click button#save":       "save",
    "click button#delete":     "_delete",
    "hidden":                  "remove"
  },

  initialize: function (options) {
    this.render();
  },

  show: function () {
    this.$el.modal({
      backdrop: 'static'
    });
  },

  save: function () {
    var that = this;

    // Disable all form elements to prevent
    // double-submissions.
    this.$(":input").prop('disabled', true);

    this.model.save({
      title: this.$("#title").val(),
      teacher: this.$("#teacher").val()
    },
    {
      error: function (model, errors) {
        _.each(errors, function (error) {
          var control_group = that.$("#" + error.attr).parents(".control-group");
          control_group.addClass('error');
          control_group.find('.help-inline').text(error.message);
        });
        that.$(":input").prop('disabled', false);
      },
      success: function () {
        that.$el.modal('hide');
        that.$(":input").prop('disabled', false);
      }
    });
  },

  _delete: function () {
    var that = this;
    this.model.destroy({
      wait: true,
      success: function () {
        this.$(".tooltip").remove();
        that.$el.modal('hide');
        router.navigate('', true);
      }
    });
  },

  render: function () {
    this.$(".modal-body").html(this.template({
      title: '',
      details: '',
      date: ''
    }));
    this.$(".modal-body").html(this.template(this.model.toJSON()));
    this.$('[rel=tooltip]').tooltip();
    return this;
  }

});

AssignmentView = Backbone.View.extend({

  tagName: 'tr',
  className: 'assignment',
  template: undefined,

  events: {
    "click td.done-toggle": "toggleDone",
    "click button.button-edit": "edit"
  },

  initialize: function (options) {
    this.template = options.template;
    this.model.view = this;
    this.model.on('change', this.render, this);
    this.model.on('update:course', this.remove, this);
    this.model.on('destroy', this.remove, this);
    app.on('details:show details:hide', this.render, this);
  },

  remove: function () {
    this.model.off('change', this.render);
    this.model.off('update:course', this.remove);
    this.model.off('destroy', this.remove);
    app.off('details:show details:hide', this.render);
    this.$el.remove();
  },

  render: function () {
    var context = this.model.toJSON();
    context.show_details = app.showing_details;

    // Set the `course` field to be the course's
    // title, not it's _id.
    context.course = this.model.get('course').get('title');

    // Render the template
    this.$el.html(this.template(context));

    // Visually mark the assignment as done.
    if (context.done) {
      this.$el.addClass("done");
      this.$(".overdue").removeClass("overdue");
    } else {
      this.$el.removeClass("done");
    }

    return this;
  },

  edit: function () {
    var edit_dialog = new EditAssignmentView({
      template: edit_assignment_template,
      model: this.model
    });
    edit_dialog.show();
  },

  toggleDone: function (event) {
    this.model.set({
      done: !this.model.get('done'),
      archived: false
    });
    this.model.save();
  }

});

DatesView = Backbone.View.extend({

  template: undefined,
  title: "Untitled",
  range: {start: undefined, end: undefined},
  _children: [],

  events: {
    "click button.add-button": "createAssignment",
    "click button.archive-button": "archiveDone"
  },

  initialize: function (options) {
    this.template = options.template;
    this.title = options.title;
    this.range = options.range;
    app.on('global:add:assignments', this.render, this);
    app.on('archived:show archived:hide', this.render, this);
  },

  remove: function () {
    app.off('global:add:assignments', this.render);
    app.off('archived:show archived:hide', this.render);
    this.removeChildren();
  },

  render: _.throttle(function () {
    console.log("render DateView");
    this.removeChildren();

    this.models = courses.get_assignments(this.range.start, this.range.end, "any");

    var unarchived = _.reject(this.models, function (assignment) {
      return assignment.get('archived');
    });

    var empty = unarchived.length === 0 && !app.showing_archived;
    this.$el.html(this.template({
      title: this.title,
      range: this.range,
      show_archive_button: !app.showing_archived,
      empty: empty
    }));

    if (app.showing_archived) {
      to_render = this.models;
    } else {
      to_render = unarchived;
    }
    
    to_render = _.sortBy(to_render, function(assignment) {
      return assignment.get('date');
    });

    var that = this;
    _.each(to_render, function (assignment) {
      var view = new AssignmentView({model: assignment, template: date_assignment_template});
      assignment.on('change:done', that.updateArchivable, that);
      assignment.on('change:archived update:course', that.render, that);
      assignment.on('change:date', that.dateChanged, that);
      that._children.push({view: view, model: assignment});
      that.$("tbody").prepend(view.render().el);
    });
    if (!empty) {
      this.updateArchivable();
    }

    // Re-sort the courses and update
    // the sidebar,
    courses.sort();
    window.app.updateCourses();

    return this;
  }, 100),

  createAssignment: function () {
    // Intelligent defaults for date ranges
    // when adding assignments to a specific range,
    // based on the range itself.
    if (this.range.end === tomorrow.valueOf()) {
      var date = tomorrow.valueOf();
    }
    else if (this.range.start === big_bang.valueOf()) {
      var date = yesterday.valueOf();
    }
    else {
      var date = this.range.start;
    }
    var that = this;
    var add_dialog = new AddAssignmentView({
      template: edit_assignment_template,
      model: this.model,
      date: date
    });
    add_dialog.show();
  },

  dateChanged: function (assignment) {
    if (this.range.start > assignment.get('date') || assignment.get('date') > this.range.end) {
      for (var i in this.models) {
        model = this.models[i];
        if (model.id === assignment.id) {
          this.models.splice(i, 1);
          break;
        }
      }
      this.render();
    }
  },

  // If there is at least one assignment that is done and unarchived, enable
  // the archive button.
  updateArchivable: _.throttle(function () {
    if (!app.showing_archived) {
      console.log("updateArchivable")
      var any_done = _.any(_.filter(this.models, function (assignment) {
        return assignment.get('done') && !assignment.get('archived');
      }));
      this.$("button.archive-button").attr('disabled', !any_done);
    }
  }, 100),

  archiveDone: function () {
    var done = _.filter(this.models, function (assignment) {
        return assignment.get('done');
    });
    _.each(done, function (assignment) {
      assignment.save({archived: true});
    });
    this.render();
  },

  removeChildren: function () {
    var that = this;
    _.each(this._children, function (child) {
      child.view.remove();
      child.model.off('change:done', that.updateArchivable);
      child.model.off('change:archived update:course', that.render);
      child.model.off('change:date', that.dateChanged);
    });
    // And reset the array of child views.
    this._children = [];
  }

});

SectionView = Backbone.View.extend({

  template: course_template,
  // Child views for removal purposes
  _children: [],

  events: {
    "click button.add-button": "createAssignment",
    "click button.edit-button": "edit",
    "click button.archive-button": "archiveDone"
  },

  initialize: function (options) {
    this.model.on('destroy', this.remove, this);
    this.model.on('change', this.render, this);
    this.model.on('add:assignments', this.render, this);
    this.model.on('reset:assignments', this.render, this);
    app.on('archived:show archived:hide', this.render, this);
  },

  remove: function () {
    this.model.off('destroy', this.remove);
    this.model.off('change', this.render);
    this.model.off('add:assignments', this.render);
    this.model.off('reset:assignments', this.render);
    app.off('archived:show archived:hide', this.render);
    this.removeChildren();
  },

  render: _.throttle(function () {
    // Remove child views previously added
    this.removeChildren();

    console.log('render SectionView')
    var assignments = this.model.get('assignments');

    var num_archived = assignments.filter(function (assignment) {
      return assignment.get('archived');
    }).length;

    // Add an archive change handler to each of the assignments
    // even though they might not be visible right now.
    var that = this;
    _.each(assignments.models, function (assignment) {
      assignment.on('change:archived', that.render, that);
      that._children.push({view: null, model: assignment});
    });

    var unarchived = assignments.reject(function (assignment) {
      return assignment.get('archived');
    });

    var empty = unarchived.length === 0 && !app.showing_archived;
    this.$el.html(course_template({
      title: this.model.get('title'),
      teacher: this.model.get('teacher'),
      archived: num_archived,
      show_archive_button: !app.showing_archived,
      empty: empty
    }));

    // Thinking about removing this, hot shot?
    // Go ahead, see what happens. Seriously
    // though, DO NOT FUCKING TOUCH THIS.
    // (If you actually want to know, it's
    // probably something with backbone-relational
    // `addAssignment` gets called way more than it
    // should anyway.)
    if (!empty) {
      if (app.showing_archived) {
        this.addAssignments(assignments.models);
      } else {
        this.addAssignments(unarchived);
      }
      // There's no real reason updateArchivable
      // needs to be in here, but there's no
      // reason to call if it's empty..
      this.updateArchivable();
    }

    // Re-sort the courses and update
    // the sidebar,
    courses.sort();
    window.app.updateCourses();

    return this;
  }, 100),

  edit: function () {
    var edit_dialog = new EditCourseView({
      model: this.model
    });
    edit_dialog.show();
  },

  createAssignment: function () {
    var add_dialog = new AddAssignmentView({
      template: edit_assignment_template,
      model: this.model,
      course: this.model.id
    });
    add_dialog.show();
  },

  addAssignment: function (assignment, course) {
    // XXX: https://github.com/PaulUithol/Backbone-relational/issues/48
    var assignment_with_id = this.$("div[data-id='" + assignment.get('_id') + "']");
    if (assignment_with_id.length === 0) {
      // If there is no `tbody` element to prepend,
      // to (which would indicate that the course
      // has no visible tasks), then stop right
      // here and render the whole thing.
      // The assignment will then be added in the
      // addAssignments() call of render().
      if (this.$("tbody").length === 0) {
        return this.render();
      }
      var view = new AssignmentView({
        model: assignment,
        template: course_assignment_template
      });
      assignment.on('change:archived change:done', this.updateArchivable, this);
      assignment.on('change:archived', this.updateArchivable, this);
      assignment.on('destroy', this.render, this);
      this._children.push({view: view, model: assignment});
      this.$("tbody").append(view.render().el);
    }
  },

  addAssignments: function (assignments) {
    _.each(assignments, this.addAssignment, this);
  },

  // If there is at least one assignment that is done
  // and unarchived, enable the archive button.
  updateArchivable: _.throttle(function () {
    if (!app.showing_archived) {
      console.log('updateArchivable');
      var done_and_unarchived = this.model.get('assignments').where({
        done: true,
        archived: false
      }).length;
      this.$("button.archive-button").attr('disabled', !done_and_unarchived);
    } 
  }, 100),

  archiveDone: function () {
    var done = this.model.get('assignments').filter(function (assignment) {
        return assignment.get('done');
    });
    _.each(done, function (assignment) {
      assignment.save({archived: true});
    });
    this.render();
  },

  removeChildren: function () {
    var that = this;
    _.each(this._children, function (child) {
      if (child.view) {
        child.view.remove();
      }
      child.model.off('change:archived change:done', that.updateArchivable);
      child.model.off('change:archived', that.render);
      child.model.off('destroy', that.render);
    });
    // And reset the array of child views.
    this._children = [];
  }

});

AppView = Backbone.View.extend({

  el: $("body"),
  showing_archived: false,
  update_timer: null,
  num_new: 0,

  events: {
    "click #toggle-details": "toggleDetails",
    "click #toggle-archived": "toggleArchived",
    "click #settings": "showSettings",
    "click #shortcuts": "showShortcuts",
    "click #add-course": "addCourse",
    "click #force-refresh": "forceRefresh",
    "click a:not([data-bypass])" : "handleLink"
  },

  initialize: function () {
    var that = this;
    // Create models & collections.
    window.settings = new Settings;
    window.settings_view = new SettingsView({model: settings});
    window.app_status = new Status;
    window.status_view = new StatusView({model: app_status});

    socket.on('connect', function () {
      // First log in
      if (settings.get('firstrun')) {
       app_status.set({
         heading: "Success!",
         message: "I hope you'll find me useful, and remember to DO YOUR HOMEWORK!",
         kind: "success"
       });   
       settings.save({firstrun: false});
      }
      // Cache has expired
      else if ((moment() - settings.getUpdatedAt()) > CACHE_TTL) {
        app_status.set({
          heading: "Heads up!",
          message: "I haven't checked the school website for new homework " +
          "in a while. I'm doing that now, and I'll load it in below ASAP.",
          kind: "info"
        });
        that.refresh();
      } else {
        that.updateUpdatedAt();
      }
      that.update_timer = setInterval(that.updateUpdatedAt, 20000);
    });

    socket.on('reconnecting', function (timeout, attempt_num) {
      if (attempt_num === 5) {
        // Close any and all open modals.
        $(".modal, .modal-backdrop").not("#failure-modal").remove();
        $("#failure-modal").modal({
          backdrop: 'static',
          keyboard: false
        });
        // If you try to reconnect, don't. For whatever reason
        // the socket will still try even after the attempt_num
        // is at it's max.
        socket.on('reconnecting', socket.disconnect);
      }
    });

    socket.on('refresh:start', this.handleRemoteRefreshStart);
    socket.on('refresh:end', this.handleRemoteRefreshEnd);

    window.router.on('highlight', this.highlightSidebar, this);
    courses.on('change remove reset add', this.updateCourses, this);

    this.bindShortcuts();
  },

  refresh: function () {
    socket.emit('refresh');
  },

  bindShortcuts: function () {
    var that = this;
    // Add course
    key('c', function () {
      that.addCourse();
    });

    // Add assignment
    key('a', function () {
      // We trigger a DOM element event here rather
      // than call an actual function because the
      // addAssignment function changes with the course
      // view, and there's no sense in unbinding and 
      // rebinding the shortcut each time.
      $(".add-button").click();
    });

    // Toggle archived
    key('shift + a', function () {
      that.toggleArchived({silent: true});
    });

    // Toggle details
    key('shift + d', function () {
      that.toggleDetails({silent: true});
    });

    // Force refresh
    key('shift + r', function () {
      that.forceRefresh({silent: true});
    });
  },

  updateUpdatedAt: function () {
    app_status.set({
      heading: "",
      message: "Last sync with school website: " + settings.getUpdatedAt().from(moment()) + ".",
      kind: "info"
    });
  },

  toggleDetails: function (options) {
    if (this.showing_details) {
      this.hideDetails();
    } else {
      this.showDetails();
    }
    if (!options.silent) {
      $('.dropdown-toggle').dropdown('toggle');
    }
    return false;
  },

  toggleArchived: function (options) {
    if (this.showing_archived) {
      this.hideArchived();
    } else {
      this.showArchived();
    }
    if (!options.silent) {
      $('.dropdown-toggle').dropdown('toggle');
    }
    return false;
  },

  handleLink: function (event) {
    var target = $(event.target)
    // Little hack for the upcoming sidebar
    // (Clicking on the badge itself, which
    // doesn't have an href element, causes
    // it to behave like a normal link.
    if (target.hasClass('badge')) {
      target = target.parent();
    }
    // Get the anchor href and protcol
    var href = $(target).attr("href");
    var protocol = window.location.protocol + "//";

    // Ensure the protocol is not part of URL, meaning its relative.
    if (href && href.slice(0, protocol.length) !== protocol &&
        href.indexOf("javascript:") !== 0) {
      // Stop the default event to ensure the link will not cause a page
      // refresh.
      event.preventDefault();

      // This uses the default router defined above, and not any routers
      // that may be placed in modules.  To have this work globally (at the
      // cost of losing all route events) you can change the following line
      // to: Backbone.history.navigate(href, true);
      router.navigate(href, true);
    }
  },

  addCourse: function () {
    var add_dialog = new AddCourseView();
    add_dialog.show();
  },

  highlightSidebar: function () {
    this.$('li.active:not(.nav-link)').removeClass('active');
    this.$("a[href='" + Backbone.history.fragment + "']").parent().addClass('active');
  },

  handleRemoteRefreshStart: function () {
    clearInterval(app.update_timer);
    app.update_timer = null;
    window.app_status.set({
      heading: "Refreshing...",
      message: "I'm pulling down the latest homework from the school website.",
      kind: "info"
    });
  },

  handleRemoteRefreshEnd: function (data) {
    var err = data.err;
    var res = data.res;

    if (err) {
      app_status.set({
        heading: "Refresh failed!",
        message: "Shoot, something went wrong. Try again or nag Avi.",
        kind: "error"
      });
      status_view.alert();
    } else {
      var num_new = res.new_assignments + app.num_new;
      if (num_new === 1) {
        var message = "There was <b>1</b> new assignment synced from the school website.";
        var link_text = "Click here to add it."
      } else {
        var message = "There were <b>" + num_new + "</b> new assignments synced from the school website.";
        var link_text = "Click here to add them."
      }
      if (num_new === 0) {
        app.update_timer = setInterval(app.updateUpdatedAt, 20000);
      }
      app.num_new = num_new;
      app_status.set({
        heading: "Refresh complete!",
        message: message,
        link_text: link_text,
        kind: "success",
        addable: Boolean(num_new)
      });
      status_view.alert();
    }

    // Fetch the latest status (for the last_updated info)
    window.settings.fetch();
  },

  forceRefresh: function (options) {
    this.refresh();
    if (!options.silent) {
      $('.dropdown-toggle').dropdown('toggle');
    }
    return false;
  },

  showSettings: function () {
    window.settings_view.show();
    $('.dropdown-toggle').dropdown('toggle');
    return false;
  },

  showShortcuts: function () {
    $("#shortcuts-modal").modal();
    $('.dropdown-toggle').dropdown('toggle');
    return false;
  },

  updateUpcoming: _.throttle(function () {
    $("#sidebar-upcoming").html(sidebar_dates_template({dates: UPCOMING_DATES}));
    app.highlightSidebar();
  }, 100),

  updateCourses: _.throttle(function () {
    $("#sidebar-courses").html(sidebar_courses_template({courses: courses.toJSON()}));
    app.highlightSidebar();
  }, 100),

  showDetails: function () {
    $("#toggle-details").html('<i class="icon-ok"></i> Show details');
    this.showing_details = true;
    this.trigger("details:show");
  },

  hideDetails: function () {
    $("#toggle-details").html("Show details");
    this.showing_details = false;
    this.trigger("details:hide");
  },

  showArchived: function () {
    $("#toggle-archived").html('<i class="icon-ok"></i> Show archived');
    this.showing_archived = true;
    this.trigger("archived:show");
  },

  hideArchived: function () {
    $("#toggle-archived").html("Show archived");
    this.showing_archived = false;
    this.trigger("archived:hide");
  },

  setFavicon: function (favicon) {
    var link = document.createElement('link');
    link.type = 'image/x-icon';
    link.rel = 'shortcut icon';
    link.href = '/img/glyph/' + favicon + ".png";
    document.getElementsByTagName('head')[0].appendChild(link);
  }

});

SetupView = Backbone.View.extend({

  el: $("body"),

  events: {
    "click #gobutton": "go"
  },

  initialize: function () {
    // Create models & collections.
    window.settings = new Settings;
    window.app_status = new Status;
    window.status_view = new StatusView({model: app_status});

    socket.on('connect', function () {
      $("#nickname").focus();
      socket.emit('refresh', {archive_if_old: true});
    });

    socket.on('refresh:start', this.handleRemoteRefreshStart);
    socket.on('refresh:end', this.handleRemoteRefreshEnd);

    socket.on('disconnect', function () {
      // Close any and all open modals.
      $(".modal, .modal-backdrop").not("#failure-modal").remove();
      $("#failure-modal").modal({
        backdrop: 'static',
        keyboard: false
      });
      // If you try to reconnect, don't. For whatever reason
      // the socket will still try even after the attempt_num
      // is at it's max.
      socket.on('reconnecting', socket.disconnect);
    });
  },

  handleRemoteRefreshStart: function () {
    app_status.set({
      heading: "Processing...",
      message: "I'll tell you when I'm finished.",
      kind: "info"
    });
  },

  handleRemoteRefreshEnd: function (data) {
    var err = data.err;
    var res = data.res;

    if (err) {
      app_status.set({
        heading: "Uh oh",
        message: "Something went wrong setting up your account. Refresh to try again.",
        kind: "error"
      });
    } else {
      app_status.set({
        heading: "Done!",
        message: "Ready when you are.",
        kind: "success"
      });
      $("#gobutton").prop('disabled', false);
    }

    status_view.alert();
  },

  go: function () {
    this.model.save();
  }

});

function benchmarkCurrentView (n) {

  console.log("Benchmarking...")
  var start = moment();
  for (var i = 0; i < n; i++) {
    router.current_view.render()
  }
  var end = moment();
  var ms = moment().diff(start);
  console.log("Total time (ms): " + ms);
  console.log("Avg time (ms): " + ms/n);
}