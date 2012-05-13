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
    this.children = this.$el.html(status_template(this.model.toJSON())).children();
    return this;
  },

  alert: function () {
    this.children.effect("bounce", {times: 2}, 300);
  },

  handleLink: function () {
    courses.fetch();
    this.model.set({addable: false});
  },

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

  events: {
    "click button":  "add",
    "hidden":        "remove"
  },

  initialize: function (options) {
    this.template = options.template;
    // this.model.on('change', this.render, this);
    this.render();
  },

  show: function () {
    this.$el.modal({
      backdrop: 'static'
    });
  },

  add: function () {
    var that = this;
    var date = this.$("#date").val();
    // If the date isn't blank, try to parse it.
    // If it is, just leave it false-y and let
    // validation mark it as missing.
    if (date) {
      date = Date.parse(date).valueOf();
    }
    this.model.get('assignments').create({
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
      },
      success: function () {
        that.$el.modal('hide');
      }
    });
  },

  render: function () {
    this.$(".modal-body").html(this.template({
      title: '',
      details: '',
      date: ''
    }));
    this.$("#date").datepicker();
    return this;
  },

});

EditAssignmentView = Backbone.View.extend({

  el: $("#edit-assignment-modal"),
  template: undefined,

  events: {
    "click button#save":      "save",
    "click button#delete":    "delete",
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
    // If the date isn't blank, try to parse it.
    // If it is, just leave it false-y and let
    // validation mark it as missing.
    if (date) {
      date = Date.parse(date).valueOf();
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
      },
      success: function () {
        that.$el.modal('hide');
      }
    });
  },

  delete: function () {
    var that = this;
    this.model.destroy({
      wait: true,
      success: function () {
        that.$el.modal('hide');
        // XXX: The tooltip gets left behind for whatever reason.
        // $(".tooltip").remove();
      }
    });
  },

  render: function () {
    this.$(".modal-body").html(this.template(this.model.toJSON()));
    this.$("#date").datepicker();
    $('[rel=tooltip]').tooltip();
    return this;
  },

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
      },
      success: function (model) {
        router.navigate("courses/" + model.id, true);
        that.$el.modal('hide');
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
  },

});

EditCourseView = Backbone.View.extend({

  el: $("#edit-course-modal"),
  template: edit_course_template, 

  events: {
    "click button#save":       "save",
    "click button#delete":    "delete",
    "hidden":                 "remove"
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
      },
      success: function () {
        that.$el.modal('hide');
      }
    });
  },

  delete: function () {
    var that = this;
    this.model.destroy({
      wait: true,
      success: function () {
        that.$el.modal('hide');
        // XXX: The tooltip gets left behind for whatever reason.
        $(".tooltip").remove();
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
    $('[rel=tooltip]').tooltip();
    return this;
  },

});

AssignmentView = Backbone.View.extend({

  tagName: 'tr',
  template: undefined,

  events: {
    "click td.done-toggle": "toggleDone",
    "click button.button-edit": "edit",
  },

  initialize: function (options) {
    this.template = options.template;
    this.model.view = this;
    this.model.on('change', this.render, this);
    // XXX: Why is this here? It causes problems. (Lots of rendering on mark done)
    // this.model.collection.on('change', this.render, this);
    this.model.on('change:done change:date', window.app.updateUpcoming, app);
    this.model.on('change:course', this.remove, this);
    this.model.on('destroy', this.remove, this);
    app.on('details:show details:hide', this.render, this);
  },

  remove: function () {
    this.model.off('change', this.render, this);
    this.model.off('change:done change:date', window.app.updateUpcoming, app);
    this.model.off('change:course', this.remove, this);
    this.model.off('destroy', this.remove, this);
    app.off('details:show details:hide', this.render, this);
    window.app.updateUpcoming();
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
      template: edit_course_assignment_template,
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

  events: {
    "click button.archive-button": "archiveDone"
  },

  initialize: function (options) {
    this.template = options.template;
    this.title = options.title;
    this.range = options.range;
    this.models = options.models;
    app.on('archived:show archived:hide', this.render, this);
  },

  remove: function () {
    app.off('archived:show archived:hide', this.render, this);
    this.$el.remove();
  },

  render: function () {
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
      to_render = this.models, "date";
    } else {
      to_render = unarchived, "date";
    }
    
    to_render = _.sortBy(to_render, function(assignment) {
      return assignment.get('date');
    });

    var that = this;
    _.each(to_render, function (assignment) {
      var view = new AssignmentView({model: assignment, template: date_assignment_template});
      assignment.on('change:done', that.updateArchivable, that);
      assignment.on('change:date', that.dateChanged, that);
      that.$("tbody").prepend(view.render().el);
    });
    if (!empty) {
      this.updateArchivable();
    }
    return this;
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
  updateArchivable: function () {
    var any_done = _.any(_.filter(this.models, function (assignment) {
      return assignment.get('done') && !assignment.get('archived');
    }));
    this.$("button.archive-button").attr('disabled', !any_done);
  },

  archiveDone: function () {
    var done = _.filter(this.models, function (assignment) {
        return assignment.get('done');
    });
    _.each(done, function (assignment) {
      assignment.set({archived: true});
      assignment.save();
    });
    this.render();
  },

});

SectionView = Backbone.View.extend({

  template: course_template,

  events: {
      "click button.archive-button": "archiveDone",
      "click button.add-button": "createAssignment",
      "click button.edit-button": "edit"
  },

  initialize: function (options) {
    this.model.on('destroy', this.remove, this);
    this.model.on('change', this.render, this);
    this.model.on('add:assignments', this.addAssignment, this);
    this.model.on('add:assignments', window.app.updateUpcoming, app);
    this.model.on('reset:assignments', this.render, this);
    app.on('archived:show archived:hide', this.render, this);
  },

  remove: function () {
    this.model.off('destroy', this.remove, this);
    this.model.off('change', this.render, this);
    this.model.off('add:assignments', this.addAssignment, this);
    this.model.off('add:assignments', window.app.updateUpcoming, app);
    this.model.off('reset:assignments', this.render, this);
    app.off('archived:show archived:hide', this.render, this);
    this.$el.remove();
  },

  render: function () {
    var num_archived = this.model.get('assignments').filter(function (assignment) {
      return assignment.get('archived');
    }).length;

    var unarchived = this.model.get('assignments').reject(function (assignment) {
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
        this.addAssignments(this.model.get('assignments').models);
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
  },

  edit: function () {
    var edit_dialog = new EditCourseView({
      model: this.model
    });
    edit_dialog.show();
  },

  createAssignment: function () {
    var add_dialog = new AddAssignmentView({
      template: edit_course_assignment_template,
      model: this.model
    });
    add_dialog.show();
  },

  addAssignment: function (assignment) {
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
      assignment.on('change:done', this.updateArchivable, this);
      this.$("tbody").prepend(view.render().el);
    }
  },

  addAssignments: function (assignments) {
    _.each(assignments, this.addAssignment, this);
  },

  // If there is at least one assignment that is done
  // and unarchived, enable the archive button.
  updateArchivable: function () {
    var done_and_unarchived = this.model.get('assignments').where({
      done: true,
      archived: false
    }).length;
    this.$("button.archive-button").attr('disabled', !done_and_unarchived);
  },

  archiveDone: function () {
    var done = this.model.get('assignments').filter(function (assignment) {
        return assignment.get('done');
    });
    _.each(done, function (assignment) {
      assignment.set({archived: true});
      assignment.save();
    });
    this.render();
  },

});

AppView = Backbone.View.extend({

  el: $("body"),
  showing_archived: false,
  update_timer: null,

  events: {
    "click #toggle-details": "toggleDetails",
    "click #toggle-archived": "toggleArchived",
    "click #settings": "showSettings",
    "click #add-course": "addCourse",
    "click #force-refresh": "forceRefresh",
    "click a:not([data-bypass])" : "handleLink"
  },

  initialize: function () {
    // Create models & collections.
    window.settings = new Settings;
    window.settings_view = new SettingsView({model: settings});
    window.app_status = new Status;
    window.status_view = new StatusView({model: app_status});

    var that = this;
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
          kind: "info",
          closable: false
        });
        that.refresh();
      } else {
        that.updateUpdatedAt();
      }
      that.update_timer = setInterval(that.updateUpdatedAt, 20000);
    });

    socket.on('disconnect', function () {
      setTimeout(function () {
        // Close any and all open modals.
        $(".modal").each(function() {
          $(this).modal({
            backdrop: 'static',
            keyboard: false,
            show: false
          });
        });
        $("#failure-modal").modal({
          backdrop: 'static',
          keyboard: false,
          show: true
        });
      }, 1000); // Slight delay to ignore normal page reloads.
    });

    // Hotkey: Add course
    key('c', function () {
      that.addCourse();
    });

    // Hotkey: Add assignment
    key('a', function () {
      // We trigger a DOM element event here rather
      // than call an actual function because the
      // addAssignment function changes with the course
      // view, and there's no sense in unbinding and 
      // rebinding the hotkey each time.
      $(".add-button").click();
    });

    // Hotkey: Toggle details
    key('d', function () {
      that.toggleDetails({silent: true});
    });

    // Hotkey: Force refresh
    key('shift + r', function () {
      that.forceRefresh({silent: true});
    });

    window.router.on('highlight', this.highlightSidebar, this);
    courses.on('change remove reset add', this.updateCourses, this);
    courses.on('reset', this.updateUpcoming, this);
  },

  refresh: function () {
    var that = this;
    clearInterval(that.update_timer);
    socket.emit('refresh', function (err, res) {
      if (err) {
        app_status.set({
          heading: "Refresh failed!",
          message: "Shoot, something went wrong. Try again or nag Avi.",
          kind: "error"
        });
        status_view.alert();
      } else {
        var num_new = res.new_assignments;
        if (num_new === 1) {
          var message = "There was <b>1</b> new assignment synced from the school website.";
        } else {
          var message = "There were <b>" + num_new + "</b> new assignments synced from the school website.";
        }
        app_status.set({
          heading: "Refresh complete!",
          message: message,
          kind: "success",
          addable: Boolean(num_new)
        });
        status_view.alert();
        // that.update_timer = setInterval(that.updateUpdatedAt, 20000);
      }
    });
  },

  updateUpdatedAt: function () {
    settings.fetch();
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

  toggleArchived: function () {
    if (this.showing_archived) {
      this.hideArchived();
    } else {
      this.showArchived();
    }
    $('.dropdown-toggle').dropdown('toggle');
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

  forceRefresh: function (options) {
    app_status.set({
      heading: "Refreshing...",
      message: "I'm pulling down the latest homework from the school website.",
      kind: "info"
    });    
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

  updateUpcoming: function () {
    $("#sidebar-upcoming").html(sidebar_dates_template({dates: UPCOMING_DATES}));
    this.highlightSidebar();
  },

  updateCourses: function () {
    $("#sidebar-courses").html(sidebar_courses_template({courses: courses.toJSON()}));
    this.highlightSidebar();
  },

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

});

// TODO: This should probably share a common
// mixin with AppView.
SetupView = Backbone.View.extend({

  el: $("body"),

  events: {
    "click #gobutton": "go",
  },

  initialize: function () {
    // Create models & collections.
    window.settings = new Settings;
    window.app_status = new Status;
    window.status_view = new StatusView({model: app_status});

    var that = this;
    socket.on('connect', function () {
      $("#nickname").focus();
      socket.emit('refresh', {archive_if_old: true}, function (err, res) {
        if (err) {
          app_status.set({
            heading: "Uh oh",
            message: "Something went wrong setting up your account. Refresh to try again.",
            kind: "error"
          });
          status_view.alert();
        } else {
          app_status.set({
            heading: "Done!",
            message: "Ready when you are.",
            kind: "success",
            closable: false
          });
          status_view.alert();
          $("#gobutton").prop('disabled', false);
        }
      });

      app_status.set({
        heading: "Processing...",
        message: "I'll tell you when I'm finished.",
        kind: "info",
        closable: false
      });
    });

    socket.on('disconnect', function () {
      // Close any and all open modals.
      setTimeout(function () {
        $(".modal").each(function() {
          $(this).modal('hide');
        });

        $("#failure-modal").modal({
          backdrop: 'static',
          keyboard: false,
          show: true
        });
      }, 1000);
    });
  },

  go: function () {
    this.model.save();
  },

});