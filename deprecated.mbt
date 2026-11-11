///|
#deprecated("Use sorted_int_sequence_contract; this alias will be removed in v1.0.", skip_current_package=true)
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
