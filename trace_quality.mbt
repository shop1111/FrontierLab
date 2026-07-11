///|
/// Severity for lightweight trace quality checks.
pub(all) enum TraceLintSeverity {
  Info
  Warning
  Error
} derive(Debug, Eq, ToJson)

///|
/// A non-throwing quality observation for a trace document.
pub struct TraceLintIssue {
  severity : TraceLintSeverity
  code : String
  message : String
  step : Int
} derive(Debug, Eq, ToJson)

///|
pub fn TraceLintIssue::new(
  severity~ : TraceLintSeverity,
  code~ : String,
  message~ : String,
  step? : Int = -1,
) -> TraceLintIssue {
  { severity, code, message, step }
}

///|
pub fn TraceLintIssue::line(self : TraceLintIssue) -> String {
  let where_text = if self.step < 0 { "trace" } else { "step \{self.step}" }
  "[\{lint_severity_name(self.severity)}] \{self.code} at \{where_text}: \{self.message}"
}

///|
pub fn TraceLintIssue::markdown_row(self : TraceLintIssue) -> String {
  let where_text = if self.step < 0 { "trace" } else { "step \{self.step}" }
  "| \{lint_severity_name(self.severity)} | \{escape_quality_cell(self.code)} | \{escape_quality_cell(where_text)} | \{escape_quality_cell(self.message)} |"
}

///|
pub fn TraceLintIssue::is_error(self : TraceLintIssue) -> Bool {
  self.severity is Error
}

///|
pub fn TraceLintIssue::is_warning(self : TraceLintIssue) -> Bool {
  self.severity is Warning
}

///|
pub fn TraceLintIssue::is_info(self : TraceLintIssue) -> Bool {
  self.severity is Info
}

///|
pub fn TraceLintIssue::severity_name(self : TraceLintIssue) -> String {
  lint_severity_name(self.severity)
}

///|
/// A compact row describing one renderable point in a trace timeline.
pub struct TraceTimelineEntry {
  step : Int
  event_name : String
  target_count : Int
  object_count : Int
  entity_count : Int
  highlight_count : Int
  annotation_title : String
  completed : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn TraceTimelineEntry::new(
  step~ : Int,
  event_name~ : String,
  target_count~ : Int,
  object_count~ : Int,
  entity_count~ : Int,
  highlight_count~ : Int,
  annotation_title? : String = "",
  completed? : Bool = false,
) -> TraceTimelineEntry {
  {
    step,
    event_name,
    target_count,
    object_count,
    entity_count,
    highlight_count,
    annotation_title,
    completed,
  }
}

///|
pub fn TraceTimelineEntry::label(self : TraceTimelineEntry) -> String {
  let prefix = if self.step < 0 { "initial" } else { "step \{self.step}" }
  if self.annotation_title == "" {
    "\{prefix}: \{self.event_name}"
  } else {
    "\{prefix}: \{self.event_name} - \{self.annotation_title}"
  }
}

///|
pub fn TraceTimelineEntry::markdown_row(self : TraceTimelineEntry) -> String {
  "| \{quality_step_label(self.step)} | \{escape_quality_cell(self.event_name)} | \{self.target_count} | \{self.object_count} | \{self.entity_count} | \{self.highlight_count} | \{escape_quality_cell(self.annotation_title)} | \{self.completed} |"
}

///|
pub fn AlgorithmTrace::timeline(
  self : AlgorithmTrace,
) -> Array[TraceTimelineEntry] {
  let entries : Array[TraceTimelineEntry] = [
    TraceTimelineEntry::new(
      step=-1,
      event_name="initial",
      target_count=0,
      object_count=self.initial_scene.objects.length(),
      entity_count=self.initial_scene.entity_count(),
      highlight_count=self.initial_scene.highlights.length(),
    ),
  ]
  for step in self.steps {
    entries.push(
      TraceTimelineEntry::new(
        step=step.index,
        event_name=timeline_event_name(step.event),
        target_count=timeline_event_target_count(step.event),
        object_count=step.scene.objects.length(),
        entity_count=step.scene.entity_count(),
        highlight_count=step.scene.highlights.length(),
        annotation_title=match step.annotation {
          Some(note) => note.title
          None => ""
        },
        completed=step.event is Complete,
      ),
    )
  }
  entries
}

///|
/// Run non-throwing quality checks that complement `AlgorithmTrace::validate`.
pub fn AlgorithmTrace::lint(self : AlgorithmTrace) -> Array[TraceLintIssue] {
  let issues : Array[TraceLintIssue] = []
  if self.title.trim() == "" {
    issues.push(
      TraceLintIssue::new(
        severity=Error,
        code="empty-title",
        message="Trace title is empty.",
      ),
    )
  }
  if self.algorithm.trim() == "" {
    issues.push(
      TraceLintIssue::new(
        severity=Error,
        code="empty-algorithm",
        message="Trace algorithm name is empty.",
      ),
    )
  }
  if self.initial_scene.objects.is_empty() {
    issues.push(
      TraceLintIssue::new(
        severity=Warning,
        code="empty-initial-scene",
        message="Initial scene has no objects to render.",
      ),
    )
  }
  if self.steps.is_empty() {
    issues.push(
      TraceLintIssue::new(
        severity=Warning,
        code="empty-timeline",
        message="Trace has no recorded steps.",
      ),
    )
  } else if !(self.steps.last().unwrap().event is Complete) {
    issues.push(
      TraceLintIssue::new(
        severity=Warning,
        code="missing-complete",
        message="The last recorded step is not a Complete event.",
        step=self.steps.last().unwrap().index,
      ),
    )
  }
  if self.summary.is_empty() {
    issues.push(
      TraceLintIssue::new(
        severity=Info,
        code="empty-summary",
        message="Trace has no summary attributes for CLI or report output.",
      ),
    )
  }
  for step in self.steps {
    lint_step_shape(self, step, issues)
  }
  issues
}

///|
pub fn AlgorithmTrace::lint_report(self : AlgorithmTrace) -> String {
  let issues = self.lint()
  let out = StringBuilder()
  if issues.is_empty() {
    out.write_string("No trace lint issues.\n")
  } else {
    for issue in issues {
      out.write_string(issue.line())
      out.write_string("\n")
    }
  }
  out.to_string()
}

///|
pub fn AlgorithmTrace::lint_markdown(self : AlgorithmTrace) -> String {
  let out = StringBuilder()
  out.write_string("| Severity | Code | Location | Message |\n")
  out.write_string("|---|---|---|---|\n")
  let issues = self.lint()
  if issues.is_empty() {
    out.write_string("| info | clean | trace | No trace lint issues. |\n")
  } else {
    for issue in issues {
      out.write_string(issue.markdown_row())
      out.write_string("\n")
    }
  }
  out.to_string()
}

///|
pub fn AlgorithmTrace::lint_count(
  self : AlgorithmTrace,
  severity : TraceLintSeverity,
) -> Int {
  self
  .lint()
  .fold(init=0, fn(total, issue) {
    let increment = if issue.severity == severity { 1 } else { 0 }
    total + increment
  })
}

///|
pub fn AlgorithmTrace::has_lint_errors(self : AlgorithmTrace) -> Bool {
  self.lint().any(fn(issue) { issue.is_error() })
}

///|
pub fn AlgorithmTrace::has_lint_warnings(self : AlgorithmTrace) -> Bool {
  self.lint().any(fn(issue) { issue.is_warning() })
}

///|
pub fn AlgorithmTrace::timeline_report(self : AlgorithmTrace) -> String {
  let out = StringBuilder()
  for entry in self.timeline() {
    out.write_string(entry.label())
    out.write_string(
      " | targets=\{entry.target_count} objects=\{entry.object_count} entities=\{entry.entity_count} highlights=\{entry.highlight_count}\n",
    )
  }
  out.to_string()
}

///|
pub fn AlgorithmTrace::timeline_table(self : AlgorithmTrace) -> String {
  let out = StringBuilder()
  out.write_string(
    "| Step | Event | Targets | Objects | Entities | Highlights | Annotation | Complete |\n",
  )
  out.write_string("|---|---|---:|---:|---:|---:|---|---|\n")
  for entry in self.timeline() {
    out.write_string(entry.markdown_row())
    out.write_string("\n")
  }
  out.to_string()
}

///|
fn lint_step_shape(
  trace : AlgorithmTrace,
  step : AlgorithmTraceStep,
  issues : Array[TraceLintIssue],
) -> Unit {
  if step.scene.objects.is_empty() {
    issues.push(
      TraceLintIssue::new(
        severity=Warning,
        code="empty-step-scene",
        message="Step scene has no objects to render.",
        step=step.index,
      ),
    )
  }
  if timeline_event_target_count(step.event) == 0 &&
    !(step.event is Initialize ||
    step.event is Complete ||
    step.event is Custom(_, _)) {
    issues.push(
      TraceLintIssue::new(
        severity=Warning,
        code="event-without-target",
        message="Semantic event has no target references.",
        step=step.index,
      ),
    )
  }
  if step.annotation is None && !(step.event is Complete) {
    issues.push(
      TraceLintIssue::new(
        severity=Info,
        code="missing-annotation",
        message="Step has no teaching annotation.",
        step=step.index,
      ),
    )
  }
  if step.scene.entity_count() > trace.initial_scene.entity_count() * 4 &&
    trace.initial_scene.entity_count() > 0 {
    issues.push(
      TraceLintIssue::new(
        severity=Info,
        code="large-scene-growth",
        message="Step scene has grown more than four times beyond the initial scene.",
        step=step.index,
      ),
    )
  }
}

///|
fn timeline_event_name(event : TraceEvent) -> String {
  match event {
    Initialize => "initialize"
    Compare(_) => "compare"
    Swap(_, _) => "swap"
    Visit(_) => "visit"
    Update(_, _) => "update"
    Union(_, _) => "union"
    Relax(_, _, _) => "relax"
    Complete => "complete"
    Custom(kind, _) => kind
  }
}

///|
fn timeline_event_target_count(event : TraceEvent) -> Int {
  match event {
    Compare(targets) => targets.length()
    Swap(_, _) => 2
    Visit(_) => 1
    Update(_, _) => 1
    Union(_, _) => 2
    Relax(_, _, _) => 2
    _ => 0
  }
}

///|
fn lint_severity_name(severity : TraceLintSeverity) -> String {
  match severity {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
fn quality_step_label(step : Int) -> String {
  if step < 0 {
    "initial"
  } else {
    step.to_string()
  }
}

///|
fn escape_quality_cell(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new="<br>")
}
