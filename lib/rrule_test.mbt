test "parse_rrule reads a bare daily rule" {
  let r = parse_rrule("FREQ=DAILY")
  assert_eq(r.freq, Freq::Daily)
  assert_eq(r.interval, 1)
  assert_true(r.count is None)
  assert_true(r.until is None)
  assert_eq(r.byday.length(), 0)
  assert_eq(r.wkst, Weekday::MO)
}

test "parse_rrule reads interval, count and byday" {
  let r = parse_rrule("FREQ=WEEKLY;INTERVAL=2;COUNT=10;BYDAY=MO,WE,FR")
  assert_eq(r.freq, Freq::Weekly)
  assert_eq(r.interval, 2)
  assert_eq(r.count, Some(10))
  assert_eq(r.byday.length(), 3)
  assert_eq(r.byday[0].day, Weekday::MO)
  assert_eq(r.byday[2].day, Weekday::FR)
  assert_true(r.byday[0].ordinal is None)
}

test "parse_rrule reads ordinal byday and bymonth" {
  let r = parse_rrule("FREQ=MONTHLY;BYDAY=1MO,-1FR;BYMONTH=1,6")
  assert_eq(r.byday[0].ordinal, Some(1))
  assert_eq(r.byday[0].day, Weekday::MO)
  assert_eq(r.byday[1].ordinal, Some(-1))
  assert_eq(r.byday[1].day, Weekday::FR)
  assert_eq(r.bymonth.length(), 2)
  assert_eq(r.bymonth[1], 6)
}

test "parse_rrule reads an until date-time" {
  let r = parse_rrule("FREQ=YEARLY;UNTIL=20261024T000000Z")
  assert_eq(r.until.unwrap().date.year, 2026)
  assert_true(r.until.unwrap().time.utc)
}

test "parse_rrule reads a custom week start" {
  let r = parse_rrule("FREQ=WEEKLY;WKST=SU")
  assert_eq(r.wkst, Weekday::SU)
}

test "parse_rrule round-trips" {
  let a = "FREQ=WEEKLY;INTERVAL=2;COUNT=10;BYDAY=MO,WE,FR"
  assert_eq(parse_rrule(a).to_string(), a)
  let b = "FREQ=MONTHLY;BYDAY=1MO,-1FR;BYMONTH=1,6"
  assert_eq(parse_rrule(b).to_string(), b)
  let c = "FREQ=YEARLY;UNTIL=20261024T000000Z;WKST=SU"
  assert_eq(parse_rrule(c).to_string(), c)
}

test "parse_rrule rejects a missing FREQ" {
  let caught = try {
    let _ = parse_rrule("INTERVAL=2")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_rrule rejects an unknown part" {
  let caught = try {
    let _ = parse_rrule("FREQ=DAILY;BOGUS=1")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_rrule rejects a bad weekday" {
  let caught = try {
    let _ = parse_rrule("FREQ=WEEKLY;BYDAY=XX")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_rrule rejects a malformed part without equals" {
  let caught = try {
    let _ = parse_rrule("FREQ")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}
