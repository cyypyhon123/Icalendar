///|
/// RFC 5545 §3.6.5 VTIMEZONE: a named timezone made of STANDARD / DAYLIGHT
/// observances. Each observance gives the local date-time it begins, the UTC
/// offset it leaves and enters, and (usually) a yearly RRULE plus RDATEs that
/// define when it applies. This module turns a parsed VTIMEZONE component into
/// typed observances.

/// One STANDARD or DAYLIGHT observance.
pub struct Observance {
  daylight : Bool
  dtstart : DateTime
  offset_from : Int
  offset_to : Int
  rrule : RecurrenceRule?
  rdates : Array[DateTime]
}

/// A parsed VTIMEZONE.
pub struct VTimezone {
  tzid : String
  observances : Array[Observance]
}

/// Parse a VTIMEZONE component into its typed observances.
pub fn parse_timezone(comp : Component) -> VTimezone raise IcalError {
  if comp.name != "VTIMEZONE" {
    raise IcalError::BadLine("expected a VTIMEZONE component, found \{comp.name}")
  }
  let tzid = match comp.get("TZID") {
    Some(p) => p.value
    None => raise IcalError::BadLine("VTIMEZONE is missing TZID")
  }
  let obs : Array[Observance] = []
  let mut i = 0
  while i < comp.children.length() {
    let child = comp.children[i]
    if child.name == "STANDARD" || child.name == "DAYLIGHT" {
      obs.push(parse_observance(child))
    }
    i = i + 1
  }
  { tzid, observances: obs }
}

fn parse_observance(comp : Component) -> Observance raise IcalError {
  let daylight = comp.name == "DAYLIGHT"
  let dtstart = match comp.get("DTSTART") {
    Some(p) => p.as_date_time()
    None => raise IcalError::BadLine("observance is missing DTSTART")
  }
  let offset_from = match comp.get("TZOFFSETFROM") {
    Some(p) => parse_utc_offset(p.value)
    None => raise IcalError::BadLine("observance is missing TZOFFSETFROM")
  }
  let offset_to = match comp.get("TZOFFSETTO") {
    Some(p) => parse_utc_offset(p.value)
    None => raise IcalError::BadLine("observance is missing TZOFFSETTO")
  }
  let rrule = match comp.get("RRULE") {
    Some(p) => Some(parse_rrule(p.value))
    None => None
  }
  let rdates : Array[DateTime] = []
  let all = comp.get_all("RDATE")
  let mut i = 0
  while i < all.length() {
    let parts = split_on_comma(all[i].value)
    let mut j = 0
    while j < parts.length() {
      rdates.push(parse_date_time(parts[j]))
      j = j + 1
    }
    i = i + 1
  }
  { daylight, dtstart, offset_from, offset_to, rrule, rdates }
}

fn split_on_comma(s : String) -> Array[String] {
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

/// Convert a floating (local) date-time to UTC using this timezone's
/// observances. The offset in effect is found by expanding each observance's
/// transitions to UTC and walking them by fixed-point iteration. Ambiguous
/// local times (the fall-back overlap) resolve deterministically; non-existent
/// local times (the spring-forward gap) shift forward.
pub fn to_utc(loc : DateTime, tz : VTimezone) -> DateTime raise IcalError {
  let obs = tz.observances
  if obs.length() == 0 {
    raise IcalError::BadLine("VTIMEZONE has no observances")
  }
  let lo_year = loc.date.year - 1
  let hi_year = loc.date.year + 1
  let hi = DateTime::new(Date::new(hi_year, 12, 31), Time::new(23, 59, 59, false))
  let trans : Array[Int] = []
  let after : Array[Int] = []
  let mut i = 0
  while i < obs.length() {
    let o = obs[i]
    let locals : Array[DateTime] = []
    match o.rrule {
      Some(r) => {
        let occ = expand(r.with_until(hi), o.dtstart)
        let mut k = 0
        while k < occ.length() {
          locals.push(occ[k])
          k = k + 1
        }
      }
      None => locals.push(o.dtstart)
    }
    let mut r = 0
    while r < o.rdates.length() {
      locals.push(o.rdates[r])
      r = r + 1
    }
    let mut t = 0
    while t < locals.length() {
      let l = locals[t]
      if l.date.year >= lo_year && l.date.year <= hi_year {
        trans.push(dt_to_seconds(l) - o.offset_from)
        after.push(o.offset_to)
      }
      t = t + 1
    }
    i = i + 1
  }
  sort_pairs(trans, after)
  let mut offset = obs[0].offset_to
  let local_secs = dt_to_seconds(loc)
  let mut it = 0
  while it < 4 {
    let u = local_secs - offset
    let mut chosen = offset
    let mut j = 0
    while j < trans.length() {
      if trans[j] <= u {
        chosen = after[j]
      } else {
        break
      }
      j = j + 1
    }
    if chosen == offset {
      break
    }
    offset = chosen
    it = it + 1
  }
  seconds_to_dt(local_secs - offset, true)
}

/// Sort `a` ascending, carrying `b` along (insertion sort, both in place).
fn sort_pairs(a : Array[Int], b : Array[Int]) -> Unit {
  let mut i = 1
  while i < a.length() {
    let ka = a[i]
    let kb = b[i]
    let mut j = i - 1
    while j >= 0 && a[j] > ka {
      a[j + 1] = a[j]
      b[j + 1] = b[j]
      j = j - 1
    }
    a[j + 1] = ka
    b[j + 1] = kb
    i = i + 1
  }
}
