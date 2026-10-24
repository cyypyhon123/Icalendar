///|
/// RFC 5545 §3.1 "Content Lines" — the grammar every iCalendar property is
/// built on. A logical content line is split into a property name, a list of
/// `name=value[,value...]` parameters, and a value, joined by `:`.
///
/// Lines may be "folded": a CRLF followed by a space or tab is a continuation
/// of the previous logical line. `unfold` removes that folding, then
/// `parse_content_line` splits the result into its three parts.

/// The `Param` type captures one `NAME=value[,value...]` parameter group.
pub struct Param {
  name : String
  values : Array[String]
}

/// One logical, unfolded content line: `NAME;PARAM=...:VALUE`.
pub struct ContentLine {
  name : String
  params : Array[Param]
  value : String
}

/// Construct a parameter group. (Read-only structs are only constructible
/// here, so this is the public way to build one.)
pub fn Param::new(name : String, values : Array[String]) -> Param {
  { name, values }
}

/// A structural problem in a content line (missing name/colon, unterminated
/// quote, ...). The payload names the offending input.
pub(all) suberror IcalError {
  BadLine(String)
}

/// A human-readable description of the error, suitable for diagnostics.
pub fn IcalError::message(self : IcalError) -> String {
  match self {
    BadLine(what) => "malformed content line: \{what}"
  }
}

// Byte values for the ASCII delimiters the grammar is defined over.
let semicolon : Int = 0x3B // ';'
let colon : Int = 0x3A // ':'
let comma : Int = 0x2C // ','
let equals : Int = 0x3D // '='
let quote : Int = 0x22 // '"'
let cr : Int = 0x0D // '\r'
let lf : Int = 0x0A // '\n'
let space : Int = 0x20
let tab : Int = 0x09
let backslash : Int = 0x5C // '\'

/// Split a raw iCalendar stream into logical lines, folding continuations.
///
/// A line ending of CRLF, LF, or CR terminates a physical line; a line whose
/// first character is a space or tab is a fold and is glued to the previous
/// logical line (with its leading whitespace dropped, per RFC 5545 §3.1).
pub fn unfold(text : String) -> Array[String] {
  let b = @utf8.encode(text)
  let n = b.length()
  let lines : Array[String] = []
  let mut i = 0
  while i < n {
    // Start of a new logical line. Collect its physical-line segments so that
    // folded continuations are glued back together with leading whitespace
    // dropped.
    let segs : Array[String] = []
    let mut done = false
    while !done {
      let mut e = i
      while e < n && b[e].to_int() != cr && b[e].to_int() != lf {
        e = e + 1
      }
      if e > i {
        segs.push(@utf8.decode_lossy(b[i:e]))
      }
      if e < n {
        if b[e].to_int() == cr && e + 1 < n && b[e + 1].to_int() == lf {
          e = e + 2
        } else {
          e = e + 1
        }
      }
      // Is the next physical line a continuation?
      let mut j = e
      while j < n && (b[j].to_int() == space || b[j].to_int() == tab) {
        j = j + 1
      }
      if j > e && j < n && b[j].to_int() != cr && b[j].to_int() != lf {
        i = j
      } else {
        i = e
        done = true
      }
    }
    let mut line = ""
    let mut k = 0
    while k < segs.length() {
      line = line + segs[k]
      k = k + 1
    }
    lines.push(line)
  }
  lines
}

/// Parse one unfolded content line into name, params and value.
pub fn parse_content_line(line : String) -> ContentLine raise IcalError {
  let b = @utf8.encode(line)
  let n = b.length()
  let mut i = 0
  while i < n && b[i].to_int() != semicolon && b[i].to_int() != colon {
    i = i + 1
  }
  if i == 0 {
    raise IcalError::BadLine("content line has no property name: \{line}")
  }
  let name = @utf8.decode_lossy(b[0:i])
  let params : Array[Param] = []
  while i < n && b[i].to_int() == semicolon {
    let (p, next) = parse_param(b, i + 1)
    params.push(p)
    i = next
  }
  if i >= n || b[i].to_int() != colon {
    raise IcalError::BadLine("content line has no ':' separator: \{line}")
  }
  let value = @utf8.decode_lossy(b[i + 1:n])
  { name, params, value }
}

/// Parse the `NAME=value[,value...]` group starting just past a `;`.
fn parse_param(b : Bytes, start : Int) -> (Param, Int) raise IcalError {
  let n = b.length()
  let mut i = start
  while i < n && b[i].to_int() != equals {
    i = i + 1
  }
  if i == start || i >= n {
    raise IcalError::BadLine("malformed parameter (missing '=')")
  }
  let pname = @utf8.decode_lossy(b[start:i])
  i = i + 1
  let values : Array[String] = []
  let mut done = false
  while !done {
    let (v, next) = parse_param_value(b, i)
    values.push(v)
    i = next
    if i < n && b[i].to_int() == comma {
      i = i + 1
    } else {
      done = true
    }
  }
  ({ name: pname, values }, i)
}

/// Parse a single parameter value, honouring quoted strings.
fn parse_param_value(b : Bytes, start : Int) -> (String, Int) raise IcalError {
  let n = b.length()
  if start < n && b[start].to_int() == quote {
    let mut i = start + 1
    while i < n && b[i].to_int() != quote {
      i = i + 1
    }
    if i >= n {
      raise IcalError::BadLine("unterminated quoted parameter value")
    }
    return (@utf8.decode_lossy(b[start + 1:i]), i + 1)
  } else {
    let mut i = start
    while i < n && b[i].to_int() != semicolon && b[i].to_int() != colon && b[i].to_int() != comma {
      i = i + 1
    }
    return (@utf8.decode_lossy(b[start:i]), i)
  }
}

/// Escape a TEXT value for inclusion in an iCalendar line.
///
/// Backslash, semicolon, comma and newline are backslash-escaped; the newline
/// becomes the two-character sequence `\n`.
pub fn escape_text(value : String) -> String {
  let b = @utf8.encode(value)
  let out : Array[Byte] = []
  let n = b.length()
  let mut i = 0
  while i < n {
    let c = b[i]
    let ci = c.to_int()
    if ci == backslash {
      out.push(b'\\')
      out.push(b'\\')
    } else if ci == semicolon {
      out.push(b'\\')
      out.push(b';')
    } else if ci == comma {
      out.push(b'\\')
      out.push(b',')
    } else if ci == lf {
      out.push(b'\\')
      out.push(b'n')
    } else {
      out.push(c)
    }
    i = i + 1
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

/// Reverse the TEXT escaping applied by `escape_text`.
pub fn unescape_text(value : String) -> String {
  let b = @utf8.encode(value)
  let out : Array[Byte] = []
  let n = b.length()
  let mut i = 0
  while i < n {
    if b[i].to_int() == backslash && i + 1 < n {
      let next = b[i + 1].to_int()
      if next == 0x6E || next == 0x4E {
        out.push(b'\n')
        i = i + 2
      } else if next == backslash || next == semicolon || next == comma {
        out.push(b[i + 1])
        i = i + 2
      } else {
        out.push(b[i])
        i = i + 1
      }
    } else {
      out.push(b[i])
      i = i + 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}
