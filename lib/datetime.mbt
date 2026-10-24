///|
/// RFC 5545 §3.3 date/time value types: `DATE` (YYYYMMDD), `TIME` (HHMMSS,
/// optionally UTC with a trailing `Z`) and `DATE-TIME` (a `DATE` + `T` + a
/// `TIME`).
///
/// All three parse and format the RFC "basic" format (no dashes or colons),
/// and validate calendar ranges: month in 1..12, day within the month
/// (leap-year aware), hour < 24, minute < 60, and second <= 60 to admit a
/// leap second.

/// A calendar date, always expressed with a four-digit year.
pub struct Date {
  year : Int
  month : Int
  day : Int
}

/// A time of day. `utc` is true when the source carried a trailing `Z` (UTC);
/// otherwise the time is "floating" (no zone information, per RFC 5545).
pub struct Time {
  hour : Int
  minute : Int
  second : Int
  utc : Bool
}

/// A full date and time, e.g. `20261024T093000Z`.
pub struct DateTime {
  date : Date
  time : Time
}

/// Construct a DATE, validating the month and day-of-month (leap-year aware).
pub fn Date::new(year : Int, month : Int, day : Int) -> Date raise IcalError {
  validate_date(year, month, day)
  { year, month, day }
}

/// Construct a TIME, validating the hour/minute/second ranges.
pub fn Time::new(hour : Int, minute : Int, second : Int, utc : Bool) -> Time raise IcalError {
  if hour < 0 || hour > 23 {
    raise IcalError::BadLine("invalid hour: \{hour}")
  }
  if minute < 0 || minute > 59 {
    raise IcalError::BadLine("invalid minute: \{minute}")
  }
  if second < 0 || second > 60 {
    raise IcalError::BadLine("invalid second: \{second}")
  }
  { hour, minute, second, utc }
}

/// Construct a DATE-TIME from an already-valid DATE and TIME.
pub fn DateTime::new(date : Date, time : Time) -> DateTime {
  { date, time }
}

fn digit(b : Bytes, i : Int) -> Int raise IcalError {
  if i >= b.length() {
    raise IcalError::BadLine("value ended early")
  }
  let c = b[i].to_int()
  if c >= 0x30 && c <= 0x39 {
    return c - 0x30
  }
  raise IcalError::BadLine("expected a digit")
}

fn digits(b : Bytes, i : Int, count : Int) -> (Int, Int) raise IcalError {
  let mut v = 0
  let mut k = 0
  let mut idx = i
  while k < count {
    v = v * 10 + digit(b, idx)
    idx = idx + 1
    k = k + 1
  }
  (v, idx)
}

/// Whether `year` is a leap year in the proleptic Gregorian calendar.
pub fn is_leap(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

/// Number of days in `month` (1..12) of `year`, 0 for an out-of-range month.
pub fn days_in_month(year : Int, month : Int) -> Int {
  if month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12 {
    31
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else if month == 2 {
    if is_leap(year) {
      29
    } else {
      28
    }
  } else {
    0
  }
}

fn validate_date(year : Int, month : Int, day : Int) -> Unit raise IcalError {
  if month < 1 || month > 12 {
    raise IcalError::BadLine("invalid month: \{month}")
  }
  if day < 1 || day > days_in_month(year, month) {
    raise IcalError::BadLine("invalid day of month: \{year}-\{month}-\{day}")
  }
}

fn parse_date_at(b : Bytes, i : Int) -> (Date, Int) raise IcalError {
  let (year, i1) = digits(b, i, 4)
  let (month, i2) = digits(b, i1, 2)
  let (day, i3) = digits(b, i2, 2)
  validate_date(year, month, day)
  ({ year, month, day }, i3)
}

fn parse_time_at(b : Bytes, i0 : Int) -> (Time, Int) raise IcalError {
  let n = b.length()
  let (hour, i1) = digits(b, i0, 2)
  let (minute, i2) = digits(b, i1, 2)
  let (second, i3) = digits(b, i2, 2)
  let mut i = i3
  let mut utc = false
  if i < n && b[i].to_int() == 0x5A {
    utc = true
    i = i + 1
  }
  if hour > 23 {
    raise IcalError::BadLine("invalid hour: \{hour}")
  }
  if minute > 59 {
    raise IcalError::BadLine("invalid minute: \{minute}")
  }
  if second > 60 {
    raise IcalError::BadLine("invalid second: \{second}")
  }
  ({ hour, minute, second, utc }, i)
}

/// Parse an RFC 5545 `DATE` value (`YYYYMMDD`).
pub fn parse_date(s : String) -> Date raise IcalError {
  let b = @utf8.encode(s)
  if b.length() != 8 {
    raise IcalError::BadLine("DATE must be exactly 8 digits (YYYYMMDD)")
  }
  let (d, i) = parse_date_at(b, 0)
  if i != b.length() {
    raise IcalError::BadLine("trailing characters in DATE")
  }
  d
}

/// Parse an RFC 5545 `TIME` value (`HHMMSS` or `HHMMSSZ`).
pub fn parse_time(s : String) -> Time raise IcalError {
  let b = @utf8.encode(s)
  if b.length() != 6 && b.length() != 7 {
    raise IcalError::BadLine("TIME must be HHMMSS or HHMMSSZ")
  }
  let (t, i) = parse_time_at(b, 0)
  if i != b.length() {
    raise IcalError::BadLine("trailing characters in TIME")
  }
  t
}

/// Parse an RFC 5545 `DATE-TIME` value (`YYYYMMDDTHHMMSS` or `...Z`).
pub fn parse_date_time(s : String) -> DateTime raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  if n != 15 && n != 16 {
    raise IcalError::BadLine("DATE-TIME must be YYYYMMDDTHHMMSS[Z]")
  }
  let (date, i) = parse_date_at(b, 0)
  if b[i].to_int() != 0x54 {
    raise IcalError::BadLine("DATE-TIME missing 'T' separator")
  }
  let (time, j) = parse_time_at(b, i + 1)
  if j != n {
    raise IcalError::BadLine("trailing characters in DATE-TIME")
  }
  { date, time }
}

/// Format the date back to `YYYYMMDD`.
pub fn Date::to_string(self : Date) -> String {
  pad4(self.year) + pad2(self.month) + pad2(self.day)
}

/// Format the time back to `HHMMSS` (or `HHMMSSZ` when UTC).
pub fn Time::to_string(self : Time) -> String {
  let s = pad2(self.hour) + pad2(self.minute) + pad2(self.second)
  if self.utc {
    s + "Z"
  } else {
    s
  }
}

/// Format the date-time back to `YYYYMMDDTHHMMSS[Z]`.
pub fn DateTime::to_string(self : DateTime) -> String {
  self.date.to_string() + "T" + self.time.to_string()
}

fn pad2(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    "\{n}"
  }
}

fn pad4(n : Int) -> String {
  if n < 10 {
    "000\{n}"
  } else if n < 100 {
    "00\{n}"
  } else if n < 1000 {
    "0\{n}"
  } else {
    "\{n}"
  }
}

// -- UTC offset -----------------------------------------------------------

/// Parse an RFC 5545 `UTC-OFFSET` value (`+HHMM`, `-HHMM`, `+HHMMSS` or
/// `-HHMMSS`) into signed seconds east of UTC.
pub fn parse_utc_offset(s : String) -> Int raise IcalError {
  let b = @utf8.encode(s)
  let n = b.length()
  if n != 5 && n != 7 {
    raise IcalError::BadLine("UTC-OFFSET must be +HHMM[SS] or -HHMM[SS]: \{s}")
  }
  let sign = if b[0].to_int() == 0x2B {
    1
  } else if b[0].to_int() == 0x2D {
    -1
  } else {
    raise IcalError::BadLine("UTC-OFFSET must start with + or -: \{s}")
  }
  let hh = offset_digits(b, 1)
  let mm = offset_digits(b, 3)
  let mut ss = 0
  if n == 7 {
    ss = offset_digits(b, 5)
  }
  if hh > 23 || mm > 59 || ss > 59 {
    raise IcalError::BadLine("UTC-OFFSET out of range: \{s}")
  }
  sign * (hh * 3600 + mm * 60 + ss)
}

/// Format signed seconds east of UTC back to a `UTC-OFFSET` value.
pub fn format_utc_offset(secs : Int) -> String {
  let sign = if secs < 0 { "-" } else { "+" }
  let a = if secs < 0 { -secs } else { secs }
  let hh = a / 3600
  let mm = (a % 3600) / 60
  let ss = a % 60
  if ss != 0 {
    sign + pad2(hh) + pad2(mm) + pad2(ss)
  } else {
    sign + pad2(hh) + pad2(mm)
  }
}

fn offset_digits(b : Bytes, i : Int) -> Int raise IcalError {
  let c0 = b[i].to_int()
  let c1 = b[i + 1].to_int()
  if c0 < 0x30 || c0 > 0x39 || c1 < 0x30 || c1 > 0x39 {
    raise IcalError::BadLine("expected two digits in UTC-OFFSET")
  }
  (c0 - 0x30) * 10 + (c1 - 0x30)
}
