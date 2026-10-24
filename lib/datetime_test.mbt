test "parse_date reads year, month and day" {
  let d = parse_date("20261024")
  assert_eq(d.year, 2026)
  assert_eq(d.month, 10)
  assert_eq(d.day, 24)
}

test "parse_date round-trips the basic format" {
  assert_eq(parse_date("20260101").to_string(), "20260101")
  assert_eq(parse_date("19991231").to_string(), "19991231")
  assert_eq(parse_date("00010101").to_string(), "00010101")
}

test "parse_date accepts leap-year February 29" {
  let d = parse_date("20240229")
  assert_eq(d.month, 2)
  assert_eq(d.day, 29)
  let century = parse_date("20000229") // 2000 is divisible by 400
  assert_eq(century.day, 29)
}

test "parse_date rejects an invalid month" {
  let caught = try {
    let _ = parse_date("20261301")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_date rejects a day outside the month" {
  let non_leap = try {
    let _ = parse_date("20260229")
    false
  } catch {
    _ => true
  }
  assert_true(non_leap)
  let feb30 = try {
    let _ = parse_date("20260230")
    false
  } catch {
    _ => true
  }
  assert_true(feb30)
  let day32 = try {
    let _ = parse_date("20260132")
    false
  } catch {
    _ => true
  }
  assert_true(day32)
}

test "parse_time reads a floating time" {
  let t = parse_time("093000")
  assert_eq(t.hour, 9)
  assert_eq(t.minute, 30)
  assert_eq(t.second, 0)
  assert_false(t.utc)
}

test "parse_time reads a UTC time" {
  let t = parse_time("235959Z")
  assert_eq(t.hour, 23)
  assert_eq(t.minute, 59)
  assert_eq(t.second, 59)
  assert_true(t.utc)
}

test "parse_time round-trips" {
  assert_eq(parse_time("000000").to_string(), "000000")
  assert_eq(parse_time("123456Z").to_string(), "123456Z")
}

test "parse_time accepts a leap second" {
  let t = parse_time("235960Z")
  assert_eq(t.second, 60)
}

test "parse_time rejects out-of-range fields" {
  let hour = try {
    let _ = parse_time("240000")
    false
  } catch {
    _ => true
  }
  assert_true(hour)
  let minute = try {
    let _ = parse_time("006000")
    false
  } catch {
    _ => true
  }
  assert_true(minute)
  let second = try {
    let _ = parse_time("000061")
    false
  } catch {
    _ => true
  }
  assert_true(second)
}

test "parse_date_time reads a UTC date-time" {
  let dt = parse_date_time("20261024T093000Z")
  assert_eq(dt.date.year, 2026)
  assert_eq(dt.time.hour, 9)
  assert_true(dt.time.utc)
  assert_eq(dt.to_string(), "20261024T093000Z")
}

test "parse_date_time reads a floating date-time" {
  let dt = parse_date_time("20261024T093000")
  assert_false(dt.time.utc)
  assert_eq(dt.to_string(), "20261024T093000")
}

test "parse_date_time rejects a missing T" {
  let caught = try {
    let _ = parse_date_time("20261024093000")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_date_time rejects a wrong length" {
  let caught = try {
    let _ = parse_date_time("20261024T0930")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}
