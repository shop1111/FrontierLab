///|
fn wire_object(entries : Array[(String, Json)]) -> Json {
  Json::object(Map(entries))
}

///|
fn wire_array(values : Array[Json]) -> Json {
  Json::array(values)
}

///|
fn wire_int(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn encode_target(target : TargetRef) -> Json {
  let entries : Array[(String, Json)] = [
    ("object_id", Json::string(target.object_id)),
  ]
  match target.entity_id {
    Some(id) => entries.push(("entity_id", Json::string(id)))
    None => ()
  }
  wire_object(entries)
}

///|
fn encode_attributes(values : Array[TraceAttribute]) -> Json {
  wire_array(
    values.map(fn(item) {
      wire_object([
        ("key", Json::string(item.key)),
        ("value", Json::string(item.value)),
      ])
    }),
  )
}

///|
fn encode_event(event : TraceEvent) -> Json {
  match event {
    Initialize => wire_object([("type", Json::string("initialize"))])
    Compare(targets) =>
      wire_object([
        ("type", Json::string("compare")),
        ("targets", wire_array(targets.map(encode_target))),
      ])
    Swap(left, right) =>
      wire_object([
        ("type", Json::string("swap")),
        ("left", encode_target(left)),
        ("right", encode_target(right)),
      ])
    Visit(target) =>
      wire_object([
        ("type", Json::string("visit")),
        ("target", encode_target(target)),
      ])
    Update(target, value) =>
      wire_object([
        ("type", Json::string("update")),
        ("target", encode_target(target)),
        ("value", Json::string(value)),
      ])
    Union(left, right) =>
      wire_object([
        ("type", Json::string("union")),
        ("left", encode_target(left)),
        ("right", encode_target(right)),
      ])
    Relax(from, to, value) =>
      wire_object([
        ("type", Json::string("relax")),
        ("from", encode_target(from)),
        ("to", encode_target(to)),
        ("value", Json::string(value)),
      ])
    Complete => wire_object([("type", Json::string("complete"))])
    Custom(kind, attributes) =>
      wire_object([
        ("type", Json::string(kind)),
        ("attributes", encode_attributes(attributes)),
      ])
  }
}

///|
fn role_name(role : HighlightRole) -> String {
  match role {
    Current => "current"
    Candidate => "candidate"
    Compared => "compared"
    Changed => "changed"
    Visited => "visited"
    Frontier => "frontier"
    Result => "result"
    Error => "error"
  }
}

///|
fn encode_highlights(values : Array[Highlight]) -> Json {
  wire_array(
    values.map(fn(item) {
      wire_object([
        ("target", encode_target(item.target)),
        ("role", Json::string(role_name(item.role))),
      ])
    }),
  )
}

///|
fn encode_annotation(value : Annotation) -> Json {
  let entries : Array[(String, Json)] = [
    ("title", Json::string(value.title)),
    ("body", Json::string(value.body)),
  ]
  match value.pseudocode_line {
    Some(line) => entries.push(("pseudocode_line", wire_int(line)))
    None => ()
  }
  wire_object(entries)
}

///|
fn encode_scene_object(object : SceneObject) -> Json {
  match object {
    Sequence(value) =>
      wire_object([
        ("type", Json::string("sequence")),
        ("id", Json::string(value.id)),
        ("label", Json::string(value.label)),
        (
          "items",
          wire_array(
            value.items.map(fn(item) {
              wire_object([
                ("id", Json::string(item.id)),
                ("value", Json::string(item.value)),
              ])
            }),
          ),
        ),
      ])
    Sets(value) =>
      wire_object([
        ("type", Json::string("sets")),
        ("id", Json::string(value.id)),
        ("label", Json::string(value.label)),
        (
          "groups",
          wire_array(
            value.groups.map(fn(group) {
              wire_object([
                ("id", Json::string(group.id)),
                ("label", Json::string(group.label)),
                ("members", wire_array(group.members.map(Json::string))),
              ])
            }),
          ),
        ),
      ])
    Graph(value) =>
      wire_object([
        ("type", Json::string("graph")),
        ("id", Json::string(value.id)),
        ("label", Json::string(value.label)),
        (
          "nodes",
          wire_array(
            value.nodes.map(fn(node) {
              wire_object([
                ("id", Json::string(node.id)),
                ("label", Json::string(node.label)),
              ])
            }),
          ),
        ),
        (
          "edges",
          wire_array(
            value.edges.map(fn(edge) {
              wire_object([
                ("id", Json::string(edge.id)),
                ("from", Json::string(edge.from)),
                ("to", Json::string(edge.to)),
                ("label", Json::string(edge.label)),
                ("directed", Json::boolean(edge.directed)),
              ])
            }),
          ),
        ),
      ])
    Grid(value) =>
      wire_object([
        ("type", Json::string("grid")),
        ("id", Json::string(value.id)),
        ("label", Json::string(value.label)),
        ("width", wire_int(value.width)),
        ("height", wire_int(value.height)),
        (
          "cells",
          wire_array(
            value.cells.map(fn(cell) {
              wire_object([
                ("id", Json::string(cell.id)),
                ("x", wire_int(cell.x)),
                ("y", wire_int(cell.y)),
                ("label", Json::string(cell.label)),
                ("blocked", Json::boolean(cell.blocked)),
              ])
            }),
          ),
        ),
      ])
  }
}

///|
fn encode_scene(scene : Scene) -> Json {
  wire_object([
    ("objects", wire_array(scene.objects.map(encode_scene_object))),
    ("highlights", encode_highlights(scene.highlights)),
  ])
}

///|
fn encode_step(step : AlgorithmTraceStep) -> Json {
  let entries : Array[(String, Json)] = [
    ("index", wire_int(step.index)),
    ("event", encode_event(step.event)),
    ("scene", encode_scene(step.scene)),
  ]
  match step.annotation {
    Some(value) => entries.push(("annotation", encode_annotation(value)))
    None => ()
  }
  wire_object(entries)
}

///|
/// Encode the stable FrontierLab schema-v1 wire format.
pub fn AlgorithmTrace::encode_json(self : AlgorithmTrace) -> String {
  wire_object([
    ("format", Json::string("frontierlab-trace")),
    ("schema_version", Json::string(self.schema_version)),
    (
      "metadata",
      wire_object([
        ("title", Json::string(self.title)),
        ("algorithm", Json::string(self.algorithm)),
        ("description", Json::string(self.description)),
      ]),
    ),
    ("initial_scene", encode_scene(self.initial_scene)),
    ("steps", wire_array(self.steps.map(encode_step))),
    ("summary", encode_attributes(self.summary)),
  ]).stringify(indent=2)
}

///|
fn expect_object(
  value : Json,
  context : String,
) -> Map[String, Json] raise TraceError {
  match value {
    Object(map) => map
    _ => raise JsonSyntax("Expected object at \{context}")
  }
}

///|
fn expect_array(value : Json, context : String) -> Array[Json] raise TraceError {
  match value {
    Array(values) => values
    _ => raise JsonSyntax("Expected array at \{context}")
  }
}

///|
fn required(
  map : Map[String, Json],
  key : String,
  context : String,
) -> Json raise TraceError {
  match map.get(key) {
    Some(value) => value
    None => raise JsonSyntax("Missing \{context}.\{key}")
  }
}

///|
fn optional(map : Map[String, Json], key : String) -> Json? {
  map.get(key)
}

///|
fn expect_string(value : Json, context : String) -> String raise TraceError {
  match value {
    String(text) => text
    _ => raise JsonSyntax("Expected string at \{context}")
  }
}

///|
fn expect_int(value : Json, context : String) -> Int raise TraceError {
  match value {
    Number(number, ..) => number.to_int()
    _ => raise JsonSyntax("Expected integer at \{context}")
  }
}

///|
fn expect_bool(value : Json, context : String) -> Bool raise TraceError {
  match value {
    True => true
    False => false
    _ => raise JsonSyntax("Expected boolean at \{context}")
  }
}

///|
fn decode_target(value : Json, context : String) -> TargetRef raise TraceError {
  let map = expect_object(value, context)
  let object_id = expect_string(
    required(map, "object_id", context),
    "\{context}.object_id",
  )
  let entity_id = match optional(map, "entity_id") {
    Some(value) => Some(expect_string(value, "\{context}.entity_id"))
    None => None
  }
  { object_id, entity_id }
}

///|
fn decode_attributes(
  value : Json,
  context : String,
) -> Array[TraceAttribute] raise TraceError {
  expect_array(value, context).mapi(fn(index, value) raise TraceError {
    let at = "\{context}[\{index}]"
    let map = expect_object(value, at)
    {
      key: expect_string(required(map, "key", at), "\{at}.key"),
      value: expect_string(required(map, "value", at), "\{at}.value"),
    }
  })
}

///|
fn decode_event(value : Json, context : String) -> TraceEvent raise TraceError {
  let map = expect_object(value, context)
  let kind = expect_string(required(map, "type", context), "\{context}.type")
  match kind {
    "initialize" => Initialize
    "compare" =>
      Compare(
        expect_array(required(map, "targets", context), "\{context}.targets").mapi((
            i,
            v,
          ) => decode_target(v, "\{context}.targets[\{i}]"),
        ),
      )
    "swap" =>
      Swap(
        decode_target(required(map, "left", context), "\{context}.left"),
        decode_target(required(map, "right", context), "\{context}.right"),
      )
    "visit" =>
      Visit(
        decode_target(required(map, "target", context), "\{context}.target"),
      )
    "update" =>
      Update(
        decode_target(required(map, "target", context), "\{context}.target"),
        expect_string(required(map, "value", context), "\{context}.value"),
      )
    "union" =>
      Union(
        decode_target(required(map, "left", context), "\{context}.left"),
        decode_target(required(map, "right", context), "\{context}.right"),
      )
    "relax" =>
      Relax(
        decode_target(required(map, "from", context), "\{context}.from"),
        decode_target(required(map, "to", context), "\{context}.to"),
        expect_string(required(map, "value", context), "\{context}.value"),
      )
    "complete" => Complete
    other =>
      Custom(
        other,
        match optional(map, "attributes") {
          Some(value) => decode_attributes(value, "\{context}.attributes")
          None => []
        },
      )
  }
}

///|
fn decode_role(
  value : Json,
  context : String,
) -> HighlightRole raise TraceError {
  match expect_string(value, context) {
    "current" => Current
    "candidate" => Candidate
    "compared" => Compared
    "changed" => Changed
    "visited" => Visited
    "frontier" => Frontier
    "result" => Result
    "error" => Error
    other => raise JsonSyntax("Unknown highlight role: \{other}")
  }
}

///|
fn decode_annotation(
  value : Json,
  context : String,
) -> Annotation raise TraceError {
  let map = expect_object(value, context)
  {
    title: expect_string(required(map, "title", context), "\{context}.title"),
    body: expect_string(required(map, "body", context), "\{context}.body"),
    pseudocode_line: match optional(map, "pseudocode_line") {
      Some(v) => Some(expect_int(v, "\{context}.pseudocode_line"))
      None => None
    },
  }
}

///|
fn decode_scene_object(
  value : Json,
  context : String,
) -> SceneObject raise TraceError {
  let map = expect_object(value, context)
  let kind = expect_string(required(map, "type", context), "\{context}.type")
  let id = expect_string(required(map, "id", context), "\{context}.id")
  let label = expect_string(required(map, "label", context), "\{context}.label")
  match kind {
    "sequence" =>
      Sequence(
        SequenceState::new(
          id~,
          label~,
          items=expect_array(
            required(map, "items", context),
            "\{context}.items",
          ).mapi((i, v) => {
            let at = "\{context}.items[\{i}]"
            let m = expect_object(v, at)
            SequenceItem::new(
              id=expect_string(required(m, "id", at), "\{at}.id"),
              value=expect_string(required(m, "value", at), "\{at}.value"),
            )
          }),
        ),
      )
    "sets" =>
      Sets(
        SetState::new(
          id~,
          label~,
          groups=expect_array(
            required(map, "groups", context),
            "\{context}.groups",
          ).mapi((i, v) => {
            let at = "\{context}.groups[\{i}]"
            let m = expect_object(v, at)
            SetGroup::new(
              id=expect_string(required(m, "id", at), "\{at}.id"),
              label=expect_string(required(m, "label", at), "\{at}.label"),
              members=expect_array(required(m, "members", at), "\{at}.members").mapi((
                  j,
                  x,
                ) => expect_string(x, "\{at}.members[\{j}]"),
              ),
            )
          }),
        ),
      )
    "graph" =>
      Graph(
        GraphState::new(
          id~,
          label~,
          nodes=expect_array(
            required(map, "nodes", context),
            "\{context}.nodes",
          ).mapi((i, v) => {
            let at = "\{context}.nodes[\{i}]"
            let m = expect_object(v, at)
            GraphNode::new(
              id=expect_string(required(m, "id", at), "\{at}.id"),
              label=expect_string(required(m, "label", at), "\{at}.label"),
            )
          }),
          edges=expect_array(
            required(map, "edges", context),
            "\{context}.edges",
          ).mapi((i, v) => {
            let at = "\{context}.edges[\{i}]"
            let m = expect_object(v, at)
            GraphEdge::new(
              id=expect_string(required(m, "id", at), "\{at}.id"),
              from=expect_string(required(m, "from", at), "\{at}.from"),
              to=expect_string(required(m, "to", at), "\{at}.to"),
              label=expect_string(required(m, "label", at), "\{at}.label"),
              directed=expect_bool(
                required(m, "directed", at),
                "\{at}.directed",
              ),
            )
          }),
        ),
      )
    "grid" =>
      Grid(
        GridState::new(
          id~,
          label~,
          width=expect_int(required(map, "width", context), "\{context}.width"),
          height=expect_int(
            required(map, "height", context),
            "\{context}.height",
          ),
          cells=expect_array(
            required(map, "cells", context),
            "\{context}.cells",
          ).mapi((i, v) => {
            let at = "\{context}.cells[\{i}]"
            let m = expect_object(v, at)
            GridCellState::new(
              id=expect_string(required(m, "id", at), "\{at}.id"),
              x=expect_int(required(m, "x", at), "\{at}.x"),
              y=expect_int(required(m, "y", at), "\{at}.y"),
              label=expect_string(required(m, "label", at), "\{at}.label"),
              blocked=expect_bool(required(m, "blocked", at), "\{at}.blocked"),
            )
          }),
        ),
      )
    other => raise JsonSyntax("Unknown scene object type: \{other}")
  }
}

///|
fn decode_scene(value : Json, context : String) -> Scene raise TraceError {
  let map = expect_object(value, context)
  let objects = expect_array(
    required(map, "objects", context),
    "\{context}.objects",
  ).mapi((i, v) => decode_scene_object(v, "\{context}.objects[\{i}]"))
  let highlights = expect_array(
    required(map, "highlights", context),
    "\{context}.highlights",
  ).mapi((i, v) => {
    let at = "\{context}.highlights[\{i}]"
    let m = expect_object(v, at)
    Highlight::new(
      target=decode_target(required(m, "target", at), "\{at}.target"),
      role=decode_role(required(m, "role", at), "\{at}.role"),
    )
  })
  Scene::new(objects~, highlights~)
}

///|
/// Decode and validate the stable FrontierLab schema-v1 wire format.
pub fn AlgorithmTrace::decode_json(
  input : StringView,
  options? : TraceOptions = TraceOptions::default(),
) -> AlgorithmTrace raise TraceError {
  let json = @json.parse(input) catch {
    error => raise JsonSyntax(error.to_string())
  }
  let root = expect_object(json, "root")
  let format = expect_string(required(root, "format", "root"), "root.format")
  if format != "frontierlab-trace" {
    raise JsonSyntax("Unknown trace format: \{format}")
  }
  let schema_version = expect_string(
    required(root, "schema_version", "root"),
    "root.schema_version",
  )
  if schema_version != "1.0" {
    raise UnsupportedSchema(schema_version)
  }
  let metadata = expect_object(
    required(root, "metadata", "root"),
    "root.metadata",
  )
  let title = expect_string(
    required(metadata, "title", "metadata"),
    "metadata.title",
  )
  let algorithm = expect_string(
    required(metadata, "algorithm", "metadata"),
    "metadata.algorithm",
  )
  let description = expect_string(
    required(metadata, "description", "metadata"),
    "metadata.description",
  )
  let initial_scene = decode_scene(
    required(root, "initial_scene", "root"),
    "initial_scene",
  )
  let steps = expect_array(required(root, "steps", "root"), "steps").mapi((i, v) => {
    let at = "steps[\{i}]"
    let m = expect_object(v, at)
    {
      index: expect_int(required(m, "index", at), "\{at}.index"),
      event: decode_event(required(m, "event", at), "\{at}.event"),
      scene: decode_scene(required(m, "scene", at), "\{at}.scene"),
      annotation: match optional(m, "annotation") {
        Some(value) => Some(decode_annotation(value, "\{at}.annotation"))
        None => None
      },
    }
  })
  let summary = decode_attributes(required(root, "summary", "root"), "summary")
  let trace = {
    schema_version,
    title,
    algorithm,
    description,
    initial_scene,
    steps,
    summary,
  }
  trace.validate(options~)
  trace
}
