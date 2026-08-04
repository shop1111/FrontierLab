///|
/// The authoritative result of combining a semantic contract with an
/// optional reference trace.
pub struct TraceDiagnosis {
  contract_report : ContractReport
  divergence : TraceDivergence?
  focus_step : Int
  transition_diff : TraceFrameDiff?
  reference_diff : TraceFrameDiff?
  focused_slice : TraceCounterexample?
} derive(Debug, Eq, ToJson)

///|
/// Return whether both the semantic contract and optional reference agree.
pub fn TraceDiagnosis::passed(self : TraceDiagnosis) -> Bool {
  self.contract_report.passed && self.divergence is None
}

///|
/// Diagnose an actual trace with a contract and an optional reference trace.
///
/// The focus is the earliest non-negative contract failure or divergence.
/// `transition_diff` describes the actual transition into that focus, while
/// `reference_diff` compares expected and actual state at the focus.
pub fn diagnose_trace(
  actual : AlgorithmTrace,
  contract~ : TraceContract,
  expected? : AlgorithmTrace,
) -> TraceDiagnosis {
  let contract_report = contract.check(actual)
  let divergence = match expected {
    Some(reference) => first_divergence(reference, actual)
    None => None
  }
  let contract_step = match contract_report.first_failure {
    Some(value) => value.step
    None => -1
  }
  let divergence_step = match divergence {
    Some(value) => value.step
    None => -1
  }
  let focus_step = diagnosis_focus_step(contract_step, divergence_step)
  let transition_diff = if focus_step >= 0 && focus_step < actual.steps.length() {
    Some(try! actual.diff(from_step=focus_step - 1, to_step=focus_step))
  } else {
    None
  }
  let reference_diff = match expected {
    Some(reference) if focus_step >= 0 &&
      focus_step < reference.steps.length() &&
      focus_step < actual.steps.length() =>
      Some({
        from_step: focus_step,
        to_step: focus_step,
        changes: debugger_scene_diff(
          reference.steps[focus_step].scene,
          actual.steps[focus_step].scene,
        ),
      })
    _ => None
  }
  let focused_slice = if focus_step >= 0 && focus_step < actual.steps.length() {
    Some(try! actual.slice(center=focus_step))
  } else {
    None
  }
  {
    contract_report,
    divergence,
    focus_step,
    transition_diff,
    reference_diff,
    focused_slice,
  }
}

///|
fn diagnosis_focus_step(contract_step : Int, divergence_step : Int) -> Int {
  if contract_step < 0 {
    divergence_step
  } else if divergence_step < 0 {
    contract_step
  } else if contract_step <= divergence_step {
    contract_step
  } else {
    divergence_step
  }
}
