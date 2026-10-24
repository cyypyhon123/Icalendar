test "unfold joins a folded line" {
  let text = "DESCRIPTION:hello\r\n world"
  let lines = unfold(text)
  assert_eq(lines.length(), 1)
  assert_eq(lines[0], "DESCRIPTION:helloworld")
}

test "unfold splits distinct lines" {
  let text = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR\r\n"
  let lines = unfold(text)
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "BEGIN:VCALENDAR")
  assert_eq(lines[1], "VERSION:2.0")
  assert_eq(lines[2], "END:VCALENDAR")
}

test "unfold tolerates LF-only and CR-only endings" {
  let lf = "A:1\nB:2\n"
  assert_eq(unfold(lf).length(), 2)
  let cr = "A:1\rB:2\r"
  assert_eq(unfold(cr).length(), 2)
}

test "parse a plain content line" {
  let cl = parse_content_line("SUMMARY:Team standup")
  assert_eq(cl.name, "SUMMARY")
  assert_eq(cl.params.length(), 0)
  assert_eq(cl.value, "Team standup")
}

test "parse a single parameter" {
  let cl = parse_content_line("DTSTART;TZID=America/New_York:20261024T093000")
  assert_eq(cl.name, "DTSTART")
  assert_eq(cl.params.length(), 1)
  assert_eq(cl.params[0].name, "TZID")
  assert_eq(cl.params[0].values.length(), 1)
  assert_eq(cl.params[0].values[0], "America/New_York")
  assert_eq(cl.value, "20261024T093000")
}

test "parse a quoted multi-valued parameter" {
  let cl = parse_content_line("ATTENDEE;MEMBER=\"mailto:a@x.org\",\"mailto:b@x.org\":mailto:c@x.org")
  assert_eq(cl.name, "ATTENDEE")
  assert_eq(cl.params[0].name, "MEMBER")
  assert_eq(cl.params[0].values.length(), 2)
  assert_eq(cl.params[0].values[0], "mailto:a@x.org")
  assert_eq(cl.params[0].values[1], "mailto:b@x.org")
  assert_eq(cl.value, "mailto:c@x.org")
}

test "parse a colon inside a quoted parameter" {
  let cl = parse_content_line("X-QUOTED;ALTREP=\"http://x.org/a:b\":ok")
  assert_eq(cl.name, "X-QUOTED")
  assert_eq(cl.params[0].values[0], "http://x.org/a:b")
  assert_eq(cl.value, "ok")
}

test "parse a line with multiple parameters" {
  let cl = parse_content_line("ORGANIZER;CN=Alice;ROLE=CHAIR:mailto:alice@x.org")
  assert_eq(cl.params.length(), 2)
  assert_eq(cl.params[1].name, "ROLE")
  assert_eq(cl.params[1].values[0], "CHAIR")
}

test "parse rejects a line without a name" {
  let caught = try {
    let _ = parse_content_line(":value")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "parse rejects a line without a colon" {
  let caught = try {
    let _ = parse_content_line("SUMMARY;X=1")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

test "text escaping round-trips special characters" {
  assert_eq(escape_text("a;b,c\\d"), "a\\;b\\,c\\\\d")
  assert_eq(unescape_text("a\\;b\\,c\\\\d"), "a;b,c\\d")
  assert_eq(unescape_text("line1\\nline2"), "line1\nline2")
  assert_eq(unescape_text("line1\\Nline2"), "line1\nline2")
}

test "text escaping leaves plain text alone" {
  assert_eq(escape_text("hello world"), "hello world")
  assert_eq(unescape_text("hello world"), "hello world")
}
