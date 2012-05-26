// Compile templates
sidebar_courses_template = Handlebars.compile($("#sidebar-courses-template").html());
sidebar_dates_template = Handlebars.compile($("#sidebar-dates-template").html());

course_template = Handlebars.compile($("#course-template").html());
edit_course_template = Handlebars.compile($("#edit-course-template").html());
course_assignment_template = Handlebars.compile($("#course-assignment-template").html());

dates_template = Handlebars.compile($("#dates-template").html());
date_assignment_template = Handlebars.compile($("#date-assignment-template").html());

edit_assignment_template = Handlebars.compile($("#edit-assignment-template").html());

status_template = Handlebars.compile($("#status-template").html());
settings_template = Handlebars.compile($("#settings-template").html());
home_template = Handlebars.compile($("#home-template").html());

_now = moment();
today = moment([_now.year(), _now.month(), _now.date()]);
yesterday = moment(today).subtract('days', 1);
tomorrow = moment(today).add('days', 1);
in_a_week = moment(today).add('weeks', 1);
in_two_weeks = moment(today).add('weeks', 2);
big_bang = moment(0); // Actually 1970
doomsday = moment(9999999999999); // Year 2286 lol

function getEndOfWeek () {
  var wanted = _.indexOf(moment.weekdays, "Friday");
  for (var i = 1; i < 8; i++) {
    var new_date = moment(today).add('days', i);
    if (new_date.day() === wanted) {
      return new_date;
    }
  }
}

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
    start: today.valueOf(),
    end: doomsday.valueOf()
  }
];

DATE_MAP = {}

_.map(UPCOMING_DATES, function (date) {
  DATE_MAP[date.link] = _.pick(date, ['name', 'start', 'end']);
});

// Cache TTL in ms
// 3600000 ms = 1 hour
CACHE_TTL = 2 * 3600000;

// = formatting
var DATE_FORMAT = "dddd MMM D";
var DATE_RANGE_FORMAT = "dddd, MMMM Do YYYY";
var DATE_EDIT_FORMAT = "M/D/YY";

Handlebars.registerHelper('personalize', function (body) {
  return body.replace("%n", settings.get('nickname'));
});

Handlebars.registerHelper('keyword', function (title) {
  if (title.search(/quiz/i) !== -1) {
    return new Handlebars.SafeString('<span class="label label-warning">Quiz</span>');
  }
  else if (title.search(/test/i) !== -1) {
    return new Handlebars.SafeString('<span class="label label-important">Test</span>');
  }
});

Handlebars.registerHelper('remaining', function (start, end) {
  var num = courses.get_assignments(start, end, "only undone").length;
  var badge = '';
  if (num >= 1) {
    badge = 'badge-important';
  }
  return new Handlebars.SafeString('<span class="badge ' + badge + '">' + num + '</span>');
});

Handlebars.registerHelper('format_date', function (epoch) {
  var date = moment(epoch);
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

Handlebars.registerHelper('editable_date', function (epoch) {
  // If it's a blank value, don't try to format it.
  if (epoch === '') {
    return epoch;
  }

  return moment(epoch).format(DATE_EDIT_FORMAT);
});

Handlebars.registerHelper('range_date', function (ranges) {
  var start = ranges.start;
  var end = ranges.end;
  var str = "";

  if (start === end) {
    // Only one day
    str += moment(start).format(DATE_RANGE_FORMAT);
  } else {
    if (start === big_bang.valueOf()) {
      // No (real) start date
      str += "The Big Bang"
    } else {
      // Specific start date
      str += moment(start).format(DATE_RANGE_FORMAT);
    }
    str += " to "
    if (end === doomsday.valueOf()) {
      // No (real) end date
      str += "Doomsday";
    } else {
      // Specific end date
      str += moment(end).format(DATE_RANGE_FORMAT);
    }
  }

  return str;
});

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