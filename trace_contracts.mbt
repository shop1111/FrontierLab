///|
pub(all) enum TraceViolationSeverity {
  Warning
  Error
} derive(Debug, Eq, ToJson)

///|
pub struct TraceViolation {
  contract : String
  code : String
  severity : TraceViolationSeverity
  step : Int
  targets : Array[TargetRef]
  message : String
  evidence : Array[TraceAttribute]
} derive(Debug, Eq, ToJson)

///|
pub fn TraceViolation::new(
  contract~ : String,
  code~ : String,
  severity? : TraceViolationSeverity = Error,
  step? : Int = -1,
  targets? : Array[TargetRef] = [],
  message~ : String,
  evidence? : Array[TraceAttribute] = [],
) -> TraceViolation {
  { contract, code, severity, step, targets, message, evidence }
}

///|
pub struct ContractReport {
  report_version : String
  contract_name : String
  passed : Bool
  violations : Array[TraceViolation]
  first_failure : TraceViolation?
  counterexample : TraceCounterexample?
} derive(Debug, Eq, ToJson)

///|
pub fn ContractReport::to_json_string(self : ContractReport) -> String {
  self.to_json().stringify(indent=2)
}

///|
pub fn ContractReport::report(self : ContractReport) -> String {
  let out = StringBuilder()
  out.write_string(
    "Contract \{self.contract_name}: \{if self.passed { "PASS" } else { "FAIL" }}\n",
  )
  for violation in self.violations {
    let where_text = if violation.step < 0 {
      "trace"
    } else {
      "step \{violation.step}"
    }
    out.write_string(
      "- [\{contract_severity_name(violation.severity)}] \{violation.code} at \{where_text}: \{violation.message}\n",
    )
  }
  out.to_string()
}

///|
pub fn ContractReport::to_markdown(self : ContractReport) -> String {
  let out = StringBuilder()
  out.write_string("# FrontierLab contract report\n\n")
  out.write_string("- Contract: \{self.contract_name}\n")
  out.write_string("- Passed: \{self.passed}\n")
  out.write_string("- Violations: \{self.violations.length()}\n\n")
  out.write_string("| Severity | Code | Step | Message |\n")
  out.write_string("|---|---|---:|---|\n")
  for violation in self.violations {
    out.write_string(
      "| \{contract_severity_name(violation.severity)} | \{contract_escape(violation.code)} | \{violation.step} | \{contract_escape(violation.message)} |\n",
    )
  }
  out.to_string()
}

///|
/// An extensible semantic contract backed by a pure MoonBit checker callback.
pub struct TraceContract {
  name : String
  description : String
  checker : (AlgorithmTrace) -> Array[TraceViolation]
}

///|
pub fn TraceContract::new(
  name~ : String,
  description~ : String,
  checker~ : (AlgorithmTrace) -> Array[TraceViolation],
) -> TraceContract {
  { name, description, checker }
}

///|
pub fn TraceContract::check(
  self : TraceContract,
  trace : AlgorithmTrace,
) -> ContractReport {
  let violations = (self.checker)(trace)
  let first_failure = violations.search_by(fn(value) { value.severity is Error })
  let first = match first_failure {
    Some(index) => Some(violations[index])
    None => None
  }
  let counterexample = match first {
    Some(violation) if violation.step >= 0 =>
      Some(try! trace.slice(center=violation.step))
    _ => None
  }
  {
    report_version: debug_report_version,
    contract_name: self.name,
    passed: first is None,
    violations,
    first_failure: first,
    counterexample,
  }
}

///|
pub fn sequence_transition_contract(object_id~ : String) -> TraceContract {
  TraceContract::new(
    name="sequence-transition",
    description="Stable sequence identity and event transition semantics.",
    checker=fn(trace) { check_sequence_transitions(trace, object_id) },
  )
}

///|
pub fn insertion_sort_int_contract(object_id~ : String) -> TraceContract {
  TraceContract::new(
    name="insertion-sort-int",
    description="Sequence transitions plus a nondecreasing integer result.",
    checker=fn(trace) {
      let violations = check_sequence_transitions(trace, object_id)
      check_integer_sort_result(
        trace, object_id, "insertion-sort-int", violations,
      )
      violations
    },
  )
}

///|
/// Check stable sequence transitions and a nondecreasing integer result.
///
/// Unlike `insertion_sort_int_contract`, this name is algorithm-neutral and
/// is suitable for selection sort, merge sort, agent-generated traces, and
/// other sorting implementations.
pub fn sorted_int_sequence_contract(object_id~ : String) -> TraceContract {
  TraceContract::new(
    name="sorted-int-sequence",
    description="Stable sequence transitions plus a nondecreasing integer result.",
    checker=fn(trace) {
      let violations = check_sequence_transitions(trace, object_id)
      check_integer_sort_result(
        trace, object_id, "sorted-int-sequence", violations,
      )
      violations
    },
  )
}

///|
pub fn grid_path_contract(object_id~ : String) -> TraceContract {
  TraceContract::new(
    name="grid-path",
    description="A continuous, walkable start-to-end result path.",
    checker=fn(trace) { check_grid_path(trace, object_id) },
  )
}

///|
fn check_sequence_transitions(
  trace : AlgorithmTrace,
  object_id : String,
) -> Array[TraceViolation] {
  let violations : Array[TraceViolation] = []
  let mut previous = contract_sequence(trace.initial_scene, object_id)
  if previous is None {
    violations.push(
      TraceViolation::new(
        contract="sequence-transition",
        code="missing-sequence",
        message="Initial scene has no sequence object named \{object_id}.",
        targets=[TargetRef::object(object_id)],
      ),
    )
    return violations
  }
  for step in trace.steps {
    let current = contract_sequence(step.scene, object_id)
    match (previous, current) {
      (Some(before), Some(after)) => {
        check_sequence_identity(
          before,
          after,
          step.index,
          object_id,
          violations,
        )
        match step.event {
          Compare(_) =>
            if contract_sequence_ids(before) != contract_sequence_ids(after) {
              violations.push(
                TraceViolation::new(
                  contract="sequence-transition",
                  code="compare-mutated-order",
                  step=step.index,
                  message="Compare changed sequence order.",
                  targets=[TargetRef::object(object_id)],
                ),
              )
            }
          Swap(left, right) if left.object_id == object_id &&
            right.object_id == object_id =>
            check_swap_transition(
              before,
              after,
              left,
              right,
              step.index,
              violations,
            )
          _ => ()
        }
      }
      (_, None) =>
        violations.push(
          TraceViolation::new(
            contract="sequence-transition",
            code="sequence-disappeared",
            step=step.index,
            message="Sequence \{object_id} disappeared from the scene.",
            targets=[TargetRef::object(object_id)],
          ),
        )
      _ => ()
    }
    previous = current
  }
  violations
}

///|
fn check_sequence_identity(
  before : SequenceState,
  after : SequenceState,
  step : Int,
  object_id : String,
  violations : Array[TraceViolation],
) -> Unit {
  for item in before.items {
    match after.items.search_by(fn(value) { value.id == item.id }) {
      Some(index) =>
        if after.items[index].value != item.value {
          violations.push(
            TraceViolation::new(
              contract="sequence-transition",
              code="stable-value-changed",
              step~,
              targets=[TargetRef::entity(object_id, item.id)],
              message="Stable entity \{item.id} changed value.",
              evidence=[
                TraceAttribute::new(key="before", value=item.value),
                TraceAttribute::new(key="after", value=after.items[index].value),
              ],
            ),
          )
        }
      None =>
        violations.push(
          TraceViolation::new(
            contract="sequence-transition",
            code="stable-entity-removed",
            step~,
            targets=[TargetRef::entity(object_id, item.id)],
            message="Stable entity \{item.id} was removed.",
          ),
        )
    }
  }
  for item in after.items {
    if !before.items.any(fn(value) { value.id == item.id }) {
      violations.push(
        TraceViolation::new(
          contract="sequence-transition",
          code="stable-entity-added",
          step~,
          targets=[TargetRef::entity(object_id, item.id)],
          message="Unexpected stable entity \{item.id} was added.",
        ),
      )
    }
  }
}

///|
fn check_swap_transition(
  before : SequenceState,
  after : SequenceState,
  left : TargetRef,
  right : TargetRef,
  step : Int,
  violations : Array[TraceViolation],
) -> Unit {
  match (left.entity_id, right.entity_id) {
    (Some(left_id), Some(right_id)) => {
      let expected = contract_sequence_ids(before)
      let left_index = expected.search_by(fn(id) { id == left_id })
      let right_index = expected.search_by(fn(id) { id == right_id })
      match (left_index, right_index) {
        (Some(a), Some(b)) => {
          let temporary = expected[a]
          expected[a] = expected[b]
          expected[b] = temporary
          if expected != contract_sequence_ids(after) {
            violations.push(
              TraceViolation::new(
                contract="sequence-transition",
                code="invalid-swap-transition",
                step~,
                targets=[left, right],
                message="Swap changed more than the two declared entities or did not swap them.",
                evidence=[
                  TraceAttribute::new(
                    key="expected_ids",
                    value=expected.join(","),
                  ),
                  TraceAttribute::new(
                    key="actual_ids",
                    value=contract_sequence_ids(after).join(","),
                  ),
                ],
              ),
            )
          }
        }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
fn check_integer_sort_result(
  trace : AlgorithmTrace,
  object_id : String,
  contract_name : String,
  violations : Array[TraceViolation],
) -> Unit {
  let final_scene = if trace.steps.is_empty() {
    trace.initial_scene
  } else {
    trace.steps.last().unwrap().scene
  }
  match contract_sequence(final_scene, object_id) {
    Some(sequence) =>
      for index in 1..<sequence.items.length() {
        let left = @strconv.parse_int(sequence.items[index - 1].value) catch {
          _ => {
            violations.push(
              TraceViolation::new(
                contract=contract_name,
                code="non-integer-value",
                step=trace.steps.length() - 1,
                targets=[
                  TargetRef::entity(object_id, sequence.items[index - 1].id),
                ],
                message="Sequence value is not an integer.",
              ),
            )
            0
          }
        }
        let right = @strconv.parse_int(sequence.items[index].value) catch {
          _ => {
            violations.push(
              TraceViolation::new(
                contract=contract_name,
                code="non-integer-value",
                step=trace.steps.length() - 1,
                targets=[TargetRef::entity(object_id, sequence.items[index].id)],
                message="Sequence value is not an integer.",
              ),
            )
            0
          }
        }
        if left > right {
          violations.push(
            TraceViolation::new(
              contract=contract_name,
              code="result-not-sorted",
              step=trace.steps.length() - 1,
              targets=[
                TargetRef::entity(object_id, sequence.items[index - 1].id),
                TargetRef::entity(object_id, sequence.items[index].id),
              ],
              message="Final sequence contains inversion \{left} > \{right}.",
            ),
          )
          return
        }
      }
    None => ()
  }
}

///|
fn check_grid_path(
  trace : AlgorithmTrace,
  object_id : String,
) -> Array[TraceViolation] {
  let violations : Array[TraceViolation] = []
  let final_scene = if trace.steps.is_empty() {
    trace.initial_scene
  } else {
    trace.steps.last().unwrap().scene
  }
  match contract_grid(final_scene, object_id) {
    None =>
      violations.push(
        TraceViolation::new(
          contract="grid-path",
          code="missing-grid",
          targets=[TargetRef::object(object_id)],
          message="Final scene has no grid object named \{object_id}.",
        ),
      )
    Some(grid) => {
      let result_targets = final_scene.highlights.filter_map(fn(highlight) {
        if highlight.role is Result && highlight.target.object_id == object_id {
          highlight.target.entity_id
        } else {
          None
        }
      })
      let result_cells : Array[GridCellState] = []
      for id in result_targets {
        match grid.cells.search_by(fn(cell) { cell.id == id }) {
          Some(index) => {
            let cell = grid.cells[index]
            if cell.blocked {
              violations.push(
                TraceViolation::new(
                  contract="grid-path",
                  code="path-crosses-blocked-cell",
                  step=trace.steps.length() - 1,
                  targets=[TargetRef::entity(object_id, id)],
                  message="Result path crosses blocked cell \{id}.",
                ),
              )
            }
            result_cells.push(cell)
          }
          None => ()
        }
      }
      for index in 1..<result_cells.length() {
        let left = result_cells[index - 1]
        let right = result_cells[index]
        let distance = (left.x - right.x).abs() + (left.y - right.y).abs()
        if distance != 1 {
          violations.push(
            TraceViolation::new(
              contract="grid-path",
              code="non-contiguous-path",
              step=trace.steps.length() - 1,
              targets=[
                TargetRef::entity(object_id, left.id),
                TargetRef::entity(object_id, right.id),
              ],
              message="Consecutive result cells are not four-way adjacent.",
            ),
          )
          return violations
        }
      }
      if !result_cells.is_empty() {
        if result_cells[0].label != "S" {
          violations.push(
            TraceViolation::new(
              contract="grid-path",
              code="path-start-mismatch",
              step=trace.steps.length() - 1,
              targets=[TargetRef::entity(object_id, result_cells[0].id)],
              message="Result path does not begin at the S cell.",
            ),
          )
        }
        if result_cells.last().unwrap().label != "E" {
          violations.push(
            TraceViolation::new(
              contract="grid-path",
              code="path-end-mismatch",
              step=trace.steps.length() - 1,
              targets=[
                TargetRef::entity(object_id, result_cells.last().unwrap().id),
              ],
              message="Result path does not end at the E cell.",
            ),
          )
        }
      }
    }
  }
  violations
}

///|
fn contract_sequence(scene : Scene, id : String) -> SequenceState? {
  match scene.objects.search_by(fn(object) { object.id() == id }) {
    Some(index) =>
      match scene.objects[index] {
        Sequence(state) => Some(state)
        _ => None
      }
    None => None
  }
}

///|
fn contract_grid(scene : Scene, id : String) -> GridState? {
  match scene.objects.search_by(fn(object) { object.id() == id }) {
    Some(index) =>
      match scene.objects[index] {
        Grid(state) => Some(state)
        _ => None
      }
    None => None
  }
}

///|
fn contract_sequence_ids(sequence : SequenceState) -> Array[String] {
  sequence.items.map(fn(item) { item.id })
}

///|
fn contract_severity_name(severity : TraceViolationSeverity) -> String {
  match severity {
    Warning => "warning"
    Error => "error"
  }
}

///|
fn contract_escape(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new="<br>")
}
