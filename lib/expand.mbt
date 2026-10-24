///|
/// RFC 5545 §3.3.10 recurrence expansion: turn a parsed RRULE plus its DTSTART
/// into the concrete occurrence date-times, in chronological order.
///
/// The rule must be bounded — either COUNT, UNTIL, or both — otherwise the
/// sequence is infinite and `expand` raises. Supported parts are FREQ (all
/// seven), INTERVAL, COUNT, UNTIL, WKST, BYMONTH, BYMONTHDAY, BYDAY (with
/// month ordinals for MONTHLY/YEARLY), BYYEARDAY, BYHOUR, BYMINUTE, BYSECOND
/// and BYSETPOS (for date-level frequencies), and BYWEEKNO (for YEARLY).

/// Expand a recurrence rule from its start instant.
pub fn expand(rule : RecurrenceRule, dtstart : DateTime) -> Array[DateTime] raise IcalError {
  if rule.count is None && rule.until is None {
    raise IcalError::BadLine("RRULE is unbounded: set COUNT or UNTIL")
  }
  validate_rule(rule)
  let interval = rule.interval
  match rule.freq {
    Freq::Secondly => expand_subdaily(rule, dtstart, interval, 1)
    Freq::Minutely => expand_subdaily(rule, dtstart, interval, 60)
    Freq::Hourly => expand_subdaily(rule, dtstart, interval, 3600)
    Freq::Daily => expand_daily(rule, dtstart, interval)
    Freq::Weekly => expand_weekly(rule, dtstart, interval)
    Freq::Monthly => expand_monthly(rule, dtstart, interval)
    Freq::Yearly => expand_yearly(rule, dtstart, interval)
  }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

fn validate_rule(rule : RecurrenceRule) -> Unit raise IcalError {
  if rule.interval < 1 {
    raise IcalError::BadLine("INTERVAL must be at least 1")
  }
  match rule.count {
    Some(c) => if c < 1 {
      raise IcalError::BadLine("COUNT must be at least 1")
    }
    None => ()
  }
  all_in(rule.byhour, 0, 23, "BYHOUR")
  all_in(rule.byminute, 0, 59, "BYMINUTE")
  all_in(rule.bysecond, 0, 60, "BYSECOND")
  all_in(rule.bymonth, 1, 12, "BYMONTH")
  all_in(rule.bymonthday, -31, 31, "BYMONTHDAY")
  all_nonzero(rule.bymonthday, "BYMONTHDAY")
  all_in(rule.byyearday, -366, 366, "BYYEARDAY")
  all_nonzero(rule.byyearday, "BYYEARDAY")
  all_in(rule.bysetpos, -366, 366, "BYSETPOS")
  all_nonzero(rule.bysetpos, "BYSETPOS")
  valid_ordinals(rule.byday)
  all_in(rule.byweekno, -53, 53, "BYWEEKNO")
  all_nonzero(rule.byweekno, "BYWEEKNO")
  if rule.byweekno.length() > 0 && rule.freq != Freq::Yearly {
    raise IcalError::BadLine("BYWEEKNO is only valid with FREQ=YEARLY")
  }
}

fn all_in(a : Array[Int], lo : Int, hi : Int, what : String) -> Unit raise IcalError {
  let mut i = 0
  while i < a.length() {
    let v = a[i]
    if v < lo || v > hi {
      raise IcalError::BadLine("\{what} out of range: \{v}")
    }
    i = i + 1
  }
}

fn all_nonzero(a : Array[Int], what : String) -> Unit raise IcalError {
  let mut i = 0
  while i < a.length() {
    if a[i] == 0 {
      raise IcalError::BadLine("\{what} must not be 0")
    }
    i = i + 1
  }
}

fn valid_ordinals(byday : Array[ByDay]) -> Unit raise IcalError {
  let mut i = 0
  while i < byday.length() {
    match byday[i].ordinal {
      Some(o) => if o == 0 || o < -53 || o > 53 {
        raise IcalError::BadLine("BYDAY ordinal out of range: \{o}")
      }
      None => ()
    }
    i = i + 1
  }
}

// ---------------------------------------------------------------------------
// Date arithmetic (proleptic Gregorian, days since 1970-01-01)
// ---------------------------------------------------------------------------

fn year_days(y : Int) -> Int {
  if is_leap(y) {
    366
  } else {
    365
  }
}

fn day_number(y : Int, m : Int, d : Int) -> Int {
  let y0 = if m <= 2 { y - 1 } else { y }
  let era = (if y0 >= 0 { y0 } else { y0 - 399 }) / 400
  let yoe = y0 - era * 400
  let mm = if m > 2 { m - 3 } else { m + 9 }
  let doy = (153 * mm + 2) / 5 + d - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

fn civil_from_days(z0 : Int) -> (Int, Int, Int) {
  let z = z0 + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  (if m <= 2 { y + 1 } else { y }, m, d)
}

fn add_days(y : Int, m : Int, d : Int, n : Int) -> (Int, Int, Int) {
  civil_from_days(day_number(y, m, d) + n)
}

fn add_months(y : Int, m : Int, d : Int, n : Int) -> (Int, Int, Int) {
  let total = y * 12 + (m - 1) + n
  let ny = total / 12
  let nm = total % 12 + 1
  let maxd = days_in_month(ny, nm)
  (ny, nm, if d > maxd { maxd } else { d })
}

/// Day of week as 0 = Monday ... 6 = Sunday.
fn weekday_index(y : Int, m : Int, d : Int) -> Int {
  let dn = day_number(y, m, d)
  let r = dn % 7
  let r = if r < 0 { r + 7 } else { r }
  (r + 3) % 7
}

fn weekday_index_of(w : Weekday) -> Int {
  match w {
    Weekday::MO => 0
    Weekday::TU => 1
    Weekday::WE => 2
    Weekday::TH => 3
    Weekday::FR => 4
    Weekday::SA => 5
    Weekday::SU => 6
  }
}

/// Convert a 1-based day-of-year to a (month, day) pair.
fn md_of_doy(y : Int, doy : Int) -> (Int, Int) {
  let mut m = 1
  let mut rem = doy
  while rem > days_in_month(y, m) {
    rem = rem - days_in_month(y, m)
    m = m + 1
  }
  (m, rem)
}

/// The `ordinal`-th occurrence of a weekday in a month (1 = first, -1 = last),
/// or -1 when absent (e.g. a fifth Monday).
fn nth_weekday_of_month(y : Int, m : Int, wd : Int, ordinal : Int) -> Int {
  let n = days_in_month(y, m)
  if ordinal > 0 {
    let mut count = 0
    let mut d = 1
    while d <= n {
      if weekday_index(y, m, d) == wd {
        count = count + 1
        if count == ordinal {
          return d
        }
      }
      d = d + 1
    }
    return -1
  }
  let mut count = 0
  let mut d = n
  while d >= 1 {
    if weekday_index(y, m, d) == wd {
      count = count + 1
      if count == -ordinal {
        return d
      }
    }
    d = d - 1
  }
  return -1
}

/// The `ordinal`-th occurrence of a weekday in a year, as a day-of-year (or -1).
fn nth_weekday_of_year(y : Int, wd : Int, ordinal : Int) -> Int {
  let n = year_days(y)
  if ordinal > 0 {
    let mut count = 0
    let mut doy = 1
    while doy <= n {
      let (m, d) = md_of_doy(y, doy)
      if weekday_index(y, m, d) == wd {
        count = count + 1
        if count == ordinal {
          return doy
        }
      }
      doy = doy + 1
    }
    return -1
  }
  let mut count = 0
  let mut doy = n
  while doy >= 1 {
    let (m, d) = md_of_doy(y, doy)
    if weekday_index(y, m, d) == wd {
      count = count + 1
      if count == -ordinal {
        return doy
      }
    }
    doy = doy - 1
  }
  return -1
}

/// The first day (on WKST) of ISO week 1 in a week-year. Jan 4 is always in
/// week 1, so week 1 starts on the WKST-day on or before Jan 4.
fn week1_start(y : Int, wkst : Int) -> (Int, Int, Int) {
  let jan4_wd = weekday_index(y, 1, 4)
  let offset = (jan4_wd - wkst + 7) % 7
  add_days(y, 1, 4, -offset)
}

/// Number of ISO weeks in a week-year (52 or 53).
fn weeks_in_year(y : Int, wkst : Int) -> Int {
  let (sy, sm, sd) = week1_start(y, wkst)
  let (ny, nm, nd) = week1_start(y + 1, wkst)
  (day_number(ny, nm, nd) - day_number(sy, sm, sd)) / 7
}

// ---------------------------------------------------------------------------
// Comparisons and small-list helpers
// ---------------------------------------------------------------------------

fn dt_less(a : DateTime, b : DateTime) -> Bool {
  if a.date.year != b.date.year {
    return a.date.year < b.date.year
  }
  if a.date.month != b.date.month {
    return a.date.month < b.date.month
  }
  if a.date.day != b.date.day {
    return a.date.day < b.date.day
  }
  if a.time.hour != b.time.hour {
    return a.time.hour < b.time.hour
  }
  if a.time.minute != b.time.minute {
    return a.time.minute < b.time.minute
  }
  a.time.second < b.time.second
}

fn dt_le(a : DateTime, b : DateTime) -> Bool {
  if a.date.year != b.date.year {
    return a.date.year < b.date.year
  }
  if a.date.month != b.date.month {
    return a.date.month < b.date.month
  }
  if a.date.day != b.date.day {
    return a.date.day < b.date.day
  }
  if a.time.hour != b.time.hour {
    return a.time.hour < b.time.hour
  }
  if a.time.minute != b.time.minute {
    return a.time.minute < b.time.minute
  }
  a.time.second <= b.time.second
}

/// Whether the civil date (y, m, d) is strictly after `u`'s date.
fn date_gt(y : Int, m : Int, d : Int, u : DateTime) -> Bool {
  if y != u.date.year {
    return y > u.date.year
  }
  if m != u.date.month {
    return m > u.date.month
  }
  d > u.date.day
}

fn contains(a : Array[Int], v : Int) -> Bool {
  let mut i = 0
  while i < a.length() {
    if a[i] == v {
      return true
    }
    i = i + 1
  }
  false
}

fn sorted_ints(a : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  let mut i = 0
  while i < a.length() {
    out.push(a[i])
    i = i + 1
  }
  let mut j = 1
  while j < out.length() {
    let key = out[j]
    let mut k = j - 1
    while k >= 0 && out[k] > key {
      out[k + 1] = out[k]
      k = k - 1
    }
    out[k + 1] = key
    j = j + 1
  }
  out
}

fn sorted_unique(a : Array[Int]) -> Array[Int] {
  let s = sorted_ints(a)
  let out : Array[Int] = []
  let mut i = 0
  while i < s.length() {
    if i == 0 || s[i] != s[i - 1] {
      out.push(s[i])
    }
    i = i + 1
  }
  out
}

fn byday_has_weekday(byday : Array[ByDay], wd : Int) -> Bool {
  let mut i = 0
  while i < byday.length() {
    if weekday_index_of(byday[i].day) == wd {
      return true
    }
    i = i + 1
  }
  false
}

/// Whether a candidate day-of-month is selected by BYMONTHDAY/BYDAY (union).
fn is_candidate_day(rule : RecurrenceRule, y : Int, m : Int, d : Int) -> Bool {
  let mut i = 0
  while i < rule.bymonthday.length() {
    let v = rule.bymonthday[i]
    let dd = if v > 0 { v } else { days_in_month(y, m) + 1 + v }
    if dd == d {
      return true
    }
    i = i + 1
  }
  let mut j = 0
  while j < rule.byday.length() {
    let bd = rule.byday[j]
    match bd.ordinal {
      Some(o) => if nth_weekday_of_month(y, m, weekday_index_of(bd.day), o) == d {
        return true
      }
      None => if weekday_index(y, m, d) == weekday_index_of(bd.day) {
        return true
      }
    }
    j = j + 1
  }
  false
}

fn matches_month(rule : RecurrenceRule, m : Int) -> Bool {
  rule.bymonth.length() == 0 || contains(rule.bymonth, m)
}

fn matches_monthday(rule : RecurrenceRule, y : Int, m : Int, d : Int) -> Bool {
  if rule.bymonthday.length() == 0 {
    return true
  }
  let mut i = 0
  while i < rule.bymonthday.length() {
    let v = rule.bymonthday[i]
    let dd = if v > 0 { v } else { days_in_month(y, m) + 1 + v }
    if dd == d {
      return true
    }
    i = i + 1
  }
  false
}

fn matches_weekday(rule : RecurrenceRule, y : Int, m : Int, d : Int) -> Bool {
  rule.byday.length() == 0 || byday_has_weekday(rule.byday, weekday_index(y, m, d))
}

fn until_allows(rule : RecurrenceRule, dt : DateTime) -> Bool {
  match rule.until {
    None => true
    Some(u) => dt_le(dt, u)
  }
}

fn count_reached(rule : RecurrenceRule, out : Array[DateTime]) -> Bool {
  match rule.count {
    Some(c) => out.length() >= c
    None => false
  }
}

// ---------------------------------------------------------------------------
// Per-period helpers
// ---------------------------------------------------------------------------

fn time_lists(rule : RecurrenceRule, dtstart : DateTime) -> (Array[Int], Array[Int], Array[Int]) {
  let hours = if rule.byhour.length() > 0 { sorted_unique(rule.byhour) } else { [dtstart.time.hour] }
  let minutes = if rule.byminute.length() > 0 { sorted_unique(rule.byminute) } else { [dtstart.time.minute] }
  let seconds = if rule.bysecond.length() > 0 { sorted_unique(rule.bysecond) } else { [dtstart.time.second] }
  (hours, minutes, seconds)
}

/// Push every hour×minute×second instant for a single civil date.
fn emit_day(set : Array[DateTime], y : Int, m : Int, d : Int, hours : Array[Int], minutes : Array[Int], seconds : Array[Int], utc : Bool) -> Unit raise IcalError {
  let mut hi = 0
  while hi < hours.length() {
    let mut mi = 0
    while mi < minutes.length() {
      let mut si = 0
      while si < seconds.length() {
        set.push(DateTime::new(Date::new(y, m, d), Time::new(hours[hi], minutes[mi], seconds[si], utc)))
        si = si + 1
      }
      mi = mi + 1
    }
    hi = hi + 1
  }
}

/// Apply BYSETPOS, drop anything before `min`, and drop anything after UNTIL,
/// then append the survivors to `out`.
fn finalize_period(out : Array[DateTime], set : Array[DateTime], rule : RecurrenceRule, min : DateTime?) -> Unit {
  let selected : Array[DateTime] = []
  if rule.bysetpos.length() == 0 {
    let mut i = 0
    while i < set.length() {
      selected.push(set[i])
      i = i + 1
    }
  } else {
    let idxs : Array[Int] = []
    let mut i = 0
    while i < rule.bysetpos.length() {
      let p = rule.bysetpos[i]
      let idx = if p > 0 { p - 1 } else { set.length() + p }
      if idx >= 0 && idx < set.length() {
        idxs.push(idx)
      }
      i = i + 1
    }
    let sd = sorted_unique(idxs)
    let mut j = 0
    while j < sd.length() {
      selected.push(set[sd[j]])
      j = j + 1
    }
  }
  let mut k = 0
  while k < selected.length() {
    let dt = selected[k]
    let mut ok = true
    match min {
      Some(m0) => if dt_less(dt, m0) {
        ok = false
      }
      None => ()
    }
    if ok && until_allows(rule, dt) {
      out.push(dt)
    }
    k = k + 1
  }
}

fn truncate_count(out : Array[DateTime], rule : RecurrenceRule) -> Array[DateTime] {
  match rule.count {
    Some(c) => {
      if out.length() <= c {
        return out
      }
      let next : Array[DateTime] = []
      let mut i = 0
      while i < c {
        next.push(out[i])
        i = i + 1
      }
      next
    }
    None => out
  }
}

// ---------------------------------------------------------------------------
// Expansion per FREQ
// ---------------------------------------------------------------------------

fn expand_daily(rule : RecurrenceRule, dtstart : DateTime, interval : Int) -> Array[DateTime] raise IcalError {
  let (hours, minutes, seconds) = time_lists(rule, dtstart)
  let utc = dtstart.time.utc
  let out : Array[DateTime] = []
  let mut y = dtstart.date.year
  let mut m = dtstart.date.month
  let mut d = dtstart.date.day
  let mut min : DateTime? = Some(dtstart)
  let mut first = true
  while true {
    if !first {
      let (ny, nm, nd) = add_days(y, m, d, interval)
      y = ny
      m = nm
      d = nd
    }
    first = false
    match rule.until {
      Some(u) => if date_gt(y, m, d, u) {
        break
      }
      None => ()
    }
    if matches_month(rule, m) && matches_monthday(rule, y, m, d) && matches_weekday(rule, y, m, d) {
      let set : Array[DateTime] = []
      emit_day(set, y, m, d, hours, minutes, seconds, utc)
      finalize_period(out, set, rule, min)
      if count_reached(rule, out) {
        break
      }
    }
    min = None
  }
  truncate_count(out, rule)
}

fn expand_weekly(rule : RecurrenceRule, dtstart : DateTime, interval : Int) -> Array[DateTime] raise IcalError {
  let (hours, minutes, seconds) = time_lists(rule, dtstart)
  let utc = dtstart.time.utc
  let out : Array[DateTime] = []
  let wkst = weekday_index_of(rule.wkst)
  let dt_wd = weekday_index(dtstart.date.year, dtstart.date.month, dtstart.date.day)
  let offset = (dt_wd - wkst + 7) % 7
  let (s_y, s_m, s_d) = add_days(dtstart.date.year, dtstart.date.month, dtstart.date.day, -offset)
  let mut wy = s_y
  let mut wm = s_m
  let mut wd = s_d
  let mut min : DateTime? = Some(dtstart)
  let mut first = true
  while true {
    if !first {
      let (ny, nm, nd) = add_days(wy, wm, wd, 7 * interval)
      wy = ny
      wm = nm
      wd = nd
    }
    first = false
    match rule.until {
      Some(u) => if date_gt(wy, wm, wd, u) {
        break
      }
      None => ()
    }
    let set : Array[DateTime] = []
    let mut dayoff = 0
    while dayoff < 7 {
      let (yy, mm, dd) = add_days(wy, wm, wd, dayoff)
      let w = weekday_index(yy, mm, dd)
      let selected = if rule.byday.length() == 0 {
        dayoff == offset
      } else {
        byday_has_weekday(rule.byday, w)
      }
      if selected && matches_month(rule, mm) && matches_monthday(rule, yy, mm, dd) {
        emit_day(set, yy, mm, dd, hours, minutes, seconds, utc)
      }
      dayoff = dayoff + 1
    }
    finalize_period(out, set, rule, min)
    if count_reached(rule, out) {
      break
    }
    min = None
  }
  truncate_count(out, rule)
}

fn expand_monthly(rule : RecurrenceRule, dtstart : DateTime, interval : Int) -> Array[DateTime] raise IcalError {
  let (hours, minutes, seconds) = time_lists(rule, dtstart)
  let utc = dtstart.time.utc
  let out : Array[DateTime] = []
  let mut y = dtstart.date.year
  let mut m = dtstart.date.month
  let mut min : DateTime? = Some(dtstart)
  let mut first = true
  while true {
    if !first {
      let (ny, nm, _nd) = add_months(y, m, dtstart.date.day, interval)
      y = ny
      m = nm
    }
    first = false
    match rule.until {
      Some(u) => if date_gt(y, m, 1, u) {
        break
      }
      None => ()
    }
    if matches_month(rule, m) {
      let set : Array[DateTime] = []
      if rule.bymonthday.length() == 0 && rule.byday.length() == 0 {
        emit_day(set, y, m, dtstart.date.day, hours, minutes, seconds, utc)
      } else {
        let mut d = 1
        while d <= days_in_month(y, m) {
          if is_candidate_day(rule, y, m, d) {
            emit_day(set, y, m, d, hours, minutes, seconds, utc)
          }
          d = d + 1
        }
      }
      finalize_period(out, set, rule, min)
      if count_reached(rule, out) {
        break
      }
    }
    min = None
  }
  truncate_count(out, rule)
}

fn expand_yearly(rule : RecurrenceRule, dtstart : DateTime, interval : Int) -> Array[DateTime] raise IcalError {
  let (hours, minutes, seconds) = time_lists(rule, dtstart)
  let utc = dtstart.time.utc
  let out : Array[DateTime] = []
  let mut y = dtstart.date.year
  let mut min : DateTime? = Some(dtstart)
  let mut first = true
  while true {
    if !first {
      y = y + interval
    }
    first = false
    match rule.until {
      Some(u) => if date_gt(y, 1, 1, u) {
        break
      }
      None => ()
    }
    let set : Array[DateTime] = []
    if rule.byweekno.length() > 0 {
      let wkst = weekday_index_of(rule.wkst)
      let n = weeks_in_year(y, wkst)
      let weeks : Array[Int] = []
      let mut wi = 0
      while wi < rule.byweekno.length() {
        let w = rule.byweekno[wi]
        let actual = if w > 0 { w } else { n + 1 + w }
        if actual >= 1 && actual <= n {
          weeks.push(actual)
        }
        wi = wi + 1
      }
      let sw = sorted_unique(weeks)
      let mut si = 0
      while si < sw.length() {
        let actual = sw[si]
        let (sy, sm, sd) = week1_start(y, wkst)
        let (wy, wm, wd) = add_days(sy, sm, sd, (actual - 1) * 7)
        let mut dayoff = 0
        while dayoff < 7 {
          let (yy, mm, dd) = add_days(wy, wm, wd, dayoff)
          if matches_month(rule, mm) && matches_monthday(rule, yy, mm, dd) && matches_weekday(rule, yy, mm, dd) {
            emit_day(set, yy, mm, dd, hours, minutes, seconds, utc)
          }
          dayoff = dayoff + 1
        }
        si = si + 1
      }
    } else if rule.byyearday.length() > 0 {
      let n = year_days(y)
      let mut i = 0
      while i < rule.byyearday.length() {
        let v = rule.byyearday[i]
        let doy = if v > 0 { v } else { n + 1 + v }
        if doy >= 1 && doy <= n {
          let (mm, dd) = md_of_doy(y, doy)
          if matches_month(rule, mm) {
            emit_day(set, y, mm, dd, hours, minutes, seconds, utc)
          }
        }
        i = i + 1
      }
    } else if rule.bymonth.length() == 0 && has_ordinal(rule.byday) {
      let mut i = 0
      while i < rule.byday.length() {
        let bd = rule.byday[i]
        match bd.ordinal {
          Some(o) => {
            let doy = nth_weekday_of_year(y, weekday_index_of(bd.day), o)
            if doy >= 1 {
              let (mm, dd) = md_of_doy(y, doy)
              emit_day(set, y, mm, dd, hours, minutes, seconds, utc)
            }
          }
          None => {
            let mut doy = 1
            while doy <= year_days(y) {
              let (mm, dd) = md_of_doy(y, doy)
              if weekday_index(y, mm, dd) == weekday_index_of(bd.day) {
                emit_day(set, y, mm, dd, hours, minutes, seconds, utc)
              }
              doy = doy + 1
            }
          }
        }
        i = i + 1
      }
    } else {
      let months = if rule.bymonth.length() > 0 { sorted_unique(rule.bymonth) } else { [dtstart.date.month] }
      let mut mi = 0
      while mi < months.length() {
        let m = months[mi]
        if rule.bymonthday.length() == 0 && rule.byday.length() == 0 {
          emit_day(set, y, m, dtstart.date.day, hours, minutes, seconds, utc)
        } else {
          let mut d = 1
          while d <= days_in_month(y, m) {
            if is_candidate_day(rule, y, m, d) {
              emit_day(set, y, m, d, hours, minutes, seconds, utc)
            }
            d = d + 1
          }
        }
        mi = mi + 1
      }
    }
    finalize_period(out, set, rule, min)
    if count_reached(rule, out) {
      break
    }
    min = None
  }
  truncate_count(out, rule)
}

fn has_ordinal(byday : Array[ByDay]) -> Bool {
  let mut i = 0
  while i < byday.length() {
    match byday[i].ordinal {
      Some(_) => return true
      None => ()
    }
    i = i + 1
  }
  false
}

fn expand_subdaily(rule : RecurrenceRule, dtstart : DateTime, interval : Int, step : Int) -> Array[DateTime] raise IcalError {
  if rule.bysetpos.length() > 0 {
    raise IcalError::BadLine("BYSETPOS is not supported for sub-daily frequencies")
  }
  let utc = dtstart.time.utc
  let out : Array[DateTime] = []
  let start = dt_to_seconds(dtstart)
  let mut secs = start
  let mut first = true
  while true {
    if !first {
      secs = secs + step * interval
    }
    first = false
    match rule.until {
      Some(u) => if secs > dt_to_seconds(u) {
        break
      }
      None => ()
    }
    let dt = seconds_to_dt(secs, utc)
    if subdaily_matches(rule, dt) {
      out.push(dt)
      if count_reached(rule, out) {
        break
      }
    }
  }
  truncate_count(out, rule)
}

fn subdaily_matches(rule : RecurrenceRule, dt : DateTime) -> Bool {
  if rule.byhour.length() > 0 && !contains(rule.byhour, dt.time.hour) {
    return false
  }
  if rule.byminute.length() > 0 && !contains(rule.byminute, dt.time.minute) {
    return false
  }
  if rule.bysecond.length() > 0 && !contains(rule.bysecond, dt.time.second) {
    return false
  }
  if rule.bymonth.length() > 0 && !contains(rule.bymonth, dt.date.month) {
    return false
  }
  if rule.bymonthday.length() > 0 && !contains(rule.bymonthday, dt.date.day) {
    return false
  }
  if rule.byday.length() > 0 && !byday_has_weekday(rule.byday, weekday_index(dt.date.year, dt.date.month, dt.date.day)) {
    return false
  }
  true
}

fn dt_to_seconds(dt : DateTime) -> Int {
  day_number(dt.date.year, dt.date.month, dt.date.day) * 86400 + dt.time.hour * 3600 + dt.time.minute * 60 + dt.time.second
}

fn seconds_to_dt(secs : Int, utc : Bool) -> DateTime raise IcalError {
  let day = floor_div(secs, 86400)
  let rem = secs - day * 86400
  let hour = rem / 3600
  let rem2 = rem - hour * 3600
  let minute = rem2 / 60
  let second = rem2 - minute * 60
  let (y, m, d) = civil_from_days(day)
  DateTime::new(Date::new(y, m, d), Time::new(hour, minute, second, utc))
}

fn floor_div(a : Int, b : Int) -> Int {
  let q = a / b
  if a % b != 0 && a < 0 {
    q - 1
  } else {
    q
  }
}
