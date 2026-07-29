///|
struct Diagnosis {
  contract : @frontierlab.ContractReport
  divergence : @frontierlab.TraceDivergence?
  focus_step : Int
  state_changes : @frontierlab.TraceFrameDiff?
  counterexample : @frontierlab.TraceCounterexample?
}

///|
fn Diagnosis::passed(self : Diagnosis) -> Bool {
  self.contract.passed && self.divergence is None
}

///|
fn calculate_diagnosis(
  expected : @frontierlab.AlgorithmTrace,
  actual : @frontierlab.AlgorithmTrace,
  contract : @frontierlab.TraceContract,
) -> Diagnosis {
  let contract_report = contract.check(actual)
  let divergence = @frontierlab.first_divergence(expected, actual)
  let contract_step = match contract_report.first_failure {
    Some(value) => value.step
    None => -1
  }
  let divergence_step = match divergence {
    Some(value) => value.step
    None => -1
  }
  let focus_step = if contract_step < 0 {
    divergence_step
  } else if divergence_step < 0 {
    contract_step
  } else if contract_step < divergence_step {
    contract_step
  } else {
    divergence_step
  }
  let counterexample = if focus_step >= 0 && focus_step < actual.steps.length() {
    Some(try! actual.slice(center=focus_step))
  } else {
    None
  }
  let state_changes = if focus_step >= 0 && focus_step < actual.steps.length() {
    Some(try! actual.diff(from_step=focus_step - 1, to_step=focus_step))
  } else {
    None
  }
  {
    contract: contract_report,
    divergence,
    focus_step,
    state_changes,
    counterexample,
  }
}

///|
fn diagnosis_text(value : Diagnosis) -> String {
  let out = StringBuilder()
  out.write_string(
    "Diagnosis: \{if value.passed() { "PASS" } else { "FAIL" }}\n",
  )
  out.write_string(value.contract.report())
  match value.divergence {
    Some(divergence) =>
      out.write_string(
        "First divergence: step \{divergence.step} - \{divergence.message}\n",
      )
    None => out.write_string("First divergence: none\n")
  }
  out.write_string("Focus step: \{value.focus_step}\n")
  match value.state_changes {
    Some(diff) => out.write_string(diff.report())
    None => out.write_string("State changes: none\n")
  }
  match value.counterexample {
    Some(counterexample) =>
      out.write_string(
        "Counterexample: original steps \{counterexample.original_start}..\{counterexample.original_end}, focus \{counterexample.original_focus}\n",
      )
    None => out.write_string("Counterexample: none\n")
  }
  out.to_string()
}

///|
fn diagnosis_json(value : Diagnosis) -> String {
  let divergence = match value.divergence {
    Some(item) => item.to_json_string()
    None => "null"
  }
  let state_changes = match value.state_changes {
    Some(item) => item.to_json_string()
    None => "null"
  }
  let counterexample = match value.counterexample {
    Some(item) => item.to_json_string()
    None => "null"
  }
  "{\"contract\":\{value.contract.to_json_string()},\"divergence\":\{divergence},\"focus_step\":\{value.focus_step},\"state_changes\":\{state_changes},\"counterexample\":\{counterexample}}"
}

///|
fn diagnosis_html(value : Diagnosis) -> String {
  let text = html_escape(diagnosis_text(value))
  let json = diagnosis_json(value).replace_all(old="</", new="<\\/")
  "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n<title>FrontierLab diagnostic report</title>\n<style>body{max-width:960px;margin:40px auto;padding:0 20px;font:16px/1.55 system-ui;color:#172033}h1{color:#5b21b6}pre{white-space:pre-wrap;background:#f5f3ff;border:1px solid #ddd6fe;border-radius:12px;padding:18px}</style></head>\n<body><h1>FrontierLab diagnostic report</h1><pre>\{text}</pre>\n<script type=\"application/json\" id=\"frontierlab-diagnosis\">\{json}</script></body></html>"
}

///|
fn write_diagnosis_report(path : String, value : Diagnosis) -> Unit raise {
  if path == "" {
    return
  }
  let content = if path.has_suffix(".html") {
    diagnosis_html(value)
  } else if path.has_suffix(".json") {
    json_envelope("diagnose", value.passed(), diagnosis_json(value))
  } else {
    diagnosis_text(value)
  }
  @fs.write_string_to_file(path, content)
}

///|
fn output_diagnosis(format : String, value : Diagnosis) -> Unit raise {
  if format == "json" {
    println(json_envelope("diagnose", value.passed(), diagnosis_json(value)))
  } else if format == "text" {
    println(diagnosis_text(value))
  } else {
    fail("Unknown debug report format: \{format}")
  }
}
