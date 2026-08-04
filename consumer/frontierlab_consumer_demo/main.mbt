///|
fn evidence_path(directory : String, name : String) -> String {
  "\{directory}/\{name}"
}

///|
fn write_evidence(directory : String) -> Unit raise {
  @fs.create_dir(directory)
  let expected = selection_sort_trace(false)
  let actual = selection_sort_trace(true)
  let contract = @frontierlab.insertion_sort_int_contract(object_id="values").check(
    actual,
  )
  let divergence = @frontierlab.first_divergence(expected, actual).unwrap()
  let counterexample = actual.slice(center=divergence.step)
  @fs.write_string_to_file(
    evidence_path(directory, "selection-sort-expected.json"),
    expected.encode_json(),
  )
  @fs.write_string_to_file(
    evidence_path(directory, "selection-sort-actual.json"),
    actual.encode_json(),
  )
  @fs.write_string_to_file(
    evidence_path(directory, "selection-sort-contract.json"),
    contract.to_json_string(),
  )
  @fs.write_string_to_file(
    evidence_path(directory, "selection-sort-divergence.json"),
    divergence.to_json_string(),
  )
  @fs.write_string_to_file(
    evidence_path(directory, "selection-sort-counterexample.json"),
    counterexample.trace.encode_json(),
  )
  @fs.write_string_to_file(
    evidence_path(directory, "selection-sort-actual.html"),
    @frontierlab.render_trace_html(actual),
  )
  println(
    "generated: step=\{divergence.step} expected=\{divergence.expected_event} actual=\{divergence.actual_event} contract=\{contract.passed}",
  )
}

///|
fn main raise {
  let args = @sys.get_cli_args()
  let directory = if args.length() > 1 { args[1] } else { "evidence" }
  write_evidence(directory)
}
