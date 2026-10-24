///|
/// Public surface of the `icalendar` package: a thin, stable re-export over
/// the implementation in `@lib`. Every name here forwards to `@lib`, so
/// `import "icalendar"` and `import "icalendar/lib"` describe the same library.

// -- Types ----------------------------------------------------------------

pub type Param = @lib.Param
pub type ContentLine = @lib.ContentLine
pub type Date = @lib.Date
pub type Time = @lib.Time
pub type DateTime = @lib.DateTime
pub type Duration = @lib.Duration
pub type Period = @lib.Period
pub type Property = @lib.Property
pub type Component = @lib.Component
pub type Freq = @lib.Freq
pub type Weekday = @lib.Weekday
pub type ByDay = @lib.ByDay
pub type RecurrenceRule = @lib.RecurrenceRule
pub type IcalError = @lib.IcalError

// -- Content lines --------------------------------------------------------

/// Split an iCalendar stream into logical content lines, removing RFC 5545
/// line folding.
pub fn unfold(text : String) -> Array[String] {
  @lib.unfold(text)
}

/// Parse one unfolded content line into its property name, parameters and value.
pub fn parse_content_line(line : String) -> ContentLine raise IcalError {
  @lib.parse_content_line(line)
}

/// Escape a TEXT value for inclusion in a content line.
pub fn escape_text(value : String) -> String {
  @lib.escape_text(value)
}

/// Reverse the TEXT escaping applied by `escape_text`.
pub fn unescape_text(value : String) -> String {
  @lib.unescape_text(value)
}

// -- Date/time values -----------------------------------------------------

/// Parse an RFC 5545 `DATE` value.
pub fn parse_date(s : String) -> Date raise IcalError {
  @lib.parse_date(s)
}

/// Parse an RFC 5545 `TIME` value.
pub fn parse_time(s : String) -> Time raise IcalError {
  @lib.parse_time(s)
}

/// Parse an RFC 5545 `DATE-TIME` value.
pub fn parse_date_time(s : String) -> DateTime raise IcalError {
  @lib.parse_date_time(s)
}

/// Parse an RFC 5545 `DURATION` value.
pub fn parse_duration(s : String) -> Duration raise IcalError {
  @lib.parse_duration(s)
}

/// Parse an RFC 5545 `PERIOD` value.
pub fn parse_period(s : String) -> Period raise IcalError {
  @lib.parse_period(s)
}

// -- Components -----------------------------------------------------------

/// Parse a whole `.ics` stream into a component tree.
pub fn parse_calendar(text : String) -> Component raise IcalError {
  @lib.parse_calendar(text)
}

/// Serialize a component tree back to `.ics` text.
pub fn serialize_calendar(cal : Component) -> String {
  @lib.serialize_calendar(cal)
}

// -- Recurrence -----------------------------------------------------------

/// Parse an RFC 5545 `RRULE` value.
pub fn parse_rrule(s : String) -> RecurrenceRule raise IcalError {
  @lib.parse_rrule(s)
}

/// Expand a recurrence rule from its start instant into concrete occurrences.
pub fn expand(rule : RecurrenceRule, dtstart : DateTime) -> Array[DateTime] raise IcalError {
  @lib.expand(rule, dtstart)
}
