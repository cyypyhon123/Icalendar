test "parse_utc_offset handles positive, negative and seconds" {
  assert_eq(parse_utc_offset("+0800"), 28800)
  assert_eq(parse_utc_offset("-0500"), -18000)
  assert_eq(parse_utc_offset("+0530"), 19800)
  assert_eq(parse_utc_offset("-0000"), 0)
  assert_eq(parse_utc_offset("+080030"), 28830)
}

test "format_utc_offset round-trips" {
  assert_eq(format_utc_offset(28800), "+0800")
  assert_eq(format_utc_offset(-18000), "-0500")
  assert_eq(format_utc_offset(0), "+0000")
  assert_eq(format_utc_offset(28830), "+080030")
  assert_eq(format_utc_offset(-19800), "-0530")
}

test "parse_utc_offset rejects malformed offsets" {
  let bad = ["0800", "+8", "+080", "+2560", "+0860", "+080060"]
  let mut i = 0
  while i < bad.length() {
    let s = bad[i]
    let caught = try {
      let _ = parse_utc_offset(s)
      false
    } catch {
      _ => true
    }
    assert_true(caught)
    i = i + 1
  }
}

test "parse_timezone reads observances" {
  let cal = parse_calendar(
    "BEGIN:VCALENDAR\n" +
    "VERSION:2.0\n" +
    "BEGIN:VTIMEZONE\n" +
    "TZID:America/New_York\n" +
    "BEGIN:DAYLIGHT\n" +
    "DTSTART:20070311T020000\n" +
    "TZOFFSETFROM:-0500\n" +
    "TZOFFSETTO:-0400\n" +
    "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\n" +
    "END:DAYLIGHT\n" +
    "BEGIN:STANDARD\n" +
    "DTSTART:20071104T020000\n" +
    "TZOFFSETFROM:-0400\n" +
    "TZOFFSETTO:-0500\n" +
    "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\n" +
    "END:STANDARD\n" +
    "END:VTIMEZONE\n" +
    "END:VCALENDAR\n"
  )
  let tz = parse_timezone(cal.children_named("VTIMEZONE")[0])
  assert_eq(tz.tzid, "America/New_York")
  assert_eq(tz.observances.length(), 2)
  let dst = tz.observances[0]
  assert_true(dst.daylight)
  assert_eq(dst.offset_from, -18000)
  assert_eq(dst.offset_to, -14400)
  assert_eq(dst.dtstart.to_string(), "20070311T020000")
  assert_true(dst.rrule is Some(_))
  let std = tz.observances[1]
  assert_false(std.daylight)
  assert_eq(std.offset_to, -18000)
}

test "parse_observance collects rdate transitions" {
  let cal = parse_calendar(
    "BEGIN:VCALENDAR\n" +
    "BEGIN:VTIMEZONE\n" +
    "TZID:Fixed/Example\n" +
    "BEGIN:STANDARD\n" +
    "DTSTART:20000101T000000\n" +
    "TZOFFSETFROM:+0100\n" +
    "TZOFFSETTO:+0100\n" +
    "RDATE:20010101T000000,20020101T000000\n" +
    "END:STANDARD\n" +
    "END:VTIMEZONE\n" +
    "END:VCALENDAR\n"
  )
  let tz = parse_timezone(cal.children_named("VTIMEZONE")[0])
  let obs = tz.observances[0]
  assert_eq(obs.rdates.length(), 2)
  assert_eq(obs.rdates[0].to_string(), "20010101T000000")
  assert_eq(obs.rdates[1].to_string(), "20020101T000000")
}
