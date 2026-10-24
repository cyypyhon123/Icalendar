///|
/// RFC 5545 §3.3.6 `DURATION` and §3.3.9 `PERIOD`.
///
/// A duration is either a week count (`P2W`) or a day/time span
/// (`P1DT12H30M`, `PT15M`), with an optional leading sign. A period is a
/// start date-time followed by either an end date-time or a duration:
/// `start/end` or `start/duration`.

/// A length of time. Exactly one of the week form (`weeks > 0`) or the
/// day/time form is used; in the week form the day/time fields are all zero.
/// `sign` is +1 or -1 and applies to the whole duration.
pub struct Duration {
  sign : Int
  weeks : Int
  days : Int
  hours : Int
  minutes : Int
  seconds : Int
}

/// A span of time with an explicit start.
pub enum Period {
  /// `start / end` — two explicit date-times.
  Explicit(DateTime, DateTime)
  /// `start / duration` — a start plus a duration.
  Start(DateTime, Duration)
}

fn parse_number(b : Bytes, i : Int) -> (Int, Int) raise IcalError {
  let mut v = 0
  let mut idx = i
  let mut any = false
  while idx < b.length() && b[idx].to_int() >= 0x30 && b[idx].to_int() <= 0x39 {
    v = v * 10 + (b[idx].to_int() - 0x30)
    idx = idx + 1
    any = true
  }
  if !any {
    raise IcalError::BadLine("expected a number")
  }
  (v, idx)
}

fn is_digit_byte(c : Int) -> Bool {
  c >= 0x30 && c <= 0x39
}

/// Parse an RFC 5545 `DURATION` value, e.g. `P2W`, `P1DT12H`, `-PT15M`.
pub fn parse_duration(s : String) -> Duration raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  let mut i = 0
  let mut sign = 1
  if i < n && b[i].to_int() == 0x2B {
    i = i + 1
  } else if i < n && b[i].to_int() == 0x2D {
    sign = -1
    i = i + 1
  }
  if i >= n || b[i].to_int() != 0x50 {
    raise IcalError::BadLine("DURATION must begin with 'P'")
  }
  i = i + 1
  let mut weeks = 0
  let mut days = 0
  let mut hours = 0
  let mut minutes = 0
  let mut seconds = 0
  let mut any = false
  // Week form (`nW`) or day form (`nD`) come first.
  if i < n && is_digit_byte(b[i].to_int()) {
    let (num, i1) = parse_number(b, i)
    i = i1
    if i >= n {
      raise IcalError::BadLine("DURATION component is missing a unit")
    }
    let unit = b[i].to_int()
    if unit == 0x57 {
      weeks = num
      i = i + 1
      any = true
    } else if unit == 0x44 {
      days = num
      i = i + 1
      any = true
    } else {
      raise IcalError::BadLine("DURATION number must be followed by 'D' or 'W'")
    }
  }
  // Time form: `T` followed by one or more of H / M / S, in that order, each
  // appearing at most once.
  if i < n && b[i].to_int() == 0x54 {
    i = i + 1
    let mut rank = 0
    let mut saw_time = false
    while i < n && is_digit_byte(b[i].to_int()) {
      let (num, i1) = parse_number(b, i)
      i = i1
      if i >= n {
        raise IcalError::BadLine("DURATION time component is missing a unit")
      }
      let unit = b[i].to_int()
      i = i + 1
      if unit == 0x48 {
        if rank > 0 {
          raise IcalError::BadLine("DURATION time units out of order")
        }
        hours = num
        rank = 1
      } else if unit == 0x4D {
        if rank > 1 {
          raise IcalError::BadLine("DURATION time units out of order")
        }
        minutes = num
        rank = 2
      } else if unit == 0x53 {
        if rank > 2 {
          raise IcalError::BadLine("DURATION time units out of order")
        }
        seconds = num
        rank = 3
      } else {
        raise IcalError::BadLine("DURATION time unit must be 'H', 'M' or 'S'")
      }
      saw_time = true
    }
    if !saw_time {
      raise IcalError::BadLine("DURATION has 'T' with no time components")
    }
    any = true
  }
  if i != n {
    raise IcalError::BadLine("trailing characters in DURATION")
  }
  if !any {
    raise IcalError::BadLine("DURATION has no components")
  }
  { sign, weeks, days, hours, minutes, seconds }
}

/// Parse an RFC 5545 `PERIOD` value (`start/end` or `start/duration`).
pub fn parse_period(s : String) -> Period raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  let mut slash = 0
  let mut found = false
  while slash < n {
    if b[slash].to_int() == 0x2F {
      found = true
      break
    }
    slash = slash + 1
  }
  if !found {
    raise IcalError::BadLine("PERIOD is missing a '/' separator")
  }
  let start = parse_date_time(@utf8.decode_lossy(b[0:slash]))
  let rest = @utf8.decode_lossy(b[slash + 1:n])
  // A duration starts with P (or a sign then P); a date-time starts with a
  // digit (the four-digit year).
  let first = @utf8.encode(rest)[0].to_int()
  if first == 0x50 || first == 0x2B || first == 0x2D {
    Period::Start(start, parse_duration(rest))
  } else {
    Period::Explicit(start, parse_date_time(rest))
  }
}

/// Format the duration back to its RFC representation.
pub fn Duration::to_string(self : Duration) -> String {
  let s = if self.sign < 0 { "-" } else { "" }
  if self.weeks > 0 {
    return s + "P" + "\{self.weeks}" + "W"
  }
  let mut out = s + "P"
  let mut has = false
  if self.days > 0 {
    out = out + "\{self.days}" + "D"
    has = true
  }
  if self.hours > 0 || self.minutes > 0 || self.seconds > 0 {
    out = out + "T"
    if self.hours > 0 {
      out = out + "\{self.hours}" + "H"
      has = true
    }
    if self.minutes > 0 {
      out = out + "\{self.minutes}" + "M"
      has = true
    }
    if self.seconds > 0 {
      out = out + "\{self.seconds}" + "S"
      has = true
    }
  }
  if !has {
    out = out + "0D"
  }
  out
}

/// Format the period back to its RFC representation.
pub fn Period::to_string(self : Period) -> String {
  match self {
    Explicit(start, end) => start.to_string() + "/" + end.to_string()
    Start(start, dur) => start.to_string() + "/" + dur.to_string()
  }
}
