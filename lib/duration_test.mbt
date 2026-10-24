test "parse_duration reads a week form" {
  let d = parse_duration("P2W")
  assert_eq(d.weeks, 2)
  assert_eq(d.days, 0)
  assert_eq(d.sign, 1)
}

test "parse_duration reads a day form" {
  let d = parse_duration("P1D")
  assert_eq(d.days, 1)
  assert_eq(d.weeks, 0)
}

test "parse_duration reads a day-and-time form" {
  let d = parse_duration("P1DT12H30M")
  assert_eq(d.days, 1)
  assert_eq(d.hours, 12)
  assert_eq(d.minutes, 30)
  assert_eq(d.seconds, 0)
}

test "parse_duration reads a time-only form" {
  let d = parse_duration("PT15M")
  assert_eq(d.minutes, 15)
  assert_eq(d.days, 0)
  let s = parse_duration("PT20S")
  assert_eq(s.seconds, 20)
}

test "parse_duration reads a negative duration" {
  let d = parse_duration("-PT15M")
  assert_eq(d.sign, -1)
  assert_eq(d.minutes, 15)
}

test "parse_duration reads a plus sign" {
  let d = parse_duration("+P1D")
  assert_eq(d.sign, 1)
  assert_eq(d.days, 1)
}

test "parse_duration round-trips" {
  assert_eq(parse_duration("P2W").to_string(), "P2W")
  assert_eq(parse_duration("P1D").to_string(), "P1D")
  assert_eq(parse_duration("P1DT12H30M").to_string(), "P1DT12H30M")
  assert_eq(parse_duration("PT15M").to_string(), "PT15M")
  assert_eq(parse_duration("-PT15M").to_string(), "-PT15M")
  assert_eq(parse_duration("P0D").to_string(), "P0D")
}

test "parse_duration rejects a bare P" {
  let caught = try {
    let _ = parse_duration("P")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_duration rejects a month-like value without T" {
  let caught = try {
    let _ = parse_duration("P15M")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_duration rejects a T with no components" {
  let caught = try {
    let _ = parse_duration("PT")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_duration rejects a missing P" {
  let caught = try {
    let _ = parse_duration("1D")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse_duration rejects out-of-order time units" {
  let out_of_order = try {
    let _ = parse_duration("PT1M1H")
    false
  } catch {
    _ => true
  }
  assert_true(out_of_order)
  let repeated = try {
    let _ = parse_duration("PT1H1H")
    false
  } catch {
    _ => true
  }
  assert_true(repeated)
}

test "parse_period reads an explicit start/end" {
  let p = parse_period("20261024T093000Z/20261024T103000Z")
  match p {
    Explicit(start, end) => {
      assert_eq(start.date.day, 24)
      assert_eq(end.time.hour, 10)
    }
    _ => assert_true(false)
  }
}

test "parse_period reads a start/duration" {
  let p = parse_period("20261024T093000Z/PT1H")
  match p {
    Start(start, dur) => {
      assert_eq(start.time.hour, 9)
      assert_eq(dur.hours, 1)
    }
    _ => assert_true(false)
  }
}

test "parse_period round-trips" {
  assert_eq(parse_period("20261024T093000Z/20261024T103000Z").to_string(), "20261024T093000Z/20261024T103000Z")
  assert_eq(parse_period("20261024T093000Z/PT1H").to_string(), "20261024T093000Z/PT1H")
}

test "parse_period rejects a missing slash" {
  let caught = try {
    let _ = parse_period("20261024T093000Z")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}
