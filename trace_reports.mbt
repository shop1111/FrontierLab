///|
/// Render the event section of `TraceStats` as a Markdown table.
pub fn TraceStats::event_table(self : TraceStats) -> String {
  let out = StringBuilder()
  out.write_string("| Event | Count | First step | Last step |\n")
  out.write_string("|---|---:|---:|---:|\n")
  if self.event_counts.is_empty() {
    out.write_string("| none | 0 | - | - |\n")
  } else {
    for item in self.event_counts {
      out.write_string(
        "| \{escape_table_cell(item.name)} | \{item.count} | \{format_step(item.first_step)} | \{format_step(item.last_step)} |\n",
      )
    }
  }
  out.to_string()
}

///|
/// Render the object section of `TraceStats` as a Markdown table.
pub fn TraceStats::object_table(self : TraceStats) -> String {
  let out = StringBuilder()
  out.write_string(
    "| Object | Kind | Appearances | Max entities | First step | Last step |\n",
  )
  out.write_string("|---|---|---:|---:|---:|---:|\n")
  if self.object_usage.is_empty() {
    out.write_string("| none | - | 0 | 0 | - | - |\n")
  } else {
    for item in self.object_usage {
      out.write_string(
        "| \{escape_table_cell(item.object_id)} | \{item.object_kind} | \{item.appearances} | \{item.max_entities} | \{format_step(item.first_step)} | \{format_step(item.last_step)} |\n",
      )
    }
  }
  out.to_string()
}

///|
/// Render the most referenced targets as a Markdown table.
pub fn TraceStats::target_table(self : TraceStats, limit? : Int = 10) -> String {
  let out = StringBuilder()
  out.write_string(
    "| Target | References | Event refs | Highlight refs | Events | Roles |\n",
  )
  out.write_string("|---|---:|---:|---:|---|---|\n")
  let targets = self.top_targets(limit~)
  if targets.is_empty() {
    out.write_string("| none | 0 | 0 | 0 | - | - |\n")
  } else {
    for item in targets {
      let label = escape_table_cell(
        target_label(item.object_id, item.entity_id),
      )
      let event_names = escape_table_cell(item.event_names.join(", "))
      let roles = escape_table_cell(item.highlight_roles.join(", "))
      out.write_string(
        "| \{label} | \{item.references} | \{item.event_references} | \{item.highlight_references} | \{event_names} | \{roles} |\n",
      )
    }
  }
  out.to_string()
}

///|
/// Render the full analysis as Markdown for READMEs, reports, and CI artifacts.
pub fn TraceStats::to_markdown(
  self : TraceStats,
  target_limit? : Int = 10,
) -> String {
  let out = StringBuilder()
  out.write_string("# FrontierLab trace analysis\n\n")
  out.write_string("- Title: \{self.title}\n")
  out.write_string("- Algorithm: \{self.algorithm}\n")
  out.write_string("- Steps: \{self.step_count}\n")
  out.write_string("- Completed: \{self.completed}\n")
  out.write_string("- Initial objects: \{self.initial_object_count}\n")
  out.write_string("- Max objects per scene: \{self.max_objects_per_scene}\n")
  out.write_string("- Max entities per scene: \{self.max_entities_per_scene}\n")
  out.write_string("- Annotations: \{self.annotation_count}\n")
  out.write_string("- Highlights: \{self.highlight_count}\n")
  out.write_string("- Summary attributes: \{self.summary_count}\n\n")
  out.write_string("## Events\n\n")
  out.write_string(self.event_table())
  out.write_string("\n## Objects\n\n")
  out.write_string(self.object_table())
  out.write_string("\n## Targets\n\n")
  out.write_string(self.target_table(limit=target_limit))
  out.to_string()
}

///|
pub fn AlgorithmTrace::analysis_markdown(
  self : AlgorithmTrace,
  target_limit? : Int = 10,
) -> String {
  self.analyze().to_markdown(target_limit~)
}

///|
fn escape_table_cell(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new="<br>")
}

///|
fn format_step(step : Int) -> String {
  if step < 0 {
    "initial"
  } else {
    step.to_string()
  }
}

///|
fn target_label(object_id : String, entity_id : String?) -> String {
  match entity_id {
    Some(entity) => "\{object_id}/\{entity}"
    None => object_id
  }
}
