let sample_ics : String =
  "BEGIN:VCALENDAR\n" +
  "VERSION:2.0\n" +
  "PRODID:-//Example//Calendar//EN\n" +
  "BEGIN:VEVENT\n" +
  "UID:1@example.com\n" +
  "DTSTART:20261024T093000Z\n" +
  "DTEND:20261024T103000Z\n" +
  "SUMMARY:Team standup\n" +
  "DESCRIPTION:Discuss plan\\nBring coffee\n" +
  "END:VEVENT\n" +
  "BEGIN:VEVENT\n" +
  "UID:2@example.com\n" +
  "DTSTART;VALUE=DATE:20261025\n" +
  "END:VEVENT\n" +
  "END:VCALENDAR\n"

test "parse_calendar returns the VCALENDAR root" {
  let cal = parse_calendar(sample_ics)
  assert_eq(cal.name, "VCALENDAR")
  assert_eq(cal.children_named("VEVENT").length(), 2)
  assert_eq(cal.get("VERSION").unwrap().value, "2.0")
}

test "event accessors read typed values" {
  let cal = parse_calendar(sample_ics)
  let events = cal.children_named("VEVENT")
  let first = events[0]
  assert_eq(first.get("UID").unwrap().value, "1@example.com")
  assert_eq(first.get("SUMMARY").unwrap().value, "Team standup")
  let start = first.get("DTSTART").unwrap().as_date_time()
  assert_eq(start.date.year, 2026)
  assert_eq(start.time.hour, 9)
  assert_true(start.time.utc)
}

test "a DATE-valued DTSTART is read as a date" {
  let cal = parse_calendar(sample_ics)
  let second = cal.children_named("VEVENT")[1]
  let prop = second.get("DTSTART").unwrap()
  assert_eq(prop.param("VALUE"), Some("DATE"))
  let d = prop.as_date()
  assert_eq(d.year, 2026)
  assert_eq(d.month, 10)
  assert_eq(d.day, 25)
}

test "property values are unescaped on parse" {
  let cal = parse_calendar(sample_ics)
  let desc = cal.children_named("VEVENT")[0].get("DESCRIPTION").unwrap()
  assert_eq(desc.value, "Discuss plan\nBring coffee")
}

test "get returns None for an absent property or parameter" {
  let cal = parse_calendar(sample_ics)
  let first = cal.children_named("VEVENT")[0]
  assert_true(first.get("LOCATION") is None)
  assert_true(first.get("DTSTART").unwrap().param("TZID") is None)
}

test "parse_calendar rejects a mismatched END" {
  let bad = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR\nEND:VCALENDAR\n"
  let caught = try {
    let _ = parse_calendar(bad)
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_calendar rejects a non-calendar root" {
  let caught = try {
    let _ = parse_calendar("BEGIN:VEVENT\nEND:VEVENT\n")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_calendar rejects an unterminated component" {
  let caught = try {
    let _ = parse_calendar("BEGIN:VCALENDAR\nVERSION:2.0\n")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}
