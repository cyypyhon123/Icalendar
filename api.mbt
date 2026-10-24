///|
/// Stable entry points for `@icalendar` users. The implementation lives in
/// `@lib`; these functions are the surface a `moon add icalendar` caller uses.

/// Split an iCalendar stream into logical content lines, removing RFC 5545
/// line folding (continuation lines that begin with a space or tab).
pub fn unfold(text : String) -> Array[String] {
  @lib.unfold(text)
}

/// Parse one unfolded content line into its property name, parameters and value.
pub fn parse_content_line(line : String) -> @lib.ContentLine raise @lib.IcalError {
  @lib.parse_content_line(line)
}
