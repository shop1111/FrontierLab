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
