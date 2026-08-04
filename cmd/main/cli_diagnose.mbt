///|
fn diagnosis_text(value : @frontierlab.TraceDiagnosis) -> String {
  let out = StringBuilder()
  out.write_string(
    "Diagnosis: \{if value.passed() { "PASS" } else { "FAIL" }}\n",
  )
  out.write_string(value.contract_report.report())
  match value.divergence {
    Some(divergence) =>
      out.write_string(
        "First divergence: step \{divergence.step} - \{divergence.message}\n",
      )
    None => out.write_string("First divergence: none\n")
  }
  out.write_string("Focus step: \{value.focus_step}\n")
  match value.transition_diff {
    Some(diff) => {
      out.write_string("Actual transition:\n")
      out.write_string(diff.report())
    }
    None => out.write_string("Actual transition: none\n")
  }
  match value.reference_diff {
    Some(diff) => {
      out.write_string("Reference difference:\n")
      out.write_string(diff.report())
    }
    None => out.write_string("Reference difference: none\n")
  }
  match value.focused_slice {
    Some(counterexample) =>
      out.write_string(
        "Focused counterexample slice: original steps \{counterexample.original_start}..\{counterexample.original_end}, focus \{counterexample.original_focus}\n",
      )
    None => out.write_string("Focused counterexample slice: none\n")
  }
  out.to_string()
}

///|
fn diagnosis_json(value : @frontierlab.TraceDiagnosis) -> String {
  let divergence = match value.divergence {
    Some(item) => item.to_json_string()
    None => "null"
  }
  let state_changes = match value.transition_diff {
    Some(item) => item.to_json_string()
    None => "null"
  }
  let reference_changes = match value.reference_diff {
    Some(item) => item.to_json_string()
    None => "null"
  }
  let counterexample = match value.focused_slice {
    Some(item) => item.to_json_string()
    None => "null"
  }
  let counterexample_kind = if value.focused_slice is Some(_) {
    "\"focused-window\""
  } else {
    "null"
  }
  "{\"contract\":\{value.contract_report.to_json_string()},\"divergence\":\{divergence},\"focus_step\":\{value.focus_step},\"state_changes\":\{state_changes},\"reference_changes\":\{reference_changes},\"counterexample\":\{counterexample},\"counterexample_kind\":\{counterexample_kind}}"
}

///|
fn diagnosis_html(value : @frontierlab.TraceDiagnosis) -> String {
  let text = html_escape(diagnosis_text(value))
  let json = diagnosis_json(value).replace_all(old="</", new="<\\/")
  "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n<title>FrontierLab diagnostic report</title>\n<style>body{max-width:960px;margin:40px auto;padding:0 20px;font:16px/1.55 system-ui;color:#172033}h1{color:#5b21b6}pre{white-space:pre-wrap;background:#f5f3ff;border:1px solid #ddd6fe;border-radius:12px;padding:18px}</style></head>\n<body><h1>FrontierLab diagnostic report</h1><pre>\{text}</pre>\n<script type=\"application/json\" id=\"frontierlab-diagnosis\">\{json}</script></body></html>"
}
