fn strs(dts : Array[DateTime]) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i < dts.length() {
    out.push(dts[i].to_string())
    i = i + 1
  }
  out
}

test "daily with count" {
  let r = parse_rrule("FREQ=DAILY;COUNT=3")
  let dt = parse_date_time("20261024T093000Z")
  assert_eq(strs(expand(r, dt)), ["20261024T093000Z", "20261025T093000Z", "20261026T093000Z"])
}

test "daily with interval" {
  let r = parse_rrule("FREQ=DAILY;INTERVAL=2;COUNT=3")
  let dt = parse_date_time("20261024T093000Z")
  assert_eq(strs(expand(r, dt)), ["20261024T093000Z", "20261026T093000Z", "20261028T093000Z"])
}

test "daily until is inclusive" {
  let r = parse_rrule("FREQ=DAILY;UNTIL=20261026T093000Z")
  let dt = parse_date_time("20261024T093000Z")
  assert_eq(strs(expand(r, dt)), ["20261024T093000Z", "20261025T093000Z", "20261026T093000Z"])
}

test "weekly byday" {
  let r = parse_rrule("FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=5")
  let dt = parse_date_time("20261026T093000Z")
  assert_eq(
    strs(expand(r, dt)),
    ["20261026T093000Z", "20261028T093000Z", "20261030T093000Z", "20261102T093000Z", "20261104T093000Z"]
  )
}

test "weekly starts on dtstart weekday when byday is absent" {
  let r = parse_rrule("FREQ=WEEKLY;COUNT=3")
  let dt = parse_date_time("20261026T093000Z")
  assert_eq(strs(expand(r, dt)), ["20261026T093000Z", "20261102T093000Z", "20261109T093000Z"])
}

test "weekly excludes days before dtstart in the first week" {
  let r = parse_rrule("FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=4")
  let dt = parse_date_time("20261028T093000Z")
  assert_eq(
    strs(expand(r, dt)),
    ["20261028T093000Z", "20261030T093000Z", "20261102T093000Z", "20261104T093000Z"]
  )
}

test "monthly bymonthday" {
  let r = parse_rrule("FREQ=MONTHLY;BYMONTHDAY=15;COUNT=3")
  let dt = parse_date_time("20260115T120000Z")
  assert_eq(strs(expand(r, dt)), ["20260115T120000Z", "20260215T120000Z", "20260315T120000Z"])
}

test "monthly first monday" {
  let r = parse_rrule("FREQ=MONTHLY;BYDAY=1MO;COUNT=3")
  let dt = parse_date_time("20260105T090000Z")
  assert_eq(strs(expand(r, dt)), ["20260105T090000Z", "20260202T090000Z", "20260302T090000Z"])
}

test "monthly last friday" {
  let r = parse_rrule("FREQ=MONTHLY;BYDAY=-1FR;COUNT=2")
  let dt = parse_date_time("20260130T170000Z")
  assert_eq(strs(expand(r, dt)), ["20260130T170000Z", "20260227T170000Z"])
}

test "monthly last weekday via bysetpos" {
  let r = parse_rrule("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=2")
  let dt = parse_date_time("20260130T090000Z")
  assert_eq(strs(expand(r, dt)), ["20260130T090000Z", "20260227T090000Z"])
}

test "yearly birthday" {
  let r = parse_rrule("FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15;COUNT=3")
  let dt = parse_date_time("19900315T000000Z")
  assert_eq(strs(expand(r, dt)), ["19900315T000000Z", "19910315T000000Z", "19920315T000000Z"])
}

test "yearly first monday of june" {
  let r = parse_rrule("FREQ=YEARLY;BYMONTH=6;BYDAY=1MO;COUNT=2")
  let dt = parse_date_time("20260601T090000Z")
  assert_eq(strs(expand(r, dt)), ["20260601T090000Z", "20270607T090000Z"])
}

test "yearly first monday of the year" {
  let r = parse_rrule("FREQ=YEARLY;BYDAY=1MO;COUNT=2")
  let dt = parse_date_time("20260105T090000Z")
  assert_eq(strs(expand(r, dt)), ["20260105T090000Z", "20270104T090000Z"])
}

test "yearly byweekno monday of week 20" {
  let r = parse_rrule("FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO;COUNT=3")
  let dt = parse_date_time("20260511T090000Z")
  assert_eq(strs(expand(r, dt)), ["20260511T090000Z", "20270517T090000Z", "20280515T090000Z"])
}

test "yearly negative byweekno picks the last week" {
  let r = parse_rrule("FREQ=YEARLY;BYWEEKNO=-1;BYDAY=MO;COUNT=2")
  let dt = parse_date_time("20261228T090000Z")
  assert_eq(strs(expand(r, dt)), ["20261228T090000Z", "20271227T090000Z"])
}

test "byweekno is only valid with yearly frequency" {
  let r = parse_rrule("FREQ=MONTHLY;BYWEEKNO=20;COUNT=1")
  let dt = parse_date_time("20260511T090000Z")
  let caught = try {
    let _ = expand(r, dt)
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "hourly stepping" {
  let r = parse_rrule("FREQ=HOURLY;COUNT=3")
  let dt = parse_date_time("20261024T080000Z")
  assert_eq(strs(expand(r, dt)), ["20261024T080000Z", "20261024T090000Z", "20261024T100000Z"])
}

test "unbounded rule raises" {
  let r = parse_rrule("FREQ=DAILY")
  let dt = parse_date_time("20261024T093000Z")
  let caught = try {
    let _ = expand(r, dt)
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}
