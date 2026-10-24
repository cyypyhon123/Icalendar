///|
/// RFC 5545 §3.8.5.3 / §3.8.5.1: the full recurrence set of an event is
/// DTSTART plus every occurrence its RRULE generates, plus every RDATE, minus
/// every EXDATE. This module parses RDATE / EXDATE value lists and combines
/// them into the complete, sorted, de-duplicated set.

/// Parse a comma-separated RDATE / EXDATE list into date-times. Each item may
/// be a DATE-TIME, a DATE (taken at midnight), or a PERIOD (whose start is
/// used as the occurrence time).
pub fn parse_date_list(s : String) -> Array[DateTime] raise IcalError {
  let items = split_on_comma(s)
  let out : Array[DateTime] = []
  let mut i = 0
  while i < items.length() {
    out.push(parse_date_item(items[i]))
    i = i + 1
  }
  out
}

fn parse_date_item(s : String) -> DateTime raise IcalError {
  let b = @utf8.encode(s)
  let mut end = b.length()
  let mut k = 0
  while k < b.length() {
    if b[k].to_int() == 0x2F {
      end = k
      break
    }
    k = k + 1
  }
  let head = @utf8.decode_lossy(b[0:end])
  if @utf8.encode(head).length() == 8 {
    let d = parse_date(head)
    DateTime::new(d, Time::new(0, 0, 0, false))
  } else {
    parse_date_time(head)
  }
}

/// The complete recurrence set of a DATE-TIME event: `DTSTART` (plus the
/// expansion of its `RRULE`, if any) plus every `RDATE`, minus every `EXDATE`,
/// in ascending order with duplicates removed. All-day events use
/// `expand_dates` instead — this raises on a DATE-valued `DTSTART`.
pub fn occurrences(ev : Component) -> Array[DateTime] raise IcalError {
  let start = match ev.get("DTSTART") {
    Some(p) => p.as_date_time()
    None => raise IcalError::BadLine("event has no DTSTART")
  }
  let keys : Array[Int] = [dt_to_seconds(start)]
  match ev.get("RRULE") {
    Some(p) => {
      let rule = parse_rrule(p.value)
      let occ = expand(rule, start)
      let mut i = 0
      while i < occ.length() {
        keys.push(dt_to_seconds(occ[i]))
        i = i + 1
      }
    }
    None => ()
  }
  let rdates = ev.get_all("RDATE")
  let mut i = 0
  while i < rdates.length() {
    let items = parse_date_list(rdates[i].value)
    let mut j = 0
    while j < items.length() {
      keys.push(dt_to_seconds(items[j]))
      j = j + 1
    }
    i = i + 1
  }
  let excl : Array[Int] = []
  let exdates = ev.get_all("EXDATE")
  let mut e = 0
  while e < exdates.length() {
    let items = parse_date_list(exdates[e].value)
    let mut j = 0
    while j < items.length() {
      excl.push(dt_to_seconds(items[j]))
      j = j + 1
    }
    e = e + 1
  }
  let unique = sorted_unique(keys)
  let out : Array[DateTime] = []
  let mut m = 0
  while m < unique.length() {
    if !contains(excl, unique[m]) {
      out.push(seconds_to_dt(unique[m], start.time.utc))
    }
    m = m + 1
  }
  out
}
