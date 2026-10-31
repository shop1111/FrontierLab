///|
fn expect_invalid_red_black_tree(
  nodes : Array[RedBlackNode],
  root : Int32,
) -> Unit raise {
  try validate_red_black_tree(nodes, root) catch {
    InvalidStep(_) => ()
    _ => fail("expected red-black-tree invariant failure")
  } noraise {
    _ => fail("expected invalid red-black tree")
  }
}

///|
fn test_red_black_node(
  key : Int32,
  color~ : RedBlackColor = Black,
  parent~ : Int32 = -1,
) -> RedBlackNode {
  RedBlackNode::new(id="n-\{key}", key~, color~, parent~)
}

///|
test "private DP capacity guard rejects invalid dimensions" {
  let options = TraceOptions::default()
  try checked_grid_cell_count(0, 1, options) catch {
    InvalidGrid(_) => ()
    _ => fail("expected invalid DP grid")
  } noraise {
    _ => fail("expected invalid DP grid failure")
  }
}

///|
test "red black rotation helpers preserve transferred subtrees" {
  let left_nodes = [
    test_red_black_node(10),
    test_red_black_node(20, parent=0),
    test_red_black_node(30, parent=1),
    test_red_black_node(25, color=Red, parent=2),
  ]
  left_nodes[0].right = 1
  left_nodes[1].right = 2
  left_nodes[2].left = 3
  assert_eq(red_black_rotate_left(left_nodes, 0, 1), 0)
  assert_eq(left_nodes[0].right, 2)
  assert_eq(left_nodes[1].right, 3)
  assert_eq(left_nodes[3].parent, 1)
  let right_nodes = [
    test_red_black_node(30),
    test_red_black_node(20, parent=0),
    test_red_black_node(10, parent=1),
    test_red_black_node(15, color=Red, parent=2),
  ]
  right_nodes[0].left = 1
  right_nodes[1].left = 2
  right_nodes[2].right = 3
  assert_eq(red_black_rotate_right(right_nodes, 0, 1), 0)
  assert_eq(right_nodes[0].left, 2)
  assert_eq(right_nodes[1].left, 3)
  assert_eq(right_nodes[3].parent, 1)
}

///|
test "red black invariant checker rejects malformed internal trees" {
  expect_invalid_red_black_tree([], 0)
  expect_invalid_red_black_tree([test_red_black_node(1)], -1)
  let parented_root = [test_red_black_node(1, parent=0)]
  expect_invalid_red_black_tree(parented_root, 0)
  let red_root = [test_red_black_node(1, color=Red)]
  expect_invalid_red_black_tree(red_root, 0)
  let disconnected = [test_red_black_node(1), test_red_black_node(2)]
  expect_invalid_red_black_tree(disconnected, 0)
  let cycle = [test_red_black_node(1)]
  cycle[0].left = 0
  expect_invalid_red_black_tree(cycle, 0)
  let bad_parent = [test_red_black_node(10), test_red_black_node(5)]
  bad_parent[0].left = 1
  expect_invalid_red_black_tree(bad_parent, 0)
  let bad_minimum = [test_red_black_node(10), test_red_black_node(5, parent=0)]
  bad_minimum[0].right = 1
  expect_invalid_red_black_tree(bad_minimum, 0)
  let bad_maximum = [test_red_black_node(10), test_red_black_node(15, parent=0)]
  bad_maximum[0].left = 1
  expect_invalid_red_black_tree(bad_maximum, 0)
  let red_chain = [
    test_red_black_node(10),
    test_red_black_node(5, color=Red, parent=0),
    test_red_black_node(2, color=Red, parent=1),
  ]
  red_chain[0].left = 1
  red_chain[1].left = 2
  expect_invalid_red_black_tree(red_chain, 0)
  let uneven_black_height = [
    test_red_black_node(10),
    test_red_black_node(5, parent=0),
  ]
  uneven_black_height[0].left = 1
  expect_invalid_red_black_tree(uneven_black_height, 0)
}
