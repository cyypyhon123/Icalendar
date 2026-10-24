test "parse_date_list handles DATE-TIME, DATE and PERIOD" {
  let dts = parse_date_list("20260115T120000Z,20260116,20260117T100000Z/20260117T110000Z")
  assert_eq(dts.length(), 3)
  assert_eq(dts[0].to_string(), "20260115T120000Z")
  assert_eq(dts[1].to_string(), "20260116T000000")
  assert_eq(dts[2].to_string(), "20260117T100000Z")
}

test "occurrences is DTSTART plus the RRULE expansion" {
  let cal = parse_calendar(
    "BEGIN:VCALENDAR\n" +
    "BEGIN:VEVENT\n" +
    "DTSTART:20261026T093000Z\n" +
    "RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=3\n" +
    "END:VEVENT\n" +
    "END:VCALENDAR\n"
  )
  let occ = occurrences(cal.children_named("VEVENT")[0])
  assert_eq(occ.length(), 3)
  assert_eq(occ[0].to_string(), "20261026T093000Z")
  assert_eq(occ[1].to_string(), "20261102T093000Z")
  assert_eq(occ[2].to_string(), "20261109T093000Z")
}

test "occurrences adds RDATE and drops EXDATE" {
  let cal = parse_calendar(
    "BEGIN:VCALENDAR\n" +
    "BEGIN:VEVENT\n" +
    "DTSTART:20261026T093000Z\n" +
    "RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4\n" +
    "RDATE:20261028T093000Z\n" +
    "EXDATE:20261102T093000Z\n" +
    "END:VEVENT\n" +
    "END:VCALENDAR\n"
  )
  let occ = occurrences(cal.children_named("VEVENT")[0])
  assert_eq(occ.length(), 4)
  assert_eq(occ[0].to_string(), "20261026T093000Z")
  assert_eq(occ[1].to_string(), "20261028T093000Z")
  assert_eq(occ[2].to_string(), "20261109T093000Z")
  assert_eq(occ[3].to_string(), "20261116T093000Z")
}

test "occurrences de-duplicates and sorts" {
  let cal = parse_calendar(
    "BEGIN:VCALENDAR\n" +
    "BEGIN:VEVENT\n" +
    "DTSTART:20261026T093000Z\n" +
    "RRULE:FREQ=DAILY;COUNT=3\n" +
    "RDATE:20261026T093000Z,20261025T093000Z\n" +
    "END:VEVENT\n" +
    "END:VCALENDAR\n"
  )
  let occ = occurrences(cal.children_named("VEVENT")[0])
  // 10-25 (RDATE), 10-26 (DTSTART + duplicate RDATE), 10-27, 10-28
  assert_eq(occ.length(), 4)
  assert_eq(occ[0].to_string(), "20261025T093000Z")
  assert_eq(occ[1].to_string(), "20261026T093000Z")
  assert_eq(occ[2].to_string(), "20261027T093000Z")
  assert_eq(occ[3].to_string(), "20261028T093000Z")
}

test "occurrences rejects an all-day DATE DTSTART" {
  let cal = parse_calendar(
    "BEGIN:VCALENDAR\n" +
    "BEGIN:VEVENT\n" +
    "DTSTART;VALUE=DATE:20261026\n" +
    "RRULE:FREQ=YEARLY;COUNT=2\n" +
    "END:VEVENT\n" +
    "END:VCALENDAR\n"
  )
  let caught = try {
    let _ = occurrences(cal.children_named("VEVENT")[0])
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}
