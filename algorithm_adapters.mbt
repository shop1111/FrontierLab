///|
/// One stable value in a sortable sequence trace.
pub struct SortTraceItem {
  id : String
  value : Int
  label : String
} derive(Debug, Eq, ToJson)

///|
pub fn SortTraceItem::new(
  id~ : String,
  value~ : Int,
  label? : String = "",
) -> SortTraceItem {
  { id, value, label: if label == "" { value.to_string() } else { label } }
}

///|
/// One union operation for the Union-Find trace adapter.
pub struct UnionOperation {
  left : Int
  right : Int
  label : String
} derive(Debug, Eq, ToJson)

///|
pub fn UnionOperation::new(
  left~ : Int,
  right~ : Int,
  label? : String = "",
) -> UnionOperation {
  { left, right, label: if label == "" { "\{left}-\{right}" } else { label } }
}

///|
/// Build a reusable insertion-sort trace from plain integer values.
pub fn insertion_sort_trace(
  values : Array[Int],
  title? : String = "Insertion Sort",
  object_id? : String = "values",
  label? : String = "Insertion sort",
) -> AlgorithmTrace raise TraceError {
  insertion_sort_items_trace(
    values.mapi(fn(index, value) {
      SortTraceItem::new(id="item-\{index}", value~)
    }),
    title~,
    object_id~,
    label~,
  )
}

///|
/// Build an insertion-sort trace while preserving caller-provided stable item
/// ids. Stable ids make animated swaps and external annotations deterministic.
pub fn insertion_sort_items_trace(
  items : Array[SortTraceItem],
  title? : String = "Insertion Sort",
  object_id? : String = "values",
  label? : String = "Insertion sort",
) -> AlgorithmTrace raise TraceError {
  ensure_unique_sort_items(items)
  let working = items.copy()
  let initial = sort_scene(working, object_id, label, [])
  let builder = TraceBuilder::new(
    title~,
    algorithm="insertion-sort",
    description="Compare and swap values while growing a sorted prefix.",
    initial_scene=initial,
  )
  let mut comparisons = 0
  let mut swaps = 0
  for i in 1..<working.length() {
    let mut j = i
    while j > 0 {
      let left = working[j - 1]
      let right = working[j]
      comparisons += 1
      builder.record(
        event=Compare([
          TargetRef::entity(object_id, left.id),
          TargetRef::entity(object_id, right.id),
        ]),
        scene=sort_scene(working, object_id, label, [
          Highlight::new(
            target=TargetRef::entity(object_id, left.id),
            role=Compared,
          ),
          Highlight::new(
            target=TargetRef::entity(object_id, right.id),
            role=Current,
          ),
        ]),
        annotation=Annotation::new(
          title="Compare",
          body="Compare \{left.label} and \{right.label}.",
          pseudocode_line=3,
        ),
      )
      if left.value <= right.value {
        j = 0
      } else {
        working[j - 1] = right
        working[j] = left
        swaps += 1
        builder.record(
          event=Swap(
            TargetRef::entity(object_id, left.id),
            TargetRef::entity(object_id, right.id),
          ),
          scene=sort_scene(working, object_id, label, [
            Highlight::new(
              target=TargetRef::entity(object_id, left.id),
              role=Changed,
            ),
            Highlight::new(
              target=TargetRef::entity(object_id, right.id),
              role=Changed,
            ),
          ]),
          annotation=Annotation::new(
            title="Swap",
            body="Move \{right.label} left and shift \{left.label} right.",
            pseudocode_line=4,
          ),
        )
        j -= 1
      }
    }
  }
  builder.record(
    event=Complete,
    scene=sort_scene(
      working,
      object_id,
      label,
      working.map(fn(item) {
        Highlight::new(
          target=TargetRef::entity(object_id, item.id),
          role=Result,
        )
      }),
    ),
    annotation=Annotation::new(
      title="Sorted",
      body="The sequence is sorted in nondecreasing order.",
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(key="items", value=working.length().to_string()),
    TraceAttribute::new(key="comparisons", value=comparisons.to_string()),
    TraceAttribute::new(key="swaps", value=swaps.to_string()),
    TraceAttribute::new(
      key="result",
      value=working.map(fn(item) { item.label }).join(","),
    ),
  ])
}

///|
/// Build a reusable Union-Find trace from a size and an ordered operation list.
pub fn union_find_trace(
  size : Int,
  operations : Array[UnionOperation],
  title? : String = "Union-Find",
  object_id? : String = "components",
  label? : String = "Disjoint sets",
  compress_paths? : Bool = true,
) -> AlgorithmTrace raise TraceError {
  if size <= 0 {
    raise LimitExceeded("Union-Find trace size must be positive")
  }
  for op in operations {
    if op.left < 0 || op.right < 0 || op.left >= size || op.right >= size {
      raise InvalidStep(
        "Union operation endpoints must be inside the set range",
      )
    }
  }
  let parent = Array::make(size, 0)
  let rank = Array::make(size, 0)
  for i in 0..<size {
    parent[i] = i
  }
  let initial = union_find_scene(parent, object_id, label, [])
  let builder = TraceBuilder::new(
    title~,
    algorithm="union-find",
    description="Merge components and optionally expose path compression.",
    initial_scene=initial,
  )
  let mut comparisons = 0
  let mut merges = 0
  let mut compressions = 0
  for op_index, op in operations {
    let left_root = union_find_root(parent, op.left)
    let right_root = union_find_root(parent, op.right)
    comparisons += 1
    builder.record(
      event=Compare([
        TargetRef::entity(object_id, "node-\{op.left}"),
        TargetRef::entity(object_id, "node-\{op.right}"),
      ]),
      scene=union_find_scene(parent, object_id, label, [
        Highlight::new(
          target=TargetRef::entity(object_id, "node-\{op.left}"),
          role=Compared,
        ),
        Highlight::new(
          target=TargetRef::entity(object_id, "node-\{op.right}"),
          role=Compared,
        ),
      ]),
      annotation=Annotation::new(
        title="Find roots",
        body="Operation \{op_index + 1}: compare roots \{left_root} and \{right_root}.",
      ),
    )
    if left_root != right_root {
      let (new_root, attached) = union_find_attach(
        parent, rank, left_root, right_root,
      )
      merges += 1
      builder.record(
        event=Union(
          TargetRef::entity(object_id, "node-\{new_root}"),
          TargetRef::entity(object_id, "node-\{attached}"),
        ),
        scene=union_find_scene(parent, object_id, label, [
          Highlight::new(
            target=TargetRef::entity(object_id, "group-\{new_root}"),
            role=Changed,
          ),
          Highlight::new(
            target=TargetRef::entity(object_id, "node-\{attached}"),
            role=Changed,
          ),
        ]),
        annotation=Annotation::new(
          title="Union",
          body="Attach root \{attached} below root \{new_root}.",
        ),
      )
    }
  }
  if compress_paths {
    for value in 0..<size {
      let root = union_find_root(parent, value)
      if parent[value] != root {
        parent[value] = root
        compressions += 1
        builder.record(
          event=Update(
            TargetRef::entity(object_id, "node-\{value}"),
            "path-compression",
          ),
          scene=union_find_scene(parent, object_id, label, [
            Highlight::new(
              target=TargetRef::entity(object_id, "node-\{value}"),
              role=Changed,
            ),
            Highlight::new(
              target=TargetRef::entity(object_id, "group-\{root}"),
              role=Result,
            ),
          ]),
          annotation=Annotation::new(
            title="Path compression",
            body="Point node \{value} directly at root \{root}.",
          ),
        )
      }
    }
  }
  builder.record(
    event=Complete,
    scene=union_find_scene(
      parent,
      object_id,
      label,
      final_union_highlights(parent, object_id),
    ),
    annotation=Annotation::new(
      title="Components ready",
      body="The final disjoint-set forest is available as a trace scene.",
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(key="nodes", value=size.to_string()),
    TraceAttribute::new(key="operations", value=operations.length().to_string()),
    TraceAttribute::new(key="comparisons", value=comparisons.to_string()),
    TraceAttribute::new(key="merges", value=merges.to_string()),
    TraceAttribute::new(key="path_compressions", value=compressions.to_string()),
    TraceAttribute::new(
      key="components",
      value=union_component_count(parent).to_string(),
    ),
  ])
}

///|
fn sort_scene(
  items : Array[SortTraceItem],
  object_id : String,
  label : String,
  highlights : Array[Highlight],
) -> Scene raise TraceError {
  Scene::new(
    objects=[
      Sequence(
        SequenceState::new(
          id=object_id,
          label~,
          items=items.map(fn(item) {
            SequenceItem::new(id=item.id, value=item.label)
          }),
        ),
      ),
    ],
    highlights~,
  )
}

///|
fn ensure_unique_sort_items(
  items : Array[SortTraceItem],
) -> Unit raise TraceError {
  for i in 0..<items.length() {
    if items[i].id == "" {
      raise DuplicateId("Sort trace item id must not be empty")
    }
    for j in (i + 1)..<items.length() {
      if items[i].id == items[j].id {
        raise DuplicateId("Duplicate sort trace item id: \{items[i].id}")
      }
    }
  }
}

///|
fn union_find_root(parent : Array[Int], value : Int) -> Int {
  for current = value; parent[current] != current; {
    continue parent[current]
  } nobreak {
    current
  }
}

///|
fn union_find_attach(
  parent : Array[Int],
  rank : Array[Int],
  left_root : Int,
  right_root : Int,
) -> (Int, Int) {
  if rank[left_root] < rank[right_root] {
    parent[left_root] = right_root
    (right_root, left_root)
  } else if rank[left_root] > rank[right_root] {
    parent[right_root] = left_root
    (left_root, right_root)
  } else {
    parent[right_root] = left_root
    rank[left_root] += 1
    (left_root, right_root)
  }
}

///|
fn union_find_scene(
  parent : Array[Int],
  object_id : String,
  label : String,
  highlights : Array[Highlight],
) -> Scene raise TraceError {
  let groups : Array[SetGroup] = []
  for root in 0..<parent.length() {
    let members : Array[String] = []
    for value in 0..<parent.length() {
      if union_find_root(parent, value) == root {
        members.push("node-\{value}")
      }
    }
    if !members.is_empty() {
      groups.push(
        SetGroup::new(id="group-\{root}", label="Set \{root}", members~),
      )
    }
  }
  Scene::new(
    objects=[Sets(SetState::new(id=object_id, label~, groups~))],
    highlights~,
  )
}

///|
fn final_union_highlights(
  parent : Array[Int],
  object_id : String,
) -> Array[Highlight] {
  let highlights : Array[Highlight] = []
  for root in 0..<parent.length() {
    if union_find_root(parent, root) == root {
      highlights.push(
        Highlight::new(
          target=TargetRef::entity(object_id, "group-\{root}"),
          role=Result,
        ),
      )
    }
  }
  highlights
}

///|
fn union_component_count(parent : Array[Int]) -> Int {
  let mut count = 0
  for value in 0..<parent.length() {
    if union_find_root(parent, value) == value {
      count += 1
    }
  }
  count
}
