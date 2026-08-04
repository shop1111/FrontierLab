///|
struct Diagnosis {
  exit_code : Int
  stdout : String
  artifacts : Array[(String, String)]
}

///|
fn Diagnosis::new(
  exit_code? : Int = 0,
  stdout? : String = "",
  artifacts? : Array[(String, String)] = [],
) -> Diagnosis {
  { exit_code, stdout, artifacts }
}

///|
fn debug_result(
  command : String,
  format : String,
  text : String,
  json : String,
) -> String raise {
  match format {
    "json" => json_envelope(command, true, json)
    "text" => text
    other => fail("Unknown debug report format: \{other}")
  }
}

///|
fn counterexample_artifact(
  path : String,
  counterexample : @frontierlab.TraceCounterexample?,
) -> (String, String)? raise {
  if path == "" {
    return None
  }
  match counterexample {
    Some(value) =>
      Some(
        (
          path,
          if path.has_suffix(".html") {
            @frontierlab.render_trace_html(value.trace)
          } else {
            value.trace.encode_json()
          },
        ),
      )
    None => fail("No counterexample is available for this result")
  }
}

///|
fn diagnosis_report_artifact(
  path : String,
  value : @frontierlab.TraceDiagnosis,
) -> (String, String)? {
  if path == "" {
    return None
  }
  Some(
    (
      path,
      if path.has_suffix(".html") {
        diagnosis_html(value)
      } else if path.has_suffix(".json") {
        json_envelope("diagnose", value.passed(), diagnosis_json(value))
      } else {
        diagnosis_text(value)
      },
    ),
  )
}

///|
fn collect_artifact(
  artifacts : Array[(String, String)],
  artifact : (String, String)?,
) -> Unit {
  match artifact {
    Some(value) => artifacts.push(value)
    None => ()
  }
}

///|
fn output_execution(
  path : String,
  content : String,
  summary? : String = "",
) -> Diagnosis {
  if path == "-" {
    Diagnosis::new(stdout=content)
  } else {
    Diagnosis::new(
      stdout=if summary == "" {
        "Wrote \{path}"
      } else {
        "Wrote \{path}\n\{summary}"
      },
      artifacts=[(path, content)],
    )
  }
}

///|
fn apply_execution(value : Diagnosis) -> Int raise {
  for artifact in value.artifacts {
    @fs.write_string_to_file(artifact.0, artifact.1)
  }
  if value.stdout != "" {
    println(value.stdout)
  }
  value.exit_code
}
