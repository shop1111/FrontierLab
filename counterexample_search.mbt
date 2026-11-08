///|
/// A minimal failing input found by `search_sequence_counterexample`, with
/// full traces and a diagnosis of the minimal case.
pub struct SequenceCounterexample {
  seed : UInt64
  cases_tried : Int32
  original_input : Array[Int32]
  input : Array[Int32]
  shrink_steps : Int32
  reason : String
  actual_output : Array[Int32]
  expected_output : Array[Int32]?
  actual_trace : AlgorithmTrace
  expected_trace : AlgorithmTrace?
  diagnosis : TraceDiagnosis
} derive(Debug, Eq, ToJson)

///|
pub extend SequenceCounterexample with Debug::{to_repr}

///|
pub extend SequenceCounterexample with Eq::{not_equal, equal}

///|
pub extend SequenceCounterexample with ToJson::{to_json}

///|
/// SplitMix64, so a seed finds the same counterexample on every backend and
/// compiler version.
priv struct SearchRandom {
  mut state : UInt64
}

///|
fn SearchRandom::next(self : SearchRandom) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// A uniform value in `0..<limit`; `limit` must be positive.
fn SearchRandom::below(self : SearchRandom, limit : Int32) -> Int32 {
  (self.next() % limit.to_uint64()).to_int()
}

///|
fn run_counted(
  algorithm : (TracedArray[Int32]) -> Unit,
  input : Array[Int32],
) -> Array[Int32] {
  let array = TracedArray::new(input, level=Count)
  algorithm(array)
  array.to_array()
}

///|
fn run_traced(
  algorithm : (TracedArray[Int32]) -> Unit,
  input : Array[Int32],
  title : String,
  options : TraceOptions,
) -> AlgorithmTrace raise TraceError {
  let array = TracedArray::new(
    input,
    title~,
    algorithm="counterexample",
    options~,
  )
  algorithm(array)
  array.finish()
}

///|
fn sorted_copy(values : Array[Int32]) -> Array[Int32] {
  let copy = values.copy()
  copy.sort()
  copy
}

///|
/// The default property: the output is the input in nondecreasing order.
fn sorted_permutation_failure(
  input : Array[Int32],
  output : Array[Int32],
) -> String? {
  if output != sorted_copy(output) {
    Some("output \{format_values(output)} is not sorted")
  } else if output != sorted_copy(input) {
    Some("output \{format_values(output)} is not a permutation of the input")
  } else {
    None
  }
}

///|
/// Inputs one step smaller than `input`: chunks removed first (largest
/// first), then values replaced by their ranks, then single values lowered
/// toward zero.
fn shrink_candidates(input : Array[Int32]) -> Array[Array[Int32]] {
  let candidates : Array[Array[Int32]] = []
  let n = input.length()
  let mut chunk = n
  while chunk > 0 {
    for start = 0; start < n; start = start + chunk {
      let end = if start + chunk < n { start + chunk } else { n }
      candidates.push([..input[:start], ..input[end:]])
    }
    chunk = chunk / 2
  }
  // Dense ranks keep the relative order, which is all a comparison sort sees.
  let distinct = sorted_copy(input)
  distinct.dedup()
  let ranked = input.map(fn(value) {
    distinct.binary_search(value).unwrap_or(0)
  })
  if ranked != input {
    candidates.push(ranked)
  }
  for index, value in input {
    for smaller in [0, value / 2, value - 1] {
      if smaller >= 0 && smaller < value {
        let candidate = input.copy()
        candidate[index] = smaller
        if !candidates.contains(candidate) {
          candidates.push(candidate)
        }
      }
    }
  }
  candidates
}

///|
/// Searches random integer arrays for an input on which `algorithm` fails,
/// shrinks it to a minimal one, and diagnoses that input.
///
/// An input fails when its output differs from `reference`'s output, or when
/// `check(input, output)` returns a reason. Without either, the output must
/// be the sorted input. With `match_events`, an input also fails when the
/// algorithm's operations differ from `reference`'s even though the outputs
/// agree. Candidates run at `TraceLevel::Count`; only the minimal input is
/// recorded in full and passed to `diagnose_trace` with `contract`, which
/// defaults to `sorted_int_sequence_contract` when the default property is
/// used and to `sequence_transition_contract` otherwise.
///
/// Inputs have up to `max_length` values in `0..=max_value`; the first cases
/// are shorter. Shrinking evaluates at most `max_shrinks` candidates.
/// Returns `None` when every case passes. An algorithm that aborts, for
/// example by indexing out of bounds, stops the whole program.
pub fn search_sequence_counterexample(
  algorithm : (TracedArray[Int32]) -> Unit,
  reference? : (TracedArray[Int32]) -> Unit,
  check? : (Array[Int32], Array[Int32]) -> String?,
  contract? : TraceContract,
  match_events~ : Bool = false,
  cases~ : Int32 = 500,
  max_length~ : Int32 = 8,
  max_value~ : Int32 = 9,
  max_shrinks~ : Int32 = 2000,
  seed~ : UInt64 = 1,
  options~ : TraceOptions = TraceOptions::default(),
) -> SequenceCounterexample? raise TraceError {
  if cases <= 0 || max_length < 0 || max_value < 0 || max_shrinks < 0 {
    raise InvalidStep(
      "counterexample search needs positive cases and non-negative limits",
    )
  }
  if match_events && reference is None {
    raise InvalidStep("match_events requires a reference algorithm")
  }
  fn failure(input : Array[Int32]) -> String? raise TraceError {
    let output = run_counted(algorithm, input)
    match reference {
      Some(expected_algorithm) => {
        let expected = run_counted(expected_algorithm, input)
        if output != expected {
          return Some(
            "output \{format_values(output)} differs from reference \{format_values(expected)}",
          )
        }
      }
      None => ()
    }
    match check {
      Some(property) =>
        if property(input, output) is Some(reason) {
          return Some(reason)
        }
      None =>
        if reference is None {
          return sorted_permutation_failure(input, output)
        }
    }
    if match_events && reference is Some(expected_algorithm) {
      let actual = run_traced(algorithm, input, "actual", options)
      let expected = run_traced(expected_algorithm, input, "actual", options)
      if first_divergence(expected, actual) is Some(divergence) {
        return Some(
          "operations diverge at step \{divergence.step}: expected \{step_label(expected, divergence.step)}, actual \{step_label(actual, divergence.step)}",
        )
      }
    }
    None
  }

  let random = { state: seed, }
  let mut found : (Int32, Array[Int32])? = None
  for case_index in 0..<cases {
    // The first cases are short, so small counterexamples surface first.
    let limit = 2 + case_index / 2
    let length = random.below(
      (if limit < max_length { limit } else { max_length }) + 1,
    )
    let input = Array::makei(length, fn(_) { random.below(max_value + 1) })
    if failure(input) is Some(_) {
      found = Some((case_index + 1, input))
      break
    }
  }
  guard found is Some((cases_tried, original_input)) else { return None }
  let mut input = original_input
  let mut shrink_steps = 0
  let mut attempts = 0
  let mut improved = true
  while improved && attempts < max_shrinks {
    improved = false
    for candidate in shrink_candidates(input) {
      if attempts >= max_shrinks {
        break
      }
      attempts += 1
      if failure(candidate) is Some(_) {
        input = candidate
        shrink_steps += 1
        improved = true
        break
      }
    }
  }
  let reason = failure(input).unwrap_or("input no longer fails")
  let actual_trace = run_traced(
    algorithm, input, "Counterexample: actual", options,
  )
  let expected_trace = match reference {
    Some(expected_algorithm) =>
      Some(
        run_traced(
          expected_algorithm, input, "Counterexample: reference", options,
        ),
      )
    None => None
  }
  let contract = match contract {
    Some(value) => value
    None =>
      if reference is None && check is None {
        sorted_int_sequence_contract(object_id="values")
      } else {
        sequence_transition_contract(object_id="values")
      }
  }
  let diagnosis = match expected_trace {
    Some(expected) => diagnose_trace(actual_trace, contract~, expected~)
    None => diagnose_trace(actual_trace, contract~)
  }
  Some({
    seed,
    cases_tried,
    original_input,
    input,
    shrink_steps,
    reason,
    actual_output: run_counted(algorithm, input),
    expected_output: match reference {
      Some(expected_algorithm) => Some(run_counted(expected_algorithm, input))
      None => None
    },
    actual_trace,
    expected_trace,
    diagnosis,
  })
}

///|
/// Renders the counterexample and its diagnosis as Markdown.
pub fn SequenceCounterexample::report(self : SequenceCounterexample) -> String {
  let out = StringBuilder()
  out.write_string("## Counterexample\n\n")
  out.write_string(
    "Found after \{count_label(self.cases_tried, "case")} (seed \{self.seed}) and shrunk from \{format_values(self.original_input)} to \{format_values(self.input)} in \{count_label(self.shrink_steps, "step")}.\n\n",
  )
  out.write_string("- Input: \{format_values(self.input)}\n")
  out.write_string("- Actual output: \{format_values(self.actual_output)}\n")
  match self.expected_output {
    Some(expected) =>
      out.write_string("- Reference output: \{format_values(expected)}\n")
    None => ()
  }
  out.write_string("- Failure: \{self.reason}\n")
  // A divergence exists only when a reference trace was recorded.
  match (self.diagnosis.divergence, self.expected_trace) {
    (Some(divergence), Some(expected)) =>
      out.write_string(
        "- First divergence: step \{divergence.step}, expected \{step_label(expected, divergence.step)}, actual \{step_label(self.actual_trace, divergence.step)}\n",
      )
    _ => ()
  }
  match self.diagnosis.contract_report.first_failure {
    Some(violation) =>
      out.write_string(
        "- Contract \{self.diagnosis.contract_report.contract_name}: \{violation.code} at step \{violation.step}: \{violation.message}\n",
      )
    None =>
      out.write_string(
        "- Contract \{self.diagnosis.contract_report.contract_name}: PASS\n",
      )
  }
  if self.diagnosis.focus_step >= 0 &&
    self.diagnosis.focus_step < self.actual_trace.steps.length() {
    let step = self.actual_trace.steps[self.diagnosis.focus_step]
    let note = step.annotation
      .map(fn(value) { " (\{value.body})" })
      .unwrap_or("")
    out.write_string(
      "- Focus step \{self.diagnosis.focus_step}: \{debugger_event_name(step.event)}\{note}\n",
    )
  }
  out.to_string()
}

///|
fn format_values(values : Array[Int32]) -> String {
  "[\{values.map(fn(value) { value.to_string() }).join(", ")}]"
}

///|
/// The event at `step` with its targets, such as `swap(item-0, item-1)`.
fn step_label(trace : AlgorithmTrace, step : Int32) -> String {
  if step < 0 || step >= trace.steps.length() {
    return "end of trace"
  }
  let event = trace.steps[step].event
  let targets = debugger_event_targets(event).map(fn(target) {
    target.entity_id.unwrap_or(target.object_id)
  })
  if targets.is_empty() {
    debugger_event_name(event)
  } else {
    "\{debugger_event_name(event)}(\{targets.join(", ")})"
  }
}

///|
fn count_label(count : Int32, noun : String) -> String {
  if count == 1 {
    "1 \{noun}"
  } else {
    "\{count} \{noun}s"
  }
}
