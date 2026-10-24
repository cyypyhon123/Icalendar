///|
/// RFC 5545 §3.6 components: the VCALENDAR / VEVENT / VTODO / VJOURNAL /
/// VFREEBUSY / VALARM / VTIMEZONE tree. `parse_calendar` turns a `.ics`
/// stream into a `Component` tree, and the accessors pull typed values back
/// out of it.

/// One property inside a component, e.g. `DTSTART;TZID=...:20261024T093000Z`.
/// The value is stored *unescaped* (TEXT escapes already reversed); parameters
/// keep their raw, quoted-form-preserving values.
pub struct Property {
  name : String
  params : Array[Param]
  value : String
}

/// A component and its nested sub-components, e.g. a VCALENDAR containing
/// VEVENT children.
pub struct Component {
  name : String
  properties : Array[Property]
  children : Array[Component]
}

/// Parse a whole `.ics` stream into the root VCALENDAR component.
pub fn parse_calendar(text : String) -> Component raise IcalError {
  let lines = unfold(text)
  let mut i = 0
  while i < lines.length() && lines[i] == "" {
    i = i + 1
  }
  if i >= lines.length() {
    raise IcalError::BadLine("calendar is empty")
  }
  let (root, next0) = parse_component(lines, i)
  if root.name != "VCALENDAR" {
    raise IcalError::BadLine("top-level component must be VCALENDAR, found \{root.name}")
  }
  let mut next = next0
  while next < lines.length() && lines[next] == "" {
    next = next + 1
  }
  if next != lines.length() {
    raise IcalError::BadLine("unexpected content after the top-level component")
  }
  root
}

fn parse_component(lines : Array[String], i : Int) -> (Component, Int) raise IcalError {
  let begin = parse_content_line(lines[i])
  if begin.name != "BEGIN" {
    raise IcalError::BadLine("expected a BEGIN line, found \{begin.name}")
  }
  let name = begin.value
  let comp : Component = { name, properties: [], children: [] }
  let mut idx = i + 1
  let mut done = false
  while !done {
    if idx >= lines.length() {
      raise IcalError::BadLine("component \{name} is never closed by an END line")
    }
    let cl = parse_content_line(lines[idx])
    if cl.name == "END" {
      if cl.value != name {
        raise IcalError::BadLine("END:\{cl.value} does not match BEGIN:\{name}")
      }
      idx = idx + 1
      done = true
    } else if cl.name == "BEGIN" {
      let (child, next) = parse_component(lines, idx)
      comp.children.push(child)
      idx = next
    } else {
      comp.properties.push(property_of(cl))
      idx = idx + 1
    }
  }
  (comp, idx)
}

fn property_of(cl : ContentLine) -> Property {
  { name: cl.name, params: cl.params, value: unescape_text(cl.value) }
}

/// The first property with the given name, or `None` if absent.
pub fn Component::get(self : Component, name : String) -> Property? {
  let mut i = 0
  while i < self.properties.length() {
    if self.properties[i].name == name {
      return Some(self.properties[i])
    }
    i = i + 1
  }
  None
}

/// Every property with the given name, in document order.
pub fn Component::get_all(self : Component, name : String) -> Array[Property] {
  let out : Array[Property] = []
  let mut i = 0
  while i < self.properties.length() {
    if self.properties[i].name == name {
      out.push(self.properties[i])
    }
    i = i + 1
  }
  out
}

/// Every child component with the given name, in document order.
pub fn Component::children_named(self : Component, name : String) -> Array[Component] {
  let out : Array[Component] = []
  let mut i = 0
  while i < self.children.length() {
    if self.children[i].name == name {
      out.push(self.children[i])
    }
    i = i + 1
  }
  out
}

/// The first value of the named parameter, or `None` if absent.
pub fn Property::param(self : Property, name : String) -> String? {
  let mut i = 0
  while i < self.params.length() {
    if self.params[i].name == name {
      if self.params[i].values.length() > 0 {
        return Some(self.params[i].values[0])
      }
      return None
    }
    i = i + 1
  }
  None
}

/// Interpret this property's value as a DATE.
pub fn Property::as_date(self : Property) -> Date raise IcalError {
  parse_date(self.value)
}

/// Interpret this property's value as a DATE-TIME.
pub fn Property::as_date_time(self : Property) -> DateTime raise IcalError {
  parse_date_time(self.value)
}

/// Interpret this property's value as a DURATION.
pub fn Property::as_duration(self : Property) -> Duration raise IcalError {
  parse_duration(self.value)
}

/// Interpret this property's value as a PERIOD.
pub fn Property::as_period(self : Property) -> Period raise IcalError {
  parse_period(self.value)
}
