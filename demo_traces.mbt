///|
priv struct DemoSortItem {
  id : String
  value : Int
}

///|
/// Build the insertion-sort trace used by the bundled demo and CLI.
pub fn insertion_sort_demo_trace(values : Array[Int]) -> AlgorithmTrace raise {
  let items : Array[DemoSortItem] = values.mapi(fn(index, value) {
    { id: "item-\{index}", value }
  })
  let initial = demo_sort_scene(items, [])
  let builder = TraceBuilder::new(
    title="Insertion Sort",
    algorithm="insertion-sort",
    description="Compare and swap values while growing a sorted prefix.",
    initial_scene=initial,
  )
  for i in 1..<items.length() {
    let mut j = i
    while j > 0 && items[j - 1].value > items[j].value {
      let left = items[j - 1]
      let right = items[j]
      builder.record(
        event=Compare([
          TargetRef::entity("values", left.id),
          TargetRef::entity("values", right.id),
        ]),
        scene=demo_sort_scene(items, [
          Highlight::new(
            target=TargetRef::entity("values", left.id),
            role=Compared,
          ),
          Highlight::new(
            target=TargetRef::entity("values", right.id),
            role=Current,
          ),
        ]),
        annotation=Annotation::new(
          title="Compare",
          body="\{left.value} is greater than \{right.value}.",
          pseudocode_line=3,
        ),
      )
      items[j - 1] = right
      items[j] = left
      builder.record(
        event=Swap(
          TargetRef::entity("values", left.id),
          TargetRef::entity("values", right.id),
        ),
        scene=demo_sort_scene(items, [
          Highlight::new(
            target=TargetRef::entity("values", left.id),
            role=Changed,
          ),
          Highlight::new(
            target=TargetRef::entity("values", right.id),
            role=Changed,
          ),
        ]),
        annotation=Annotation::new(
          title="Swap",
          body="Move the insertion key one position left.",
          pseudocode_line=4,
        ),
      )
      j -= 1
    }
  }
  builder.record(
    event=Complete,
    scene=demo_sort_scene(
      items,
      items.map(fn(item) {
        Highlight::new(target=TargetRef::entity("values", item.id), role=Result)
      }),
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(key="items", value=items.length().to_string()),
  ])
}

///|
fn demo_sort_scene(
  items : Array[DemoSortItem],
  highlights : Array[Highlight],
) -> Scene raise {
  Scene::new(
    objects=[
      Sequence(
        SequenceState::new(
          id="values",
          label="Insertion sort",
          items=items.map(fn(item) {
            SequenceItem::new(id=item.id, value=item.value.to_string())
          }),
        ),
      ),
    ],
    highlights~,
  )
}

///|
/// Build the Union-Find trace used by the bundled demo and CLI.
pub fn union_find_demo_trace() -> AlgorithmTrace raise {
  let parent = [0, 1, 2, 3, 4, 5]
  let initial = demo_union_scene(parent, [])
  let builder = TraceBuilder::new(
    title="Union-Find",
    algorithm="union-find",
    description="Merge components and expose path compression.",
    initial_scene=initial,
  )
  for pair in [(0, 1), (2, 3), (1, 3), (4, 5), (3, 5)] {
    let (left, right) = pair
    let left_root = demo_find_root(parent, left)
    let right_root = demo_find_root(parent, right)
    builder.record(
      event=Compare([
        TargetRef::entity("components", "node-\{left}"),
        TargetRef::entity("components", "node-\{right}"),
      ]),
      scene=demo_union_scene(parent, [
        Highlight::new(
          target=TargetRef::entity("components", "node-\{left}"),
          role=Compared,
        ),
        Highlight::new(
          target=TargetRef::entity("components", "node-\{right}"),
          role=Compared,
        ),
      ]),
      annotation=Annotation::new(
        title="Find roots",
        body="Compare roots \{left_root} and \{right_root}.",
      ),
    )
    if left_root != right_root {
      parent[right_root] = left_root
      builder.record(
        event=Union(
          TargetRef::entity("components", "node-\{left_root}"),
          TargetRef::entity("components", "node-\{right_root}"),
        ),
        scene=demo_union_scene(parent, [
          Highlight::new(
            target=TargetRef::entity("components", "group-\{left_root}"),
            role=Changed,
          ),
        ]),
        annotation=Annotation::new(
          title="Union",
          body="Attach root \{right_root} below root \{left_root}.",
        ),
      )
    }
  }
  for value in 0..<parent.length() {
    let root = demo_find_root(parent, value)
    if parent[value] != root {
      parent[value] = root
      builder.record(
        event=Update(
          TargetRef::entity("components", "node-\{value}"),
          "path-compression",
        ),
        scene=demo_union_scene(parent, [
          Highlight::new(
            target=TargetRef::entity("components", "node-\{value}"),
            role=Changed,
          ),
        ]),
        annotation=Annotation::new(
          title="Path compression",
          body="Point node \{value} directly at root \{root}.",
        ),
      )
    }
  }
  builder.record(event=Complete, scene=demo_union_scene(parent, []))
  builder.finish()
}

///|
fn demo_find_root(parent : Array[Int], value : Int) -> Int {
  for current = value; parent[current] != current; {
    continue parent[current]
  } nobreak {
    current
  }
}

///|
fn demo_union_scene(
  parent : Array[Int],
  highlights : Array[Highlight],
) -> Scene raise {
  let groups : Array[SetGroup] = []
  for root in 0..<parent.length() {
    let members : Array[String] = []
    for value in 0..<parent.length() {
      if demo_find_root(parent, value) == root {
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
    objects=[
      Sets(SetState::new(id="components", label="Disjoint sets", groups~)),
    ],
    highlights~,
  )
}

///|
/// Build the A* flagship trace used by the bundled demo and CLI.
pub fn pathfinding_demo_trace() -> AlgorithmTrace raise {
  let grid = GridMap::new(width=7, height=5)
    .with_obstacle(Position::new(x=2, y=0))
    .with_obstacle(Position::new(x=2, y=1))
    .with_obstacle(Position::new(x=2, y=2))
    .with_weight(Position::new(x=4, y=3), 7)
  let start = Position::new(x=0, y=0)
  let goal = Position::new(x=6, y=4)
  let search = astar_trace(grid, start~, goal~)
  search_trace_to_algorithm_trace(
    grid,
    start~,
    goal~,
    algorithm="A*",
    trace=search,
  )
}
