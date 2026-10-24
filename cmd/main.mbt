///|
/// Runnable demo: unfold a small .ics stream and show how each line parses
/// into name, parameters and value.
///
/// Run with: `moon run cmd`

let sample : String =
  "BEGIN:VCALENDAR\r\n" +
  "VERSION:2.0\r\n" +
  "PRODID:-//Example//Calendar//EN\r\n" +
  "BEGIN:VEVENT\r\n" +
  "UID:1234@example.com\r\n" +
  "DTSTART;TZID=Asia/Shanghai:20261024T093000\r\n" +
  "SUMMARY:Team standup\r\n" +
  "DESCRIPTION:Discuss the weekly plan\\nBring coffee\r\n" +
  "ATTENDEE;CN=Alice;ROLE=REQ-PARTICIPANT:mailto:alice@example.com\r\n" +
  "END:VEVENT\r\n" +
  "END:VCALENDAR\r\n"

fn main {
  let lines = @ical.unfold(sample)
  println("unfolded \{lines.length()} logical content line(s):\n")
  let mut description = ""
  let mut i = 0
  while i < lines.length() {
    let _ = try {
      let cl = @ical.parse_content_line(lines[i])
      println("  \{cl.name}\{render_params(cl.params)}: \{cl.value}")
      if cl.name == "DESCRIPTION" {
        description = cl.value
      }
    } catch {
      e => println("  (parse error: \{e.message()})")
    }
    i = i + 1
  }
  println("\nDESCRIPTION after unescaping: \{@ical.unescape_text(description)}")
}

fn render_params(params : Array[@ical.Param]) -> String {
  if params.length() == 0 {
    return ""
  }
  let mut s = ""
  let mut i = 0
  while i < params.length() {
    let p = params[i]
    s = s + ";" + p.name + "=" + p.values[0]
    i = i + 1
  }
  s
}
