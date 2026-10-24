///|
/// Runnable demo: parse a small calendar, pull out each event, expand its
/// recurrence rule, and show the whole thing serialized back out again.
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
