///|
/// An array that records what an algorithm does to it.
///
/// Write the algorithm against `TracedArray` instead of `Array`: indexing,
/// `swap`, `less`, and `compare` record `Compare`, `Swap`, and `Update` events
/// with stable element ids, so no `TraceBuilder` code is needed. Reads are
/// counted but not recorded as steps. Use `less` or `compare` instead of
/// `a[i] < a[j]`, which reads the values without recording a comparison.
pub struct TracedArray[T] {
  priv tracker : SequenceTracker
  priv values : Array[T]
}

///|
pub fn[T : Show] TracedArray::new(
  values : Array[T],
  title~ : String = "Traced array",
  algorithm~ : String = "traced-array",
  object_id~ : String = "values",
  label~ : String = "Values",
  level~ : TraceLevel = Full,
  options~ : TraceOptions = TraceOptions::default(),
) -> TracedArray[T] {
  let tracker = SequenceTracker::new(
    title~,
    algorithm~,
    description="Events recorded by TracedArray operations.",
    object_id~,
    label~,
    values=if level == Full {
      values.map(fn(value) { value.to_string() })
    } else {
      Array::make(values.length(), "")
    },
    level~,
    options~,
  )
  { tracker, values: values.copy(), }
}

///|
pub fn[T] TracedArray::length(self : TracedArray[T]) -> Int32 {
  self.values.length()
}

///|
#alias("_[_]")
pub fn[T] TracedArray::get(self : TracedArray[T], index : Int32) -> T {
  if self.tracker.level != Off {
    self.tracker.reads += 1
  }
  self.values[index]
}

///|
#alias("_[_]=_")
pub fn[T : Show] TracedArray::set(
  self : TracedArray[T],
  index : Int32,
  value : T,
) -> Unit {
  let tracker = self.tracker
  let old = self.values[index]
  self.values[index] = value
  if tracker.level == Off {
    return
  }
  tracker.writes += 1
  if tracker.level == Full {
    tracker.values[index] = value.to_string()
    tracker.record(
      Update(tracker.target(index), tracker.values[index]),
      tracker.highlight([index], Changed),
      Annotation::new(
        title="Update",
        body="Position \{index} changes from \{old} to \{value}.",
      ),
    )
  }
}

///|
/// Exchanges two positions and records a `Swap`.
pub fn[T] TracedArray::swap(
  self : TracedArray[T],
  i : Int32,
  j : Int32,
) -> Unit {
  self.values.swap(i, j)
  let tracker = self.tracker
  if tracker.level == Off {
    return
  }
  tracker.swaps += 1
  if tracker.level == Full {
    tracker.ids.swap(i, j)
    tracker.values.swap(i, j)
    tracker.record(
      Swap(tracker.target(i), tracker.target(j)),
      tracker.highlight([i, j], Changed),
      Annotation::new(
        title="Swap",
        body="Positions \{i} and \{j} exchange \{tracker.values[j]} and \{tracker.values[i]}.",
      ),
    )
  }
}

///|
/// Compares two positions like `Compare::compare` and records a `Compare`.
pub fn[T : Compare] TracedArray::compare(
  self : TracedArray[T],
  i : Int32,
  j : Int32,
) -> Int32 {
  let result = self.values[i].compare(self.values[j])
  let tracker = self.tracker
  if tracker.level == Off {
    return result
  }
  tracker.compares += 1
  if tracker.level == Full {
    let relation = if result < 0 { "<" } else if result > 0 { ">" } else { "=" }
    tracker.record(
      Compare([tracker.target(i), tracker.target(j)]),
      tracker.highlight([i, j], Compared),
      Annotation::new(
        title="Compare",
        body="Position \{i} (\{tracker.values[i]}) \{relation} position \{j} (\{tracker.values[j]}).",
      ),
    )
  }
  result
}

///|
/// Returns whether position `i` is less than position `j`, recording a `Compare`.
pub fn[T : Compare] TracedArray::less(
  self : TracedArray[T],
  i : Int32,
  j : Int32,
) -> Bool {
  self.compare(i, j) < 0
}

///|
/// Returns a copy of the current values without counting reads.
pub fn[T] TracedArray::to_array(self : TracedArray[T]) -> Array[T] {
  self.values.copy()
}

///|
pub fn[T] TracedArray::counts(self : TracedArray[T]) -> OperationCounts {
  self.tracker.counts()
}

///|
/// Completes the trace. Raises the first recording error, or `InvalidStep`
/// when the array was not created at `TraceLevel::Full`.
pub fn[T] TracedArray::finish(
  self : TracedArray[T],
) -> AlgorithmTrace raise TraceError {
  self.tracker.finish()
}
