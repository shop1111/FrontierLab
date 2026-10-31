///|
/// One operation accepted by the red-black-tree trace adapter.
pub(all) enum RedBlackTreeOperation {
  Insert(Int32)
  Find(Int32)
} derive(Debug, Eq, ToJson)

///|
pub extend RedBlackTreeOperation with Debug::{to_repr}

///|
pub extend RedBlackTreeOperation with Eq::{not_equal, equal}

///|
pub extend RedBlackTreeOperation with ToJson::{to_json}

///|
/// Build a red-black-tree trace with insertion balancing and lookup paths.
pub fn red_black_tree_trace(
  operations : Array[RedBlackTreeOperation],
  title~ : String = "红黑树",
  object_id~ : String = "tree",
  label~ : String = "红黑树结构",
  options~ : TraceOptions = TraceOptions::default(),
) -> AlgorithmTrace raise TraceError {
  let mut requested_nodes = 0
  for operation in operations {
    if operation is Insert(_) {
      requested_nodes += 1
    }
  }
  if requested_nodes == 0 {
    ensure_adapter_capacity(1, operations.length() + 1, options)
  } else {
    if requested_nodes > options.max_entities_per_scene / 2 {
      raise LimitExceeded("Red-black tree exceeds the scene entity limit")
    }
    ensure_adapter_capacity(
      requested_nodes * 2,
      operations.length() + 1,
      options,
    )
  }
  let nodes : Array[RedBlackNode] = []
  let mut root = -1
  let stats = RedBlackTreeStats::new()
  let builder = TraceBuilder::new(
    title~,
    algorithm="red-black-tree",
    description="使用稳定节点 ID 展示红黑树的插入、平衡修复和查找过程。",
    initial_scene=red_black_tree_scene(nodes, object_id, label, [], Result),
    options~,
  )
  for operation in operations {
    match operation {
      Insert(key) => {
        if red_black_tree_find_index(nodes, root, key) >= 0 {
          raise InvalidStep("Duplicate red-black-tree key: \{key}")
        }
        let mut parent = -1
        let mut current = root
        while current >= 0 {
          parent = current
          current = if key < nodes[current].key {
            nodes[current].left
          } else {
            nodes[current].right
          }
        }
        let node_index = nodes.length()
        nodes.push(
          RedBlackNode::new(id="node-\{node_index}", key~, color=Red, parent~),
        )
        if parent < 0 {
          root = node_index
        } else if key < nodes[parent].key {
          nodes[parent].left = node_index
        } else {
          nodes[parent].right = node_index
        }
        stats.insertions += 1
        let insert_attributes = [
          TraceAttribute::new(key="key", value=key.to_string()),
        ]
        let insert_body = if parent < 0 {
          "将键 \{key} 作为根节点插入，初始颜色为红色。"
        } else {
          let direction = if key < nodes[parent].key { "left" } else { "right" }
          insert_attributes.push(
            TraceAttribute::new(
              key="parent",
              value=nodes[parent].key.to_string(),
            ),
          )
          insert_attributes.push(
            TraceAttribute::new(key="direction", value=direction),
          )
          if direction == "left" {
            "将键 \{key} 作为节点 \{nodes[parent].key} 的左孩子插入，初始颜色为红色。"
          } else {
            "将键 \{key} 作为节点 \{nodes[parent].key} 的右孩子插入，初始颜色为红色。"
          }
        }
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-insert",
          attributes=insert_attributes,
          highlighted=[node_index],
          role=Changed,
          title="插入红色节点",
          body=insert_body,
        )
        root = red_black_tree_fix_insert(
          builder, nodes, root, node_index, object_id, label, stats,
        )
        validate_red_black_tree(nodes, root)
      }
      Find(key) => {
        stats.searches += 1
        let mut current = root
        let mut found = -1
        while current >= 0 && found < 0 {
          stats.visits += 1
          builder.record(
            event=Visit(TargetRef::entity(object_id, nodes[current].id)),
            scene=red_black_tree_scene(
              nodes,
              object_id,
              label,
              [current],
              Current,
            ),
            annotation=Annotation::new(
              title="查找键 \{key}",
              body="将键 \{key} 与节点 \{nodes[current].key} 比较。",
            ),
          )
          if key == nodes[current].key {
            found = current
          } else if key < nodes[current].key {
            current = nodes[current].left
          } else {
            current = nodes[current].right
          }
        }
        if found >= 0 {
          stats.found += 1
          record_red_black_event(
            builder,
            nodes,
            root,
            object_id,
            label,
            kind="rb-find-hit",
            attributes=[TraceAttribute::new(key="key", value=key.to_string())],
            highlighted=[found],
            role=Result,
            title="查找命中",
            body="树中存在键 \{key}。",
          )
        } else {
          stats.missed += 1
          record_red_black_event(
            builder,
            nodes,
            root,
            object_id,
            label,
            kind="rb-find-miss",
            attributes=[TraceAttribute::new(key="key", value=key.to_string())],
            highlighted=[],
            role=Error,
            title="查找未命中",
            body="树中不存在键 \{key}。",
          )
        }
      }
    }
  }
  let all_nodes = Array::makei(nodes.length(), fn(index) { index })
  builder.record(
    event=Complete,
    scene=red_black_tree_scene(nodes, object_id, label, all_nodes, Result),
    annotation=Annotation::new(
      title="红黑树操作完成",
      body="所有插入和查找操作均已完成。",
    ),
  )
  let inorder : Array[String] = []
  red_black_tree_inorder(nodes, root, inorder)
  builder.finish(summary=[
    TraceAttribute::new(key="operations", value=operations.length().to_string()),
    TraceAttribute::new(key="insertions", value=stats.insertions.to_string()),
    TraceAttribute::new(key="searches", value=stats.searches.to_string()),
    TraceAttribute::new(key="found", value=stats.found.to_string()),
    TraceAttribute::new(key="missed", value=stats.missed.to_string()),
    TraceAttribute::new(key="visits", value=stats.visits.to_string()),
    TraceAttribute::new(key="rotations", value=stats.rotations.to_string()),
    TraceAttribute::new(key="recolors", value=stats.recolors.to_string()),
    TraceAttribute::new(key="nodes", value=nodes.length().to_string()),
    TraceAttribute::new(
      key="height",
      value=red_black_tree_height(nodes, root).to_string(),
    ),
    TraceAttribute::new(
      key="black_height",
      value=red_black_tree_black_height(nodes, root).to_string(),
    ),
    TraceAttribute::new(key="inorder", value=inorder.join(",")),
  ])
}

///|
priv enum RedBlackColor {
  Red
  Black
} derive(Eq)

///|
priv struct RedBlackNode {
  id : String
  key : Int32
  mut color : RedBlackColor
  mut parent : Int32
  mut left : Int32
  mut right : Int32
}

///|
fn RedBlackNode::new(
  id~ : String,
  key~ : Int32,
  color~ : RedBlackColor,
  parent~ : Int32,
) -> RedBlackNode {
  { id, key, color, parent, left: -1, right: -1, }
}

///|
priv struct RedBlackTreeStats {
  mut insertions : Int32
  mut searches : Int32
  mut found : Int32
  mut missed : Int32
  mut visits : Int32
  mut rotations : Int32
  mut recolors : Int32
}

///|
fn RedBlackTreeStats::new() -> RedBlackTreeStats {
  {
    insertions: 0,
    searches: 0,
    found: 0,
    missed: 0,
    visits: 0,
    rotations: 0,
    recolors: 0,
  }
}

///|
fn red_black_tree_fix_insert(
  builder : TraceBuilder,
  nodes : Array[RedBlackNode],
  initial_root : Int32,
  inserted : Int32,
  object_id : String,
  label : String,
  stats : RedBlackTreeStats,
) -> Int32 raise TraceError {
  let mut root = initial_root
  let mut current = inserted
  while current != root && red_black_color(nodes, nodes[current].parent) == Red {
    let parent = nodes[current].parent
    let grand = nodes[parent].parent
    if parent == nodes[grand].left {
      let uncle = nodes[grand].right
      if red_black_color(nodes, uncle) == Red {
        nodes[parent].color = Black
        nodes[uncle].color = Black
        nodes[grand].color = Red
        stats.recolors += 3
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-recolor",
          attributes=[
            TraceAttribute::new(
              key="grandparent",
              value=nodes[grand].key.to_string(),
            ),
          ],
          highlighted=[parent, uncle, grand],
          role=Changed,
          title="节点组重新着色",
          body="父节点和叔节点变为黑色，祖父节点变为红色。",
        )
        current = grand
      } else {
        if current == nodes[parent].right {
          current = parent
          let pivot_key = nodes[current].key
          root = red_black_rotate_left(nodes, root, current)
          stats.rotations += 1
          record_red_black_event(
            builder,
            nodes,
            root,
            object_id,
            label,
            kind="rb-rotate-left",
            attributes=[
              TraceAttribute::new(key="pivot", value=pivot_key.to_string()),
            ],
            highlighted=[current, nodes[current].parent],
            role=Changed,
            title="左旋",
            body="以节点 \{pivot_key} 为支点执行左旋。",
          )
        }
        let fixed_parent = nodes[current].parent
        let fixed_grand = nodes[fixed_parent].parent
        nodes[fixed_parent].color = Black
        nodes[fixed_grand].color = Red
        stats.recolors += 2
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-recolor",
          attributes=[
            TraceAttribute::new(
              key="parent",
              value=nodes[fixed_parent].key.to_string(),
            ),
          ],
          highlighted=[fixed_parent, fixed_grand],
          role=Changed,
          title="准备右旋",
          body="将父节点变为黑色、祖父节点变为红色。",
        )
        let pivot_key = nodes[fixed_grand].key
        root = red_black_rotate_right(nodes, root, fixed_grand)
        stats.rotations += 1
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-rotate-right",
          attributes=[
            TraceAttribute::new(key="pivot", value=pivot_key.to_string()),
          ],
          highlighted=[fixed_grand, nodes[fixed_grand].parent],
          role=Changed,
          title="右旋",
          body="以节点 \{pivot_key} 为支点执行右旋。",
        )
      }
    } else {
      let uncle = nodes[grand].left
      if red_black_color(nodes, uncle) == Red {
        nodes[parent].color = Black
        nodes[uncle].color = Black
        nodes[grand].color = Red
        stats.recolors += 3
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-recolor",
          attributes=[
            TraceAttribute::new(
              key="grandparent",
              value=nodes[grand].key.to_string(),
            ),
          ],
          highlighted=[parent, uncle, grand],
          role=Changed,
          title="节点组重新着色",
          body="父节点和叔节点变为黑色，祖父节点变为红色。",
        )
        current = grand
      } else {
        if current == nodes[parent].left {
          current = parent
          let pivot_key = nodes[current].key
          root = red_black_rotate_right(nodes, root, current)
          stats.rotations += 1
          record_red_black_event(
            builder,
            nodes,
            root,
            object_id,
            label,
            kind="rb-rotate-right",
            attributes=[
              TraceAttribute::new(key="pivot", value=pivot_key.to_string()),
            ],
            highlighted=[current, nodes[current].parent],
            role=Changed,
            title="右旋",
            body="以节点 \{pivot_key} 为支点执行右旋。",
          )
        }
        let fixed_parent = nodes[current].parent
        let fixed_grand = nodes[fixed_parent].parent
        nodes[fixed_parent].color = Black
        nodes[fixed_grand].color = Red
        stats.recolors += 2
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-recolor",
          attributes=[
            TraceAttribute::new(
              key="parent",
              value=nodes[fixed_parent].key.to_string(),
            ),
          ],
          highlighted=[fixed_parent, fixed_grand],
          role=Changed,
          title="准备左旋",
          body="将父节点变为黑色、祖父节点变为红色。",
        )
        let pivot_key = nodes[fixed_grand].key
        root = red_black_rotate_left(nodes, root, fixed_grand)
        stats.rotations += 1
        record_red_black_event(
          builder,
          nodes,
          root,
          object_id,
          label,
          kind="rb-rotate-left",
          attributes=[
            TraceAttribute::new(key="pivot", value=pivot_key.to_string()),
          ],
          highlighted=[fixed_grand, nodes[fixed_grand].parent],
          role=Changed,
          title="左旋",
          body="以节点 \{pivot_key} 为支点执行左旋。",
        )
      }
    }
  }
  if root >= 0 && nodes[root].color == Red {
    nodes[root].color = Black
    stats.recolors += 1
    record_red_black_event(
      builder,
      nodes,
      root,
      object_id,
      label,
      kind="rb-recolor",
      attributes=[
        TraceAttribute::new(key="root", value=nodes[root].key.to_string()),
      ],
      highlighted=[root],
      role=Changed,
      title="根节点染黑",
      body="红黑树的根节点必须始终为黑色。",
    )
  }
  root
}

///|
fn red_black_rotate_left(
  nodes : Array[RedBlackNode],
  initial_root : Int32,
  pivot : Int32,
) -> Int32 {
  let mut root = initial_root
  let promoted = nodes[pivot].right
  nodes[pivot].right = nodes[promoted].left
  if nodes[promoted].left >= 0 {
    nodes[nodes[promoted].left].parent = pivot
  }
  nodes[promoted].parent = nodes[pivot].parent
  if nodes[pivot].parent < 0 {
    root = promoted
  } else if pivot == nodes[nodes[pivot].parent].left {
    nodes[nodes[pivot].parent].left = promoted
  } else {
    nodes[nodes[pivot].parent].right = promoted
  }
  nodes[promoted].left = pivot
  nodes[pivot].parent = promoted
  root
}

///|
fn red_black_rotate_right(
  nodes : Array[RedBlackNode],
  initial_root : Int32,
  pivot : Int32,
) -> Int32 {
  let mut root = initial_root
  let promoted = nodes[pivot].left
  nodes[pivot].left = nodes[promoted].right
  if nodes[promoted].right >= 0 {
    nodes[nodes[promoted].right].parent = pivot
  }
  nodes[promoted].parent = nodes[pivot].parent
  if nodes[pivot].parent < 0 {
    root = promoted
  } else if pivot == nodes[nodes[pivot].parent].right {
    nodes[nodes[pivot].parent].right = promoted
  } else {
    nodes[nodes[pivot].parent].left = promoted
  }
  nodes[promoted].right = pivot
  nodes[pivot].parent = promoted
  root
}

///|
fn record_red_black_event(
  builder : TraceBuilder,
  nodes : Array[RedBlackNode],
  root : Int32,
  object_id : String,
  label : String,
  kind~ : String,
  attributes~ : Array[TraceAttribute],
  highlighted~ : Array[Int32],
  role~ : HighlightRole,
  title~ : String,
  body~ : String,
) -> Unit raise TraceError {
  ignore(root)
  builder.record(
    event=Custom(kind, attributes),
    scene=red_black_tree_scene(nodes, object_id, label, highlighted, role),
    annotation=Annotation::new(title~, body~),
  )
}

///|
fn red_black_tree_scene(
  nodes : Array[RedBlackNode],
  object_id : String,
  label : String,
  highlighted : Array[Int32],
  role : HighlightRole,
) -> Scene raise TraceError {
  let graph_nodes = nodes.map(fn(node) {
    GraphNode::new(
      id=node.id,
      label="\{node.key} [\{if node.color == Red { "R" } else { "B" }}]",
    )
  })
  let edges : Array[GraphEdge] = []
  for node in nodes {
    if node.left >= 0 {
      let child = nodes[node.left]
      edges.push(
        GraphEdge::new(
          id="edge-\{node.id}-\{child.id}",
          from=node.id,
          to=child.id,
          label="left",
          directed=true,
        ),
      )
    }
    if node.right >= 0 {
      let child = nodes[node.right]
      edges.push(
        GraphEdge::new(
          id="edge-\{node.id}-\{child.id}",
          from=node.id,
          to=child.id,
          label="right",
          directed=true,
        ),
      )
    }
  }
  Scene::new(
    objects=[
      Graph(GraphState::new(id=object_id, label~, nodes=graph_nodes, edges~)),
    ],
    highlights=highlighted.map(fn(index) {
      Highlight::new(
        target=TargetRef::entity(object_id, nodes[index].id),
        role~,
      )
    }),
  )
}

///|
fn red_black_color(nodes : Array[RedBlackNode], index : Int32) -> RedBlackColor {
  if index < 0 {
    Black
  } else {
    nodes[index].color
  }
}

///|
fn red_black_tree_find_index(
  nodes : Array[RedBlackNode],
  root : Int32,
  key : Int32,
) -> Int32 {
  for current = root; current >= 0; {
    if key == nodes[current].key {
      break current
    } else if key < nodes[current].key {
      continue nodes[current].left
    } else {
      continue nodes[current].right
    }
  } nobreak {
    -1
  }
}

///|
fn validate_red_black_tree(
  nodes : Array[RedBlackNode],
  root : Int32,
) -> Unit raise TraceError {
  if nodes.is_empty() {
    if root != -1 {
      raise InvalidStep("Empty red-black tree has a root")
    }
    return
  }
  if root < 0 || root >= nodes.length() {
    raise InvalidStep("Red-black-tree root is invalid")
  }
  if nodes[root].parent != -1 {
    raise InvalidStep("Red-black-tree root must not have a parent")
  }
  if nodes[root].color != Black {
    raise InvalidStep("Red-black-tree root must be black")
  }
  let seen = Array::make(nodes.length(), false)
  ignore(validate_red_black_subtree(nodes, root, -1, None, None, seen))
  if seen.any(fn(value) { !value }) {
    raise InvalidStep("Red-black tree contains a disconnected node")
  }
}

///|
fn validate_red_black_subtree(
  nodes : Array[RedBlackNode],
  index : Int32,
  parent : Int32,
  minimum : Int32?,
  maximum : Int32?,
  seen : Array[Bool],
) -> Int32 raise TraceError {
  if index < 0 {
    return 1
  }
  if index >= nodes.length() || seen[index] {
    raise InvalidStep("Red-black tree contains a cycle or invalid child")
  }
  seen[index] = true
  let node = nodes[index]
  if node.parent != parent {
    raise InvalidStep("Red-black-tree parent link is inconsistent")
  }
  match minimum {
    Some(bound) if node.key <= bound =>
      raise InvalidStep("Red-black tree violates BST ordering")
    _ => ()
  }
  match maximum {
    Some(bound) if node.key >= bound =>
      raise InvalidStep("Red-black tree violates BST ordering")
    _ => ()
  }
  if node.color == Red &&
    (
      red_black_color(nodes, node.left) == Red ||
      red_black_color(nodes, node.right) == Red
    ) {
    raise InvalidStep("Red node has a red child")
  }
  let left_black_height = validate_red_black_subtree(
    nodes,
    node.left,
    index,
    minimum,
    Some(node.key),
    seen,
  )
  let right_black_height = validate_red_black_subtree(
    nodes,
    node.right,
    index,
    Some(node.key),
    maximum,
    seen,
  )
  if left_black_height != right_black_height {
    raise InvalidStep("Red-black tree has inconsistent black height")
  }
  left_black_height + (if node.color == Black { 1 } else { 0 })
}

///|
fn red_black_tree_height(nodes : Array[RedBlackNode], root : Int32) -> Int32 {
  if root < 0 {
    0
  } else {
    1 +
    red_black_tree_height(nodes, nodes[root].left).max(
      red_black_tree_height(nodes, nodes[root].right),
    )
  }
}

///|
fn red_black_tree_black_height(
  nodes : Array[RedBlackNode],
  root : Int32,
) -> Int32 {
  if root < 0 {
    0
  } else {
    (if nodes[root].color == Black { 1 } else { 0 }) +
    red_black_tree_black_height(nodes, nodes[root].left)
  }
}

///|
fn red_black_tree_inorder(
  nodes : Array[RedBlackNode],
  root : Int32,
  values : Array[String],
) -> Unit {
  if root >= 0 {
    red_black_tree_inorder(nodes, nodes[root].left, values)
    values.push(nodes[root].key.to_string())
    red_black_tree_inorder(nodes, nodes[root].right, values)
  }
}
