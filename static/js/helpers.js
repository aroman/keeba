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

UPCOMING_DATES = [
  {
    name: "Today",
    link: "today",
    epoch: today.valueOf()
  },
  {
    name: "Tomorrow",
    link: "tomorrow",
    epoch: tomorrow.valueOf()
  },
  {
    name: "This Week",
    link: "week",
    epoch: in_a_week.valueOf()
  },
  {
    name: "Next 2 Weeks",
    link: "two-week",
    epoch: in_two_weeks.valueOf()
  },
  {
    name: "All Assignments",
    link: "all",
    epoch: 9999999999999 // Year 2286 lol
  }
];

DATE_MAP = {}

_.map(UPCOMING_DATES, function (date) {
  DATE_MAP[date.link] = _.pick(date, ['name', 'epoch']);
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

Handlebars.registerHelper('remaining', function (end) {
  var num = courses.get_assignments(today.valueOf(), end, "only undone").length;
  var badge = '';
  if (num >= 1) {
    badge = 'badge-error';
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
  if (ranges.end === 9999999999999) {
    return "Every assignment ever"
  } else {
    return " Up to " + moment(ranges.end).format(DATE_RANGE_FORMAT);
  }
});
