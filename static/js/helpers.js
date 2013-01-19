// Copyright (C) 2013 Avi Romanoff <aviromanoff at gmail.com>

// Contains Handlebars helper functions,
// date constants and date utility functions,
// as well as other various utility functions
// and constants.


// Pre-compile dates.
function compileDateConstants () {
  // XXX: Hacky implementation of date generation
  // Specifically, what's with UTC and local vs
  // server timezones?
  _now = moment();
  today = moment.utc([_now.year(), _now.month(), _now.date()]);
  yesterday = moment(today).subtract('days', 1);
  tomorrow = moment(today).add('days', 1);
  in_a_week = moment(today).add('weeks', 1);
  in_two_weeks = moment(today).add('weeks', 2);
  big_bang = moment(0).utc(); // Actually 1970
  doomsday = moment(9999999999999).utc(); // Actually 2286 lol
}

compileDateConstants();

// Returns the date which is the last day
// of the current school week.
function getEndOfWeek () {
  var wanted = _.indexOf(moment.weekdays, "Friday");
  for (var i = 1; i < 8; i++) {
    var new_date = moment(today).add('days', i);
    if (new_date.day() === wanted) {
      return new_date;
    }
  }
}

// Returns the date which is the first day
// of the current school week, or of the upcoming
// week if currently on a weekend.
function getStartOfWeek () {
  var wanted = _.indexOf(moment.weekdays, "Monday");
  // It's a weekend (Friday, Saturday, Sunday)
  if (_.indexOf([5,6,0], today.day()) !== -1) {
    var start = 1;
    var end = 4;
  } else {
    var start = -3;
    var end = 1;
  }
  for (var i = start; i < end; i++) {
    var new_date = moment(today).add('days', i);
    if (new_date.day() === wanted) {
      return new_date;
    }
  }
}

// Date range information which powers
// the "Upcoming" sidebar
UPCOMING_DATES = [
  {
    name: "Overdue",
    link: "overdue",
    start: big_bang.valueOf(),
    end: yesterday.valueOf()
  },
  {
    name: "Today",
    link: "today",
    start: today.valueOf(),
    end: today.valueOf()
  },
  {
    name: "Tomorrow",
    link: "tomorrow",
    start: tomorrow.valueOf(),
    end: tomorrow.valueOf()
  },
  {
    name: "This Week",
    link: "week",
    start: getStartOfWeek().valueOf(),
    end: getEndOfWeek().valueOf()
  },
  {
    name: "Next 2 Weeks",
    link: "fortnight",
    start: getStartOfWeek().valueOf(),
    end: moment(getEndOfWeek()).add('weeks', 1).valueOf()
  },
  {
    name: "All Assignments",
    link: "all",
    start: big_bang.valueOf(),
    end: doomsday.valueOf()
  }
];

DATE_MAP = {}

// Generates DATE_MAP object from UPCOMING_DATES array.
_.map(UPCOMING_DATES, function (date) {
  DATE_MAP[date.link] = _.pick(date, ['name', 'start', 'end']);
});

// Number of ms that represents
// the maximum time difference for 
// issuing a refresh command to the server
// That is, if the current time is greater
// than CACHE_TTL ms away from the previous
// refresh time, a refresh is requested.
// 3600000 ms = 1 hour
CACHE_TTL = 2 * 3600000;

// Moment-style date formats used for rendering
// dates in templates.
var DATE_FORMAT = "dddd MMM D";
var DATE_RANGE_FORMAT = "dddd, MMMM Do YYYY";
var DATE_EDIT_FORMAT = "M/D/YY";

// Returns copy of string 'body' with all instances
// of %n replaced with the user's nickname.
Handlebars.registerHelper('personalize', function (body) {
  return body.replace("%n", settings.get('nickname'));
});

// Identifies quiz/test keywords in string title
// and creates labels for the appropriate assessment type.
Handlebars.registerHelper('keyword', function (title) {
  if (title.search(/quiz/i) !== -1) {
    return new Handlebars.SafeString('<span class="label label-warning">Quiz</span>');
  }
  else if (title.search(/test/i) !== -1) {
    return new Handlebars.SafeString('<span class="label label-important">Test</span>');
  }
});

var exclamations = ["Woo-hoo", "Rock on", "Sweet", "Right on", "Nice", "Congrats"];
var rando = Math.floor(Math.random() * exclamations.length);

// Returns a random exclamation string. Used for empty
// DatesView/SectionView templates.
Handlebars.registerHelper('exclamation', function () {
  return exclamations[rando] + "!";
});

// Returns the # of assignments which are not 'done'
// accross all courses between the dates 'start' and 'end'.
Handlebars.registerHelper('remaining', function (start, end) {
  var num = courses.get_assignments(start, end, "only undone").length;
  var badge = '';
  if (num >= 1) {
    badge = 'badge-important';
  }
  return new Handlebars.SafeString('<span class="badge ' + badge + '">' + num + '</span>');
});

// Returns a string representation of a given date.
// For use in AssignmentView templates.
Handlebars.registerHelper('format_date', function (epoch) {
  var date = moment.utc(epoch);
  var str = "";

  if (date.valueOf() < yesterday.valueOf()) {
    str = '<span class="overdue">' + date.format(DATE_FORMAT) + '</span>';
  }
  else if (date.valueOf() == yesterday.valueOf()) {
    str = '<span class="overdue">Yesterday</span>';
  }
  else if (date.valueOf() == today.valueOf()) {
    str = '<span class="overdue">Today</span>';
  }
  else if (date.valueOf() == tomorrow.valueOf()) {
    str = "Tomorrow";
  }
  else {
    str = date.format(DATE_FORMAT);
  }

  return str;
});

// Returns a properly formatted string representation
// of a date for use with bootstrap-datepicker. 
Handlebars.registerHelper('editable_date', function (epoch) {
  // If it's a blank value, don't try to format it.
  if (epoch === '') {
    return epoch;
  }

  return moment.utc(epoch).format(DATE_EDIT_FORMAT);
});

// Returns a string representation of the range of
// dates, with special cases for edge dates and overlapping
// ranges (ranges.start == ranges.end)
Handlebars.registerHelper('range_date', function (ranges) {
  var start = ranges.start;
  var end = ranges.end;
  var str = "";

  if (start === end) {
    // Only one day
    str += moment.utc(start).format(DATE_RANGE_FORMAT);
  } else {
    if (start === big_bang.valueOf()) {
      // No (real) start date
      str += "The Big Bang"
    } else {
      // Specific start date
      str += moment.utc(start).format(DATE_RANGE_FORMAT);
    }
    str += " to "
    if (end === doomsday.valueOf()) {
      // No (real) end date
      str += "Doomsday";
    } else {
      // Specific end date
      str += moment.utc(end).format(DATE_RANGE_FORMAT);
    }
  }

  return str;
});

// Used to generate the HTML dropdown menu
// containing all possible options for an assignment's
// date. Used in AddAssignmentView and EditAssignmentView
// templates.
Handlebars.registerHelper('course_options', function (course_id) {
  str = "";

  _.each(courses.pluck("_id"), function (current_id) {
    str += "<option";
    if (current_id === course_id) {
      str += " selected";
    }
    str += ' value="' +
    current_id +
    '">' +
    courses.get(current_id).get('title') +
    "</option>\n";
  });

  return str;
});