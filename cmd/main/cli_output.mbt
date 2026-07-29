///|
fn json_escape(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
}

///|
fn html_escape(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
fn json_envelope(command : String, ok : Bool, result : String) -> String {
  let ok_text = if ok { "true" } else { "false" }
  "{\"report_version\":\"frontierlab-debug-report/1.0\",\"ok\":\{ok_text},\"command\":\"\{command}\",\"result\":\{result}}"
}

///|
fn json_error_envelope(command : String, message : String) -> String {
  "{\"report_version\":\"frontierlab-debug-report/1.0\",\"ok\":false,\"command\":\"\{command}\",\"result\":null,\"diagnostics\":[\"\{json_escape(message)}\"]}"
}

///|
fn output_debug(
  command : String,
  format : String,
  text : String,
  json : String,
) -> Unit raise {
  if format == "json" {
    println(json_envelope(command, true, json))
  } else if format == "text" {
    println(text)
  } else {
    fail("Unknown debug report format: \{format}")
  }
}

///|
fn write_output(path : String, content : String) -> Unit raise {
  if path == "-" {
    println(content)
  } else {
    @fs.write_string_to_file(path, content)
    println("Wrote \{path}")
  }
}

///|
fn write_counterexample(
  path : String,
  counterexample : @frontierlab.TraceCounterexample?,
) -> Unit raise {
  if path == "" {
    return
  }
  match counterexample {
    Some(value) => {
      let content = if path.has_suffix(".html") {
        @frontierlab.render_trace_html(value.trace)
      } else {
        value.trace.encode_json()
      }
      @fs.write_string_to_file(path, content)
    }
    None => fail("No counterexample is available for this result")
  }
}
