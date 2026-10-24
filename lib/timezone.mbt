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
