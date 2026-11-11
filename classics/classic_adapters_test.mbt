///|
fn adapter_summary_value(
  trace : @frontierlab.AlgorithmTrace,
  key : String,
) -> String {
  trace.summary[trace.summary.search_by(fn(item) { item.key == key }).unwrap()].value
}

///|
fn assert_adapter_round_trip(trace : @frontierlab.AlgorithmTrace) -> Unit raise {
  assert_true(
    @frontierlab.AlgorithmTrace::decode_json(trace.encode_json()) == trace,
  )
}

///|
test "Fibonacci adapter records base cases recurrence and limits" {
  let zero = @classics.fibonacci_dp_trace(0)
  let one = @classics.fibonacci_dp_trace(1)
  let ten = @classics.fibonacci_dp_trace(10)
  assert_eq(adapter_summary_value(zero, "result"), "0")
  assert_eq(adapter_summary_value(one, "result"), "1")
  assert_eq(adapter_summary_value(ten, "result"), "55")
  assert_eq(ten.analyze().event_count("update"), 9)
  assert_true(ten.steps.last().unwrap().event is @frontierlab.Complete)
  assert_adapter_round_trip(ten)
  try @classics.fibonacci_dp_trace(-1) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid Fibonacci index")
  } noraise {
    _ => fail("expected negative Fibonacci failure")
  }
  try @classics.fibonacci_dp_trace(47) catch {
    @frontierlab.LimitExceeded(_) => ()
    _ => fail("expected safe-range Fibonacci limit")
  } noraise {
    _ => fail("expected oversized Fibonacci failure")
  }
}

///|
test "coin change adapter records optimum unreachable and invalid input" {
  let optimum = @classics.coin_change_dp_trace([1, 3, 4], 6)
  assert_eq(adapter_summary_value(optimum, "reachable"), "true")
  assert_eq(adapter_summary_value(optimum, "minimum_coins"), "2")
  assert_eq(optimum.analyze().event_count("update"), 6)
  assert_adapter_round_trip(optimum)
  let missing = @classics.coin_change_dp_trace([2], 3)
  assert_eq(adapter_summary_value(missing, "reachable"), "false")
  assert_eq(adapter_summary_value(missing, "minimum_coins"), "unreachable")
  let zero = @classics.coin_change_dp_trace([], 0)
  assert_eq(adapter_summary_value(zero, "minimum_coins"), "0")
  try @classics.coin_change_dp_trace([0, 1], 3) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid coin denomination")
  } noraise {
    _ => fail("expected invalid coin failure")
  }
  try @classics.coin_change_dp_trace([1], -1) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid negative amount")
  } noraise {
    _ => fail("expected negative amount failure")
  }
}

///|
test "zero one knapsack adapter records choices and validates dimensions" {
  let trace = @classics.zero_one_knapsack_dp_trace([2, 3, 4], [4, 5, 6], 5)
  assert_eq(adapter_summary_value(trace, "result"), "9")
  assert_eq(adapter_summary_value(trace, "updates"), "15")
  assert_eq(trace.analyze().event_count("update"), 15)
  let html = @frontierlab.render_trace_html(trace)
  assert_true(html.contains("0/1 背包动态规划"))
  assert_true(html.contains("背包状态表"))
  assert_true(html.contains("背包最优解"))
  assert_true(html.contains("grid-shell"))
  assert_adapter_round_trip(trace)
  let empty = @classics.zero_one_knapsack_dp_trace([], [], 0)
  assert_eq(adapter_summary_value(empty, "result"), "0")
  try @classics.zero_one_knapsack_dp_trace([1], [], 2) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected mismatched knapsack input")
  } noraise {
    _ => fail("expected mismatched knapsack failure")
  }
  try @classics.zero_one_knapsack_dp_trace([0], [1], 2) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid knapsack weight")
  } noraise {
    _ => fail("expected invalid knapsack weight failure")
  }
  try @classics.zero_one_knapsack_dp_trace([], [], -1) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid knapsack capacity")
  } noraise {
    _ => fail("expected invalid knapsack capacity failure")
  }
  try @classics.zero_one_knapsack_dp_trace([1], [-1], 2) catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected invalid knapsack value")
  } noraise {
    _ => fail("expected invalid knapsack value failure")
  }
}

///|
test "LCS adapter records table backtracking Unicode and deterministic ties" {
  let trace = @classics.lcs_dp_trace("ABCBDAB", "BDCABA")
  assert_eq(adapter_summary_value(trace, "length"), "4")
  assert_eq(adapter_summary_value(trace, "sequence"), "BCBA")
  assert_true(trace.analyze().event_count("visit") > 0)
  assert_true(@frontierlab.render_trace_html(trace).contains("LCS table"))
  assert_adapter_round_trip(trace)
  let empty = @classics.lcs_dp_trace("", "abc")
  assert_eq(adapter_summary_value(empty, "sequence"), "")
  let unicode = @classics.lcs_dp_trace("你好世界", "再见世界")
  assert_eq(adapter_summary_value(unicode, "sequence"), "世界")
  let small_scene = @frontierlab.TraceOptions::new(
    max_steps=20,
    max_entities_per_scene=2,
  )
  try @classics.lcs_dp_trace("a", "a", options=small_scene) catch {
    @frontierlab.LimitExceeded(_) => ()
    _ => fail("expected DP table entity limit")
  } noraise {
    _ => fail("expected DP table entity failure")
  }
}

///|
test "classic adapters reject configured entity and step overflows" {
  let tiny_scene = @frontierlab.TraceOptions::new(
    max_steps=20,
    max_entities_per_scene=1,
  )
  try @classics.fibonacci_dp_trace(0, options=tiny_scene) catch {
    @frontierlab.LimitExceeded(_) => ()
    _ => fail("expected sequence entity limit")
  } noraise {
    _ => fail("expected sequence entity failure")
  }
  let tiny_trace = @frontierlab.TraceOptions::new(
    max_steps=1,
    max_entities_per_scene=20,
  )
  try @classics.fibonacci_dp_trace(2, options=tiny_trace) catch {
    @frontierlab.LimitExceeded(_) => ()
    _ => fail("expected adapter step limit")
  } noraise {
    _ => fail("expected adapter step failure")
  }
  let tiny_tree = @frontierlab.TraceOptions::new(
    max_steps=20,
    max_entities_per_scene=3,
  )
  try
    @classics.red_black_tree_trace(
      [@classics.Insert(1), @classics.Insert(2)],
      options=tiny_tree,
    )
  catch {
    @frontierlab.LimitExceeded(_) => ()
    _ => fail("expected red-black-tree entity limit")
  } noraise {
    _ => fail("expected red-black-tree entity failure")
  }
}

///|
test "red black tree adapter covers single and double rotations" {
  let left_left = @classics.red_black_tree_trace([
    @classics.Insert(30),
    @classics.Insert(20),
    @classics.Insert(10),
  ])
  assert_eq(adapter_summary_value(left_left, "inorder"), "10,20,30")
  assert_eq(left_left.analyze().event_count("rb-rotate-right"), 1)
  let right_right = @classics.red_black_tree_trace([
    @classics.Insert(10),
    @classics.Insert(20),
    @classics.Insert(30),
  ])
  assert_eq(right_right.analyze().event_count("rb-rotate-left"), 1)
  let left_right = @classics.red_black_tree_trace([
    @classics.Insert(30),
    @classics.Insert(10),
    @classics.Insert(20),
  ])
  assert_eq(left_right.analyze().event_count("rb-rotate-left"), 1)
  assert_eq(left_right.analyze().event_count("rb-rotate-right"), 1)
  let right_left = @classics.red_black_tree_trace([
    @classics.Insert(10),
    @classics.Insert(30),
    @classics.Insert(20),
  ])
  assert_eq(right_left.analyze().event_count("rb-rotate-right"), 1)
  assert_eq(right_left.analyze().event_count("rb-rotate-left"), 1)
  let stress = @classics.red_black_tree_trace([
    @classics.Insert(41),
    @classics.Insert(38),
    @classics.Insert(31),
    @classics.Insert(12),
    @classics.Insert(19),
    @classics.Insert(8),
    @classics.Insert(50),
    @classics.Insert(60),
    @classics.Insert(55),
    @classics.Insert(1),
    @classics.Insert(7),
    @classics.Insert(6),
  ])
  assert_eq(
    adapter_summary_value(stress, "inorder"),
    "1,6,7,8,12,19,31,38,41,50,55,60",
  )
}

///|
test "red black tree adapter records recoloring searches rendering and errors" {
  let trace = @classics.red_black_tree_trace([
    @classics.Insert(10),
    @classics.Insert(5),
    @classics.Insert(15),
    @classics.Insert(1),
    @classics.Find(5),
    @classics.Find(99),
  ])
  let stats = trace.analyze()
  assert_true(stats.event_count("rb-recolor") > 0)
  assert_eq(stats.event_count("rb-find-hit"), 1)
  assert_eq(stats.event_count("rb-find-miss"), 1)
  assert_eq(adapter_summary_value(trace, "found"), "1")
  assert_eq(adapter_summary_value(trace, "missed"), "1")
  assert_eq(adapter_summary_value(trace, "black_height"), "2")
  let html = @frontierlab.render_trace_html(trace)
  assert_true(html.contains("红黑树结构"))
  assert_true(html.contains("节点组重新着色"))
  assert_true(html.contains("查找未命中"))
  assert_true(html.contains("作为节点 10 的左孩子"))
  assert_true(html.contains("作为节点 10 的右孩子"))
  assert_true(html.contains("\"label\":\"left\""))
  assert_true(html.contains("\"label\":\"right\""))
  assert_true(html.contains("graph-svg"))
  assert_adapter_round_trip(trace)
  let mirrored_recolor = @classics.red_black_tree_trace([
    @classics.Insert(10),
    @classics.Insert(5),
    @classics.Insert(15),
    @classics.Insert(20),
  ])
  assert_true(mirrored_recolor.analyze().event_count("rb-recolor") > 1)
  let empty = @classics.red_black_tree_trace([])
  assert_eq(adapter_summary_value(empty, "nodes"), "0")
  try
    @classics.red_black_tree_trace([@classics.Insert(4), @classics.Insert(4)])
  catch {
    @frontierlab.InvalidStep(_) => ()
    _ => fail("expected duplicate red-black-tree key")
  } noraise {
    _ => fail("expected duplicate red-black-tree failure")
  }
}
