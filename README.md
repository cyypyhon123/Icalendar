# icalendar

A pure-MoonBit reader, writer and recurrence engine for [RFC 5545](https://datatracker.ietf.org/doc/html/rfc5545)
iCalendar — the format behind `.ics` calendar files. No native code, no runtime
dependencies, compiles to WASM.

## What it does

An iCalendar document is a tree of *components* (`VCALENDAR` containing
`VEVENT`, `VTODO`, `VALARM`, ...), each carrying *properties* such as
`DTSTART`, `SUMMARY`, or `RRULE`. This library:

- unfolds and parses the content-line grammar that everything else is built on,
- parses and formats the DATE / TIME / DATE-TIME / DURATION / PERIOD value types,
- builds a component tree you can query (`children_named`, `get`, typed accessors),
- serializes it back with correct 75-octet line folding,
- parses recurrence rules (`RRULE`) and expands them into concrete occurrences.

## A taste

```moonbit
let cal = @icalendar.parse_calendar(ics_text)

for ev in cal.children_named("VEVENT") {
  match ev.get("RRULE") {
    Some(rule) => {
      let start = ev.get("DTSTART").unwrap().as_date_time()
      let rule = @icalendar.parse_rrule(rule.value)
      for occ in @icalendar.expand(rule, start) {
        println(occ.to_string())
      }
    }
    None => println("one-off event")
  }
}
```

The package is available as `icalendar` (a re-export facade) or, more directly,
as `icalendar/lib`. Both expose the same functions.

## Recurrence

The expander handles every `FREQ`, `INTERVAL`, `COUNT`, `UNTIL`, `WKST`,
`BYMONTH`, `BYMONTHDAY`, `BYDAY` (including `1MO` / `-1FR` ordinals),
`BYYEARDAY`, `BYHOUR`, `BYMINUTE`, `BYSECOND` and `BYSETPOS`. A rule must be
bounded by `COUNT` or `UNTIL` — an unbounded sequence is an error, not an
infinite loop.

```
FREQ=MONTHLY;BYDAY=1MO;COUNT=6        first Monday of every month, six times
FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15   a birthday
FREQ=WEEKLY;BYDAY=MO,WE,FR            Mondays, Wednesdays, Fridays
FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1   the last weekday
```

## Trying it

`moon run cmd` parses a small calendar embedded in the demo, expands each
event's rule and prints the round-tripped document. The `fixtures/` directory
holds standalone `.ics` files (`standup.ics`, `board-meeting.ics`,
`birthday.ics`) that exercise the same paths.

## Boundaries

This is a parsing/serialization/recurrence library, not a scheduling server.
Timezone resolution through `VTIMEZONE` (local-time `DTSTART` values are kept
verbatim rather than converted), `BYWEEKNO` expansion, and the iTIP
invitation protocol are out of scope for now; `DATE`-valued recurrences are
parsed but `expand` operates on `DATE-TIME` starts.

## License

Apache-2.0.
