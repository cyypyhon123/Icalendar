///|
/// RFC 5545 §3.3.10 recurrence rules (RRULE). A rule is a semicolon-separated
/// list of `KEY=value` parts beginning with a required `FREQ`, e.g.
/// `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR`. This module parses and re-serializes
/// rules; expansion into concrete occurrences lives in `expand.mbt`.

/// The base unit a rule repeats on.
pub(all) enum Freq {
  Secondly
  Minutely
  Hourly
  Daily
  Weekly
  Monthly
  Yearly
} derive(Eq, @debug.Debug)

/// A day of the week. `MO` is the RFC default week start.
pub(all) enum Weekday {
  MO
  TU
  WE
  TH
  FR
  SA
  SU
} derive(Eq, @debug.Debug)

/// One BYDAY entry: an optional ordinal (`1` = first, `-1` = last) plus a day.
/// `1MO` is the first Monday of the month; `MO` alone is every Monday.
pub struct ByDay {
  ordinal : Int?
  day : Weekday
}

/// A parsed recurrence rule.
pub struct RecurrenceRule {
  freq : Freq
  interval : Int
  count : Int?
  until : DateTime?
  bysecond : Array[Int]
  byminute : Array[Int]
  byhour : Array[Int]
  byday : Array[ByDay]
  bymonthday : Array[Int]
  byyearday : Array[Int]
  byweekno : Array[Int]
  bymonth : Array[Int]
  bysetpos : Array[Int]
  wkst : Weekday
}

/// Construct a BYDAY entry.
pub fn ByDay::new(ordinal : Int?, day : Weekday) -> ByDay {
  { ordinal, day }
}

/// Parse an RRULE value such as `FREQ=WEEKLY;BYDAY=MO,WE,FR`.
pub fn parse_rrule(s : String) -> RecurrenceRule raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  let mut freq : Freq? = None
  let mut interval = 1
  let mut count : Int? = None
  let mut until : DateTime? = None
  let mut bysecond : Array[Int] = []
  let mut byminute : Array[Int] = []
  let mut byhour : Array[Int] = []
  let mut byday : Array[ByDay] = []
  let mut bymonthday : Array[Int] = []
  let mut byyearday : Array[Int] = []
  let mut byweekno : Array[Int] = []
  let mut bymonth : Array[Int] = []
  let mut bysetpos : Array[Int] = []
  let mut wkst = Weekday::MO
  let mut i = 0
  while i < n {
    let mut k = i
    while k < n && b[k].to_int() != 0x3D && b[k].to_int() != 0x3B {
      k = k + 1
    }
    if k >= n || b[k].to_int() != 0x3D {
      raise IcalError::BadLine("RRULE part is missing '=': \{s}")
    }
    let key = @utf8.decode_lossy(b[i:k])
    k = k + 1
    let mut v = k
    while v < n && b[v].to_int() != 0x3B {
      v = v + 1
    }
    let val = @utf8.decode_lossy(b[k:v])
    if key == "FREQ" {
      freq = Some(freq_of_code(val))
    } else if key == "INTERVAL" {
      interval = parse_int(val)
    } else if key == "COUNT" {
      count = Some(parse_int(val))
    } else if key == "UNTIL" {
      until = Some(parse_date_time(val))
    } else if key == "BYSECOND" {
      bysecond = int_list(val)
    } else if key == "BYMINUTE" {
      byminute = int_list(val)
    } else if key == "BYHOUR" {
      byhour = int_list(val)
    } else if key == "BYDAY" {
      byday = byday_list(val)
    } else if key == "BYMONTHDAY" {
      bymonthday = int_list(val)
    } else if key == "BYYEARDAY" {
      byyearday = int_list(val)
    } else if key == "BYWEEKNO" {
      byweekno = int_list(val)
    } else if key == "BYMONTH" {
      bymonth = int_list(val)
    } else if key == "BYSETPOS" {
      bysetpos = int_list(val)
    } else if key == "WKST" {
      wkst = weekday_of_code(val)
    } else {
      raise IcalError::BadLine("unknown RRULE part: \{key}")
    }
    i = if v < n { v + 1 } else { v }
  }
  let f = match freq {
    Some(f) => f
    None => raise IcalError::BadLine("RRULE is missing FREQ")
  }
  {
    freq: f,
    interval,
    count,
    until,
    bysecond,
    byminute,
    byhour,
    byday,
    bymonthday,
    byyearday,
    byweekno,
    bymonth,
    bysetpos,
    wkst
  }
}

/// Serialize the rule back to `FREQ=...;...` form.
pub fn RecurrenceRule::to_string(self : RecurrenceRule) -> String {
  let mut out = "FREQ=" + freq_code(self.freq)
  if self.interval != 1 {
    out = out + ";INTERVAL=" + "\{self.interval}"
  }
  match self.count {
    Some(c) => out = out + ";COUNT=" + "\{c}"
    None => ()
  }
  match self.until {
    Some(u) => out = out + ";UNTIL=" + u.to_string()
    None => ()
  }
  if self.bysecond.length() > 0 {
    out = out + ";BYSECOND=" + ints(self.bysecond)
  }
  if self.byminute.length() > 0 {
    out = out + ";BYMINUTE=" + ints(self.byminute)
  }
  if self.byhour.length() > 0 {
    out = out + ";BYHOUR=" + ints(self.byhour)
  }
  if self.byday.length() > 0 {
    out = out + ";BYDAY=" + bydays(self.byday)
  }
  if self.bymonthday.length() > 0 {
    out = out + ";BYMONTHDAY=" + ints(self.bymonthday)
  }
  if self.byyearday.length() > 0 {
    out = out + ";BYYEARDAY=" + ints(self.byyearday)
  }
  if self.byweekno.length() > 0 {
    out = out + ";BYWEEKNO=" + ints(self.byweekno)
  }
  if self.bymonth.length() > 0 {
    out = out + ";BYMONTH=" + ints(self.bymonth)
  }
  if self.bysetpos.length() > 0 {
    out = out + ";BYSETPOS=" + ints(self.bysetpos)
  }
  if self.wkst != Weekday::MO {
    out = out + ";WKST=" + weekday_code(self.wkst)
  }
  out
}

/// A copy of the rule with its UNTIL replaced by `u`. Useful for expanding an
/// otherwise-unbounded rule (e.g. a VTIMEZONE transition rule) up to a bound.
pub fn RecurrenceRule::with_until(self : RecurrenceRule, u : DateTime) -> RecurrenceRule {
  {
    freq: self.freq,
    interval: self.interval,
    count: self.count,
    until: Some(u),
    bysecond: self.bysecond,
    byminute: self.byminute,
    byhour: self.byhour,
    byday: self.byday,
    bymonthday: self.bymonthday,
    byyearday: self.byyearday,
    byweekno: self.byweekno,
    bymonth: self.bymonth,
    bysetpos: self.bysetpos,
    wkst: self.wkst
  }
}

fn freq_of_code(c : String) -> Freq raise IcalError {
  if c == "SECONDLY" {
    Freq::Secondly
  } else if c == "MINUTELY" {
    Freq::Minutely
  } else if c == "HOURLY" {
    Freq::Hourly
  } else if c == "DAILY" {
    Freq::Daily
  } else if c == "WEEKLY" {
    Freq::Weekly
  } else if c == "MONTHLY" {
    Freq::Monthly
  } else if c == "YEARLY" {
    Freq::Yearly
  } else {
    raise IcalError::BadLine("unknown FREQ: \{c}")
  }
}

fn freq_code(f : Freq) -> String {
  match f {
    Freq::Secondly => "SECONDLY"
    Freq::Minutely => "MINUTELY"
    Freq::Hourly => "HOURLY"
    Freq::Daily => "DAILY"
    Freq::Weekly => "WEEKLY"
    Freq::Monthly => "MONTHLY"
    Freq::Yearly => "YEARLY"
  }
}

fn weekday_of_code(c : String) -> Weekday raise IcalError {
  if c == "MO" {
    Weekday::MO
  } else if c == "TU" {
    Weekday::TU
  } else if c == "WE" {
    Weekday::WE
  } else if c == "TH" {
    Weekday::TH
  } else if c == "FR" {
    Weekday::FR
  } else if c == "SA" {
    Weekday::SA
  } else if c == "SU" {
    Weekday::SU
  } else {
    raise IcalError::BadLine("unknown weekday: \{c}")
  }
}

fn weekday_code(w : Weekday) -> String {
  match w {
    Weekday::MO => "MO"
    Weekday::TU => "TU"
    Weekday::WE => "WE"
    Weekday::TH => "TH"
    Weekday::FR => "FR"
    Weekday::SA => "SA"
    Weekday::SU => "SU"
  }
}

fn split_commas(s : String) -> Array[String] {
  let b = @utf8.encode(s)
  let n = b.length()
  let out : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i < n {
    if b[i].to_int() == 0x2C {
      out.push(@utf8.decode_lossy(b[start:i]))
      start = i + 1
    }
    i = i + 1
  }
  out.push(@utf8.decode_lossy(b[start:n]))
  out
}

fn parse_int(s : String) -> Int raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  if n == 0 {
    raise IcalError::BadLine("empty integer")
  }
  let mut i = 0
  let mut neg = false
  if b[i].to_int() == 0x2D {
    neg = true
    i = i + 1
  } else if b[i].to_int() == 0x2B {
    i = i + 1
  }
  if i >= n {
    raise IcalError::BadLine("empty integer")
  }
  let mut v = 0
  while i < n {
    let c = b[i].to_int()
    if c < 0x30 || c > 0x39 {
      raise IcalError::BadLine("invalid integer: \{s}")
    }
    v = v * 10 + (c - 0x30)
    i = i + 1
  }
  if neg { -v } else { v }
}

fn int_list(s : String) -> Array[Int] raise IcalError {
  let parts = split_commas(s)
  let out : Array[Int] = []
  let mut i = 0
  while i < parts.length() {
    out.push(parse_int(parts[i]))
    i = i + 1
  }
  out
}

fn byday_list(s : String) -> Array[ByDay] raise IcalError {
  let parts = split_commas(s)
  let out : Array[ByDay] = []
  let mut i = 0
  while i < parts.length() {
    out.push(parse_byday(parts[i]))
    i = i + 1
  }
  out
}

fn parse_byday(s : String) -> ByDay raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  if n < 2 {
    raise IcalError::BadLine("invalid BYDAY: \{s}")
  }
  let code = @utf8.decode_lossy(b[n - 2:n])
  let day = weekday_of_code(code)
  let ordinal : Int? = if n > 2 {
    Some(parse_int(@utf8.decode_lossy(b[0:n - 2])))
  } else {
    None
  }
  { ordinal, day }
}

fn ints(vals : Array[Int]) -> String {
  let mut s = ""
  let mut i = 0
  while i < vals.length() {
    if i > 0 {
      s = s + ","
    }
    s = s + "\{vals[i]}"
    i = i + 1
  }
  s
}

fn bydays(vals : Array[ByDay]) -> String {
  let mut s = ""
  let mut i = 0
  while i < vals.length() {
    if i > 0 {
      s = s + ","
    }
    let bd = vals[i]
    match bd.ordinal {
      Some(o) => s = s + "\{o}" + weekday_code(bd.day)
      None => s = s + weekday_code(bd.day)
    }
    i = i + 1
  }
  s
}
