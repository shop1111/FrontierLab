///|
/// Convert a legacy path-search trace into the generic visualization protocol.
pub fn search_trace_to_algorithm_trace(
  grid : GridMap,
  start~ : Position,
  goal~ : Position,
  algorithm~ : String,
  trace~ : SearchTrace,
) -> AlgorithmTrace raise {
  let initial = search_scene(grid, start, goal, None, [], [], [])
  let builder = TraceBuilder::new(
    title="\{algorithm} frontier exploration",
    algorithm~,
    description="Grid search recorded through FrontierLab's generic trace protocol.",
    initial_scene=initial,
  )
  let mut previous_parent_count = 0
  for step in trace.steps {
    let event = if step.parent.length() > previous_parent_count {
      let link = step.parent[step.parent.length() - 1]
      Relax(
        position_id(link.parent),
        position_id(link.child),
        search_cost_label(step.cost, link.child),
      )
    } else {
      match step.current {
        Some(current) => Visit(position_id(current))
        None => Custom("frontier-empty", [])
      }
    }
    previous_parent_count = step.parent.length()
    let scene = search_scene(
      grid,
      start,
      goal,
      step.current,
      step.frontier,
      step.visited,
      [],
    )
    builder.record(
      event~,
      scene~,
      annotation=Annotation::new(
        title="Explore the frontier",
        body="Visited \{step.visited.length()} cells; \{step.frontier.length()} remain in the frontier.",
      ),
    )
  }
  let final_scene = search_scene(
    grid,
    start,
    goal,
    None,
    [],
    match trace.steps.last() {
      Some(step) => step.visited
      None => []
    },
    trace.result.path,
  )
  builder.record(
    event=Complete,
    scene=final_scene,
    annotation=Annotation::new(
      title=if trace.result.reachable { "Path found" } else { "No path" },
      body="Cost \{trace.result.cost}; visited \{trace.result.visited_count} cells.",
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(
      key="reachable",
      value=trace.result.reachable.to_string(),
    ),
    TraceAttribute::new(key="cost", value=trace.result.cost.to_string()),
    TraceAttribute::new(
      key="visited_count",
      value=trace.result.visited_count.to_string(),
    ),
  ])
}

///|
fn search_scene(
  grid : GridMap,
  start : Position,
  goal : Position,
  current : Position?,
  frontier : Array[Position],
  visited : Array[Position],
  path : Array[Position],
) -> Scene raise {
  let cells : Array[GridCellState] = []
  for y in 0..<grid.height {
    for x in 0..<grid.width {
      let position = Position::new(x~, y~)
      let label = if position == start {
        "S"
      } else if position == goal {
        "E"
      } else {
        let weight = grid.weight_at(position)
        if weight == 1 {
          ""
        } else {
          weight.to_string()
        }
      }
      cells.push(
        GridCellState::new(
          id=position_id(position),
          x~,
          y~,
          label~,
          blocked=grid.is_obstacle(position),
        ),
      )
    }
  }
  let highlights : Array[Highlight] = []
  match current {
    Some(position) =>
      highlights.push(
        Highlight::new(target=position_id(position), role=Current),
      )
    None => ()
  }
  for position in path {
    highlights.push(Highlight::new(target=position_id(position), role=Result))
  }
  for position in frontier {
    highlights.push(Highlight::new(target=position_id(position), role=Frontier))
  }
  for position in visited {
    highlights.push(Highlight::new(target=position_id(position), role=Visited))
  }
  Scene::new(
    objects=[
      Grid(
        GridState::new(
          id="search-grid",
          label="Grid search",
          width=grid.width,
          height=grid.height,
          cells~,
        ),
      ),
    ],
    highlights~,
  )
}

///|
fn position_id(position : Position) -> String {
  "cell-\{position.x}-\{position.y}"
}

///|
fn search_cost_label(costs : Array[CostEntry], position : Position) -> String {
  match costs.search_by(fn(entry) { entry.position == position }) {
    Some(index) => costs[index].cost.to_string()
    None => "?"
  }
}
