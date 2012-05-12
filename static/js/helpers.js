// Compile templates
sidebar_courses_template = Handlebars.compile($("#sidebar-courses-template").html());
sidebar_dates_template = Handlebars.compile($("#sidebar-dates-template").html());

course_template = Handlebars.compile($("#course-template").html());
course_assignment_template = Handlebars.compile($("#course-assignment-template").html());

dates_template = Handlebars.compile($("#dates-template").html());
date_assignment_template = Handlebars.compile($("#date-assignment-template").html());

status_template = Handlebars.compile($("#status-template").html());
settings_template = Handlebars.compile($("#settings-template").html());
home_template = Handlebars.compile($("#home-template").html());

edit_course_assignment_template = Handlebars.compile($("#edit-course-assignment-template").html());
edit_course_template = Handlebars.compile($("#edit-course-template").html());

_now = moment();
today = moment([_now.year(), _now.month(), _now.date()]);
yesterday = moment(today).subtract('days', 1);
tomorrow = moment(today).add('days', 1);
in_a_week = moment(today).add('weeks', 1);
in_two_weeks = moment(today).add('weeks', 2);

function getEndOfWeek () {
  for (var i = 1; i < 7; i++) {
    var new_date = moment(today).add('days', i);
    // The day is actually friday.
    if (new_date.day() === 5) {
      return new_date;
    }
  }
}

UPCOMING_DATES = [
  {
    name: "Overdue",
    link: "overdue",
    start: 0,
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
    start: today.valueOf(),
    end: tomorrow.valueOf()
  },
  {
    name: "This Week",
    link: "week",
    start: today.valueOf(),
    end: getEndOfWeek()
  },
  {
    name: "Next 2 Weeks",
    link: "fortnight",
    start: today.valueOf(),
    end: in_two_weeks.valueOf()
  },
  {
    name: "All Assignments",
    link: "all",
    start: today.valueOf(),
    end: 9999999999999 // Year 2286 lol
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
    // More than one day
    str += moment(start).format(DATE_RANGE_FORMAT) + " to ";
    if (end === 9999999999999) {
      // No (real) end date
      str += "Doomsday";
    } else {
      // Specific end date
      str += moment(end).format(DATE_RANGE_FORMAT);
    }
  }

  return str;
});
