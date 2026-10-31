///|
/// Plain bubble sort written against `TracedArray`; it has no tracing code.
fn traced_bubble_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
      }
    }
  }
}

///|
/// Insertion sort that shifts with indexing instead of swapping.
fn traced_shift_insertion_sort(a : @frontierlab.TracedArray[Int32]) -> Unit {
  for i in 1..<a.length() {
    let key = a[i]
    let mut j = i - 1
    while j >= 0 && a[j] > key {
      a[j + 1] = a[j]
      j -= 1
    }
    a[j + 1] = key
  }
}

///|
fn auto_summary_value(
  trace : @frontierlab.AlgorithmTrace,
  key : String,
) -> String {
  trace.summary[trace.summary.search_by(fn(item) { item.key == key }).unwrap()].value
}

///|
/// The sorted-sequence contract also checks permutation semantics (stable
/// values per id), so it applies to swap-based traces only.
fn assert_consistent_sequence_trace(
  trace : @frontierlab.AlgorithmTrace,
) -> Unit raise {
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
  let diagnosis = @frontierlab.diagnose_trace(
    trace,
    contract=@frontierlab.sorted_int_sequence_contract(object_id="values"),
  )
  assert_true(diagnosis.passed())
}

///|
test "TracedArray records an untouched bubble sort" {
  let a = @frontierlab.TracedArray::new([5, 1, 4, 2, 8], title="Bubble sort")
  traced_bubble_sort(a)
  assert_eq(a.to_array(), [1, 2, 4, 5, 8])
  let counts = a.counts()
  assert_eq(counts.compares, 10)
  assert_eq(counts.swaps, 4)
  assert_eq(counts.writes, 0)
  let trace = a.finish()
  let stats = trace.analyze()
  assert_eq(stats.event_count("compare"), 10)
  assert_eq(stats.event_count("swap"), 4)
  assert_eq(stats.event_count("complete"), 1)
  assert_eq(auto_summary_value(trace, "swaps"), "4")
  assert_consistent_sequence_trace(trace)
}

///|
test "TracedArray indexing records updates and counts reads" {
  let a = @frontierlab.TracedArray::new([3, 1, 2])
  traced_shift_insertion_sort(a)
  assert_eq(a.to_array(), [1, 2, 3])
  let counts = a.counts()
  assert_eq(counts.compares, 0)
  assert_eq(counts.writes, 4)
  assert_true(counts.reads > 0)
  let trace = a.finish()
  assert_eq(trace.analyze().event_count("update"), 4)
  let final_values = match trace.steps.last().unwrap().scene.objects[0] {
    Sequence(state) => state.items.map(fn(item) { item.value })
    _ => []
  }
  assert_eq(final_values, ["1", "2", "3"])
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
}

///|
test "TracedArray levels share counts and skip recording below Full" {
  let full = @frontierlab.TracedArray::new([9, 7, 5, 3, 1])
  let count = @frontierlab.TracedArray::new([9, 7, 5, 3, 1], level=Count)
  let off = @frontierlab.TracedArray::new([9, 7, 5, 3, 1], level=Off)
  traced_bubble_sort(full)
  traced_bubble_sort(count)
  traced_bubble_sort(off)
  assert_eq(count.to_array(), [1, 3, 5, 7, 9])
  assert_eq(off.to_array(), [1, 3, 5, 7, 9])
  assert_eq(count.counts(), full.counts())
  assert_eq(off.counts().compares, 0)
  assert_eq(off.counts().swaps, 0)
  try count.finish() catch {
    InvalidStep(message) => assert_true(message.contains("TraceLevel::Full"))
    _ => fail("expected InvalidStep")
  } noraise {
    _ => fail("Count level must not build a trace")
  }
}

///|
test "TracedArray keeps recording errors until finish" {
  let a = @frontierlab.TracedArray::new(
    [5, 4, 3, 2, 1],
    options=@frontierlab.TraceOptions::new(max_steps=3),
  )
  traced_bubble_sort(a)
  assert_eq(a.to_array(), [1, 2, 3, 4, 5])
  try a.finish() catch {
    LimitExceeded(_) => ()
    _ => fail("expected LimitExceeded")
  } noraise {
    _ => fail("step limit must surface at finish")
  }
}

///|
test "SequenceProbe infers swaps from snapshots of a plain array" {
  let values = [4, 3, 1, 2]
  let probe = @frontierlab.SequenceProbe::new(values, title="Observed sort")
  for end = values.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      probe.compare(i, i + 1)
      if values[i] > values[i + 1] {
        values.swap(i, i + 1)
        probe.observe(values)
      }
    }
  }
  probe.observe(values)
  let counts = probe.counts()
  assert_eq(counts.compares, 6)
  assert_eq(counts.swaps, 5)
  assert_eq(counts.snapshots, 6)
  let trace = probe.finish()
  assert_eq(trace.analyze().event_count("swap"), 5)
  assert_consistent_sequence_trace(trace)
}

///|
test "SequenceProbe classifies updates moves inserts and removals" {
  let probe = @frontierlab.SequenceProbe::new([1, 2, 3])
  probe.observe([1, 9, 3])
  probe.observe([9, 3, 1])
  probe.observe([0, 9, 3, 1])
  probe.observe([9, 3, 1])
  probe.observe([7, 8])
  let trace = probe.finish()
  let kinds = trace.steps.map(fn(step) {
    match step.event {
      Update(_, value) => "update:\{value}"
      Custom(kind, _) => kind
      Complete => "complete"
      _ => "other"
    }
  })
  assert_eq(kinds, ["update:9", "move", "insert", "remove", "edit", "complete"])
  assert_eq(trace.analyze().event_count("move"), 1)
}

///|
test "SequenceProbe keeps ids stable across moves" {
  let probe = @frontierlab.SequenceProbe::new(["a", "b", "c"])
  probe.observe(["c", "a", "b"])
  let trace = probe.finish()
  let ids = match trace.steps[0].scene.objects[0] {
    Sequence(state) => state.items.map(fn(item) { item.id })
    _ => []
  }
  assert_eq(ids, ["item-2", "item-0", "item-1"])
}

///|
test "SequenceProbe ignores unchanged snapshots and honours notes" {
  let probe = @frontierlab.SequenceProbe::new([2, 1])
  probe.observe([2, 1])
  probe.observe([1, 2], note="Put the smaller value first.")
  let trace = probe.finish()
  assert_eq(trace.steps.length(), 2)
  assert_eq(
    trace.steps[0].annotation.unwrap().body,
    "Put the smaller value first.",
  )
  assert_eq(probe.counts().snapshots, 2)
}

///|
test "SequenceProbe at level Off does nothing" {
  let probe = @frontierlab.SequenceProbe::new([2, 1], level=Off)
  probe.observe([1, 2])
  probe.compare(0, 1)
  assert_eq(probe.counts().snapshots, 0)
  assert_eq(probe.counts().compares, 0)
}

///|
test "TracedArray at level Off still sorts with indexed writes" {
  let a = @frontierlab.TracedArray::new([3, 1, 2], level=Off)
  traced_shift_insertion_sort(a)
  assert_eq(a.to_array(), [1, 2, 3])
  assert_eq(a.counts().writes, 0)
  assert_eq(a.counts().reads, 0)
}

///|
test "TracedArray reports an initial scene over the entity limit" {
  let a = @frontierlab.TracedArray::new(
    [3, 2, 1],
    options=@frontierlab.TraceOptions::new(max_entities_per_scene=2),
  )
  traced_bubble_sort(a)
  assert_eq(a.to_array(), [1, 2, 3])
  try a.finish() catch {
    LimitExceeded(_) => ()
    _ => fail("expected LimitExceeded")
  } noraise {
    _ => fail("entity limit must surface at finish")
  }
}

///|
test "TracedArray reports a step limit reached by the final step" {
  let a = @frontierlab.TracedArray::new(
    [2, 1],
    options=@frontierlab.TraceOptions::new(max_steps=2),
  )
  traced_bubble_sort(a)
  assert_eq(a.counts().compares + a.counts().swaps, 2)
  try a.finish() catch {
    LimitExceeded(_) => ()
    _ => fail("expected LimitExceeded")
  } noraise {
    _ => fail("the Complete step must respect the step limit")
  }
}

///|
test "SequenceProbe matches duplicate values to the nearest element" {
  let probe = @frontierlab.SequenceProbe::new([1, 2, 1, 3])
  probe.observe([3, 1, 2, 1])
  let trace = probe.finish()
  let ids = match trace.steps[0].scene.objects[0] {
    Sequence(state) => state.items.map(fn(item) { item.id })
    _ => []
  }
  assert_eq(ids, ["item-3", "item-0", "item-1", "item-2"])
  assert_true(trace.steps[0].event is Custom("move", _))
}
