///|
/// Runnable demo: parse a small calendar, pull out each event, expand its
/// recurrence rule, and show the whole thing serialized back out again. It
/// also walks a DATE-valued (all-day) event and resolves a local time through
/// a VTIMEZONE.
///
/// Run with: `moon run cmd`

let sample : String =
  "BEGIN:VCALENDAR\n" +
  "VERSION:2.0\n" +
  "PRODID:-//icalendar demo//EN\n" +
  "BEGIN:VEVENT\n" +
  "UID:standup@example.com\n" +
  "DTSTART:20261026T093000Z\n" +
  "DTEND:20261026T100000Z\n" +
  "SUMMARY:Team standup\n" +
  "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10\n" +
  "END:VEVENT\n" +
  "BEGIN:VEVENT\n" +
  "UID:board@example.com\n" +
  "DTSTART:20261102T090000Z\n" +
  "DTEND:20261102T110000Z\n" +
  "SUMMARY:Board meeting\n" +
  "DESCRIPTION:Quarterly review\\nBring the slides\n" +
  "RRULE:FREQ=MONTHLY;BYDAY=1MO;COUNT=6\n" +
  "BEGIN:VALARM\n" +
  "ACTION:DISPLAY\n" +
  "TRIGGER:-PT15M\n" +
  "DESCRIPTION:Reminder\n" +
  "END:VALARM\n" +
  "END:VEVENT\n" +
  "END:VCALENDAR\n"

let birthday : String =
  "BEGIN:VCALENDAR\n" +
  "VERSION:2.0\n" +
  "BEGIN:VEVENT\n" +
  "UID:birthday@example.com\n" +
  "DTSTART;VALUE=DATE:19900315\n" +
  "SUMMARY:Sam's birthday\n" +
  "RRULE:FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15;COUNT=3\n" +
  "END:VEVENT\n" +
  "END:VCALENDAR\n"

let timezone : String =
  "BEGIN:VCALENDAR\n" +
  "BEGIN:VTIMEZONE\n" +
  "TZID:America/New_York\n" +
  "BEGIN:DAYLIGHT\n" +
  "DTSTART:20070311T020000\n" +
  "TZOFFSETFROM:-0500\n" +
  "TZOFFSETTO:-0400\n" +
  "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\n" +
  "END:DAYLIGHT\n" +
  "BEGIN:STANDARD\n" +
  "DTSTART:20071104T020000\n" +
  "TZOFFSETFROM:-0400\n" +
  "TZOFFSETTO:-0500\n" +
  "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\n" +
  "END:STANDARD\n" +
  "END:VTIMEZONE\n" +
  "END:VCALENDAR\n"

fn main {
  let cal = try {
    @ical.parse_calendar(sample)
  } catch {
    e => {
      println("could not parse calendar: \{e.message()}")
      return
    }
  }
  let events = cal.children_named("VEVENT")
  println("Parsed a VCALENDAR with \{events.length()} event(s):\n")
  let mut i = 0
  while i < events.length() {
    print_event(events[i])
    i = i + 1
  }
  println("--- round-trip ---\n")
  println(@ical.serialize_calendar(cal))

  show_birthday()
  show_timezone()
}

fn show_birthday() -> Unit {
  println("\n--- all-day event (DATE DTSTART) ---\n")
  let _ = try {
    let bcal = @ical.parse_calendar(birthday)
    let ev = bcal.children_named("VEVENT")[0]
    let start = ev.get("DTSTART").unwrap().as_date()
    let rule = @ical.parse_rrule(ev.get("RRULE").unwrap().value)
    let dates = @ical.expand_dates(rule, start)
    println("\{ev.get("SUMMARY").unwrap().value}")
    println("  starts \{start.to_string()} (all day)")
    let mut i = 0
    while i < dates.length() {
      println("    - \{dates[i].to_string()}")
      i = i + 1
    }
  } catch {
    e => println("could not show birthday: \{e.message()}")
  }
}

fn show_timezone() -> Unit {
  println("\n--- timezone resolution ---\n")
  let _ = try {
    let tcal = @ical.parse_calendar(timezone)
    let tz = @ical.parse_timezone(tcal.children_named("VTIMEZONE")[0])
    let summer = @ical.to_utc(@ical.parse_date_time("20260815T120000"), tz)
    let winter = @ical.to_utc(@ical.parse_date_time("20260215T120000"), tz)
    println("\{tz.tzid}")
    println("  20260815T120000 (local) -> \{summer.to_string()}")
    println("  20260215T120000 (local) -> \{winter.to_string()}")
  } catch {
    e => println("could not show timezone: \{e.message()}")
  }
}

fn print_event(ev : @ical.Component) -> Unit {
  let summary = match ev.get("SUMMARY") {
    Some(p) => p.value
    None => "(no summary)"
  }
  let start = match ev.get("DTSTART") {
    Some(p) => try {
      p.as_date_time().to_string()
    } catch {
      _ => p.value
    }
    None => "(no start)"
  }
  println("\{summary}")
  println("  starts \{start}")
  match ev.get("RRULE") {
    Some(p) => {
      let _ = try {
        let rule = @ical.parse_rrule(p.value)
        let dtstart = ev.get("DTSTART").unwrap().as_date_time()
        let occ = @ical.expand(rule, dtstart)
        println("  rule   \{rule.to_string()}")
        println("  first \{occ.length()} occurrence(s):")
        let mut i = 0
        while i < occ.length() && i < 6 {
          println("    - \{occ[i].to_string()}")
          i = i + 1
        }
        if occ.length() > 6 {
          println("    ...")
        }
      } catch {
        e => println("  (could not expand rule: \{e.message()})")
      }
    }
    None => ()
  }
  println("")
}
