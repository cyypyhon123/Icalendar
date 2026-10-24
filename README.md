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
- parses recurrence rules (`RRULE`) and expands them into concrete occurrences,
- combines `RDATE` / `EXDATE` into an event's complete occurrence set,
- parses `VTIMEZONE` components and resolves floating times to UTC through them.

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
`BYYEARDAY`, `BYWEEKNO` (ISO week numbers, for yearly rules), `BYHOUR`,
`BYMINUTE`, `BYSECOND` and `BYSETPOS`. A rule must be bounded by `COUNT` or
`UNTIL` — an unbounded sequence is an error, not an infinite loop.

```
FREQ=MONTHLY;BYDAY=1MO;COUNT=6        first Monday of every month, six times
FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15   a birthday
FREQ=WEEKLY;BYDAY=MO,WE,FR            Mondays, Wednesdays, Fridays
FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO      Monday of ISO week 20, every year
FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1   the last weekday
```

For all-day events whose `DTSTART` is a `DATE` (a birthday, a holiday), use
`expand_dates(rule, start)` to get `DATE`s directly — the time-of-day is
dropped, so `BYHOUR` / `BYMINUTE` / `BYSECOND` are rejected.

For the complete set of a timed event — `DTSTART` plus its `RRULE` expansion,
plus every `RDATE`, minus every `EXDATE` — use `occurrences(event)`. It returns
date-times in ascending order with duplicates removed.

## Trying it

`moon run cmd` parses a small calendar embedded in the demo, expands each
event's rule and prints the round-tripped document. The `fixtures/` directory
holds standalone `.ics` files (`standup.ics`, `board-meeting.ics`,
`birthday.ics`) that exercise the same paths.

## Boundaries

This is a parsing/serialization/recurrence library, not a scheduling server.
The iTIP invitation protocol (scheduling messages) is out of scope for now.

## License

Apache-2.0.
