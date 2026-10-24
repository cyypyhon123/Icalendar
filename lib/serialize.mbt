///|
/// Serialization: turn components back into `.ics` text. Property values are
/// TEXT-escaped, parameter values that contain `:`, `;` or `,` are re-quoted,
/// and content lines longer than 75 octets are folded (continuation lines
/// begin with a single space, per RFC 5545 §3.1).

/// Format one parameter group as `NAME=value[,value...]`.
pub fn Param::to_string(self : Param) -> String {
  let mut out = self.name + "="
  let mut i = 0
  while i < self.values.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + quote_if_needed(self.values[i])
    i = i + 1
  }
  out
}

/// Format one property as a full content line (unfolded).
pub fn Property::to_string(self : Property) -> String {
  let mut out = self.name
  let mut i = 0
  while i < self.params.length() {
    out = out + ";" + self.params[i].to_string()
    i = i + 1
  }
  out + ":" + escape_text(self.value)
}

/// Format a component (and its children) as full `.ics` text with CRLF line
/// endings and 75-octet folding.
pub fn Component::to_string(self : Component) -> String {
  let mut out = "BEGIN:" + self.name + "\r\n"
  let mut i = 0
  while i < self.properties.length() {
    out = out + fold_line(self.properties[i].to_string()) + "\r\n"
    i = i + 1
  }
  let mut j = 0
  while j < self.children.length() {
    out = out + self.children[j].to_string()
    j = j + 1
  }
  out + "END:" + self.name + "\r\n"
}

/// Serialize a VCALENDAR root to `.ics` text.
pub fn serialize_calendar(cal : Component) -> String {
  cal.to_string()
}

/// Wrap a parameter value in quotes when it contains a character that would
/// otherwise be parsed as a delimiter.
fn quote_if_needed(v : String) -> String {
  let b = @utf8.encode(v)
  let mut needs = false
  let mut i = 0
  while i < b.length() {
    let c = b[i].to_int()
    if c == 0x3A || c == 0x3B || c == 0x2C {
      needs = true
    }
    i = i + 1
  }
  if needs {
    "\"" + v + "\""
  } else {
    v
  }
}

/// Fold a content line at 75 octets, splitting on character boundaries so a
/// multi-byte UTF-8 sequence is never cut in half.
fn fold_line(line : String) -> String {
  let b = @utf8.encode(line)
  let n = b.length()
  if n <= 75 {
    return line
  }
  let out : Array[Byte] = []
  let mut i = 0
  let mut first = true
  while i < n {
    if !first {
      out.push(b'\r')
      out.push(b'\n')
      out.push(b' ')
    }
    let mut end = if first { i + 75 } else { i + 74 }
    if end > n {
      end = n
    }
    end = char_boundary(b, end, n)
    append_range(out, b, i, end)
    i = end
    first = false
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

/// The largest cut position <= `limit` that does not split a UTF-8 sequence.
fn char_boundary(b : Bytes, limit : Int, n : Int) -> Int {
  if limit >= n {
    return n
  }
  let mut p = limit
  while p > 0 && b[p].to_int() >= 0x80 && b[p].to_int() <= 0xBF {
    p = p - 1
  }
  p
}

fn append_range(out : Array[Byte], b : Bytes, start : Int, end : Int) -> Unit {
  let mut k = start
  while k < end {
    out.push(b[k])
    k = k + 1
  }
}
