let roundtrip_ics : String =
  "BEGIN:VCALENDAR\n" +
  "VERSION:2.0\n" +
  "PRODID:-//Example//Calendar//EN\n" +
  "BEGIN:VEVENT\n" +
  "UID:1@example.com\n" +
  "DTSTART:20261024T093000Z\n" +
  "SUMMARY:Team standup\n" +
  "END:VEVENT\n" +
  "END:VCALENDAR\n"

test "serialize then reparse preserves the calendar" {
  let cal = parse_calendar(roundtrip_ics)
  let cal2 = parse_calendar(cal.to_string())
  assert_eq(cal2.name, "VCALENDAR")
  let events = cal2.children_named("VEVENT")
  assert_eq(events.length(), 1)
  assert_eq(events[0].get("UID").unwrap().value, "1@example.com")
  assert_eq(events[0].get("SUMMARY").unwrap().value, "Team standup")
  assert_eq(events[0].get("DTSTART").unwrap().as_date_time().to_string(), "20261024T093000Z")
}

test "a value with commas and semicolons round-trips through escaping" {
  let p = Property::new("DESCRIPTION", [], "a;b,c\\d")
  let line = p.to_string()
  assert_eq(line, "DESCRIPTION:a\\;b\\,c\\\\d")
  let cl = parse_content_line(line)
  assert_eq(unescape_text(cl.value), "a;b,c\\d")
}

test "a parameter value with a delimiter is re-quoted" {
  let p = Property::new("ATTENDEE", [Param::new("MEMBER", ["a,b"])], "mailto:x@y")
  assert_eq(p.to_string(), "ATTENDEE;MEMBER=\"a,b\":mailto:x@y")
}

test "long lines are folded and unfold back to the original" {
  let mut v = ""
  let mut i = 0
  while i < 120 {
    v = v + "a"
    i = i + 1
  }
  let comp = Component::new("VEVENT", [Property::new("DESCRIPTION", [], v)], [])
  let lines = unfold(comp.to_string())
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "BEGIN:VEVENT")
  assert_eq(lines[1], "DESCRIPTION:" + v)
  assert_eq(lines[2], "END:VEVENT")
}

test "an RRULE value keeps its ; and , separators on round-trip" {
  let ics =
    "BEGIN:VCALENDAR\n" +
    "VERSION:2.0\n" +
    "BEGIN:VEVENT\n" +
    "UID:r@example.com\n" +
    "DTSTART:20261026T093000Z\n" +
    "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10\n" +
    "END:VEVENT\n" +
    "END:VCALENDAR\n"
  let cal = parse_calendar(ics)
  let ev = cal.children_named("VEVENT")[0]
  assert_eq(ev.get("RRULE").unwrap().value, "FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10")
  let cal2 = parse_calendar(cal.to_string())
  let ev2 = cal2.children_named("VEVENT")[0]
  assert_eq(ev2.get("RRULE").unwrap().value, "FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10")
  let occ = expand(parse_rrule(ev2.get("RRULE").unwrap().value), parse_date_time("20261026T093000Z"))
  assert_eq(occ.length(), 10)
}
