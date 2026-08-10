///|
/// Build a Fibonacci dynamic-programming trace for `F(n)`.
pub fn fibonacci_dp_trace(
  n : Int,
  title? : String = "Fibonacci DP",
  object_id? : String = "dp",
  label? : String = "Fibonacci states",
  options? : TraceOptions = TraceOptions::default(),
) -> AlgorithmTrace raise TraceError {
  if n < 0 {
    raise InvalidStep("Fibonacci index must be nonnegative")
  }
  if n > 46 {
    raise LimitExceeded("Fibonacci index exceeds the safe Int range (0..46)")
  }
  let state_count = n + 1
  let update_count = if n < 2 { 0 } else { n - 1 }
  ensure_adapter_capacity(state_count + 1, update_count + 1, options)
  let values = Array::make(state_count, "?")
  values[0] = "0"
  if n >= 1 {
    values[1] = "1"
  }
  let builder = TraceBuilder::new(
    title~,
    algorithm="fibonacci-dp",
    description="Compute each Fibonacci state from the previous two states.",
    initial_scene=dp_sequence_scene(values, object_id, label, []),
    options~,
  )
  let numbers = Array::make(state_count, 0)
  if n >= 1 {
    numbers[1] = 1
  }
  for i in 2..<=n {
    numbers[i] = numbers[i - 1] + numbers[i - 2]
    values[i] = numbers[i].to_string()
    builder.record(
      event=Update(dp_sequence_target(object_id, i), values[i]),
      scene=dp_sequence_scene(values, object_id, label, [
        Highlight::new(
          target=dp_sequence_target(object_id, i - 2),
          role=Compared,
        ),
        Highlight::new(
          target=dp_sequence_target(object_id, i - 1),
          role=Compared,
        ),
        Highlight::new(target=dp_sequence_target(object_id, i), role=Changed),
      ]),
      annotation=Annotation::new(
        title="Compute F(\{i})",
        body="F(\{i}) = F(\{i - 1}) + F(\{i - 2}) = \{numbers[i]}.",
      ),
    )
  }
  builder.record(
    event=Complete,
    scene=dp_sequence_scene(values, object_id, label, [
      Highlight::new(target=dp_sequence_target(object_id, n), role=Result),
    ]),
    annotation=Annotation::new(
      title="Fibonacci result",
      body="F(\{n}) = \{numbers[n]}.",
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(key="n", value=n.to_string()),
    TraceAttribute::new(key="states", value=state_count.to_string()),
    TraceAttribute::new(key="updates", value=update_count.to_string()),
    TraceAttribute::new(key="result", value=numbers[n].to_string()),
  ])
}

///|
/// Build a one-dimensional minimum-coin-change dynamic-programming trace.
pub fn coin_change_dp_trace(
  coins : Array[Int],
  amount : Int,
  title? : String = "Coin Change DP",
  object_id? : String = "dp",
  label? : String = "Minimum coins",
  options? : TraceOptions = TraceOptions::default(),
) -> AlgorithmTrace raise TraceError {
  if amount < 0 {
    raise InvalidStep("Coin-change amount must be nonnegative")
  }
  for coin in coins {
    if coin <= 0 {
      raise InvalidStep("Coin denominations must be positive")
    }
  }
  let state_count = amount + 1
  ensure_adapter_capacity(state_count + 1, amount + 1, options)
  let unreachable_bound = amount + 1
  let minimum = Array::make(state_count, unreachable_bound)
  let values = Array::make(state_count, "?")
  minimum[0] = 0
  values[0] = "0"
  let builder = TraceBuilder::new(
    title~,
    algorithm="coin-change-dp",
    description="Choose the fewest coins for every amount from zero to the target.",
    initial_scene=dp_sequence_scene(values, object_id, label, []),
    options~,
  )
  for current in 1..<=amount {
    let mut best = unreachable_bound
    let mut predecessor = -1
    let mut chosen_coin = -1
    for coin in coins {
      if coin <= current && minimum[current - coin] != unreachable_bound {
        let candidate = minimum[current - coin] + 1
        if candidate < best {
          best = candidate
          predecessor = current - coin
          chosen_coin = coin
        }
      }
    }
    minimum[current] = best
    values[current] = if best == unreachable_bound {
      "∞"
    } else {
      best.to_string()
    }
    let highlights : Array[Highlight] = []
    if predecessor >= 0 {
      highlights.push(
        Highlight::new(
          target=dp_sequence_target(object_id, predecessor),
          role=Compared,
        ),
      )
    }
    highlights.push(
      Highlight::new(
        target=dp_sequence_target(object_id, current),
        role=Changed,
      ),
    )
    builder.record(
      event=Update(dp_sequence_target(object_id, current), values[current]),
      scene=dp_sequence_scene(values, object_id, label, highlights),
      annotation=Annotation::new(
        title="Amount \{current}",
        body=if chosen_coin < 0 {
          "No denomination can reach amount \{current}."
        } else {
          "Use coin \{chosen_coin}; the minimum is \{best}."
        },
      ),
    )
  }
  builder.record(
    event=Complete,
    scene=dp_sequence_scene(values, object_id, label, [
      Highlight::new(
        target=dp_sequence_target(object_id, amount),
        role=if minimum[amount] == unreachable_bound { Error } else { Result },
      ),
    ]),
    annotation=Annotation::new(
      title=if minimum[amount] == unreachable_bound {
        "Amount unreachable"
      } else {
        "Minimum found"
      },
      body=if minimum[amount] == unreachable_bound {
        "The target amount cannot be formed from the supplied denominations."
      } else {
        "The target amount needs \{minimum[amount]} coin(s)."
      },
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(key="amount", value=amount.to_string()),
    TraceAttribute::new(
      key="coins",
      value=coins.map(fn(coin) { coin.to_string() }).join(","),
    ),
    TraceAttribute::new(
      key="reachable",
      value=(minimum[amount] != unreachable_bound).to_string(),
    ),
    TraceAttribute::new(
      key="minimum_coins",
      value=if minimum[amount] == unreachable_bound {
        "unreachable"
      } else {
        minimum[amount].to_string()
      },
    ),
  ])
}

///|
/// Build a two-dimensional 0/1-knapsack dynamic-programming trace.
pub fn zero_one_knapsack_dp_trace(
  weights : Array[Int],
  values : Array[Int],
  capacity : Int,
  title? : String = "0/1 背包动态规划",
  object_id? : String = "dp",
  label? : String = "背包状态表",
  options? : TraceOptions = TraceOptions::default(),
) -> AlgorithmTrace raise TraceError {
  if weights.length() != values.length() {
    raise InvalidStep("Knapsack weights and values must have the same length")
  }
  if capacity < 0 {
    raise InvalidStep("Knapsack capacity must be nonnegative")
  }
  for weight in weights {
    if weight <= 0 {
      raise InvalidStep("Knapsack weights must be positive")
    }
  }
  for value in values {
    if value < 0 {
      raise InvalidStep("Knapsack values must be nonnegative")
    }
  }
  let rows = weights.length() + 1
  let columns = capacity + 1
  let cells = checked_grid_cell_count(columns, rows, options)
  let updates = weights.length() * capacity
  ensure_adapter_capacity(cells + 1, updates + 1, options)
  let table = Array::makei(rows, fn(_) { Array::make(columns, 0) })
  let labels = Array::makei(rows, fn(row) {
    Array::makei(columns, fn(column) {
      if row == 0 || column == 0 {
        "0"
      } else {
        "?"
      }
    })
  })
  let builder = TraceBuilder::new(
    title~,
    algorithm="zero-one-knapsack-dp",
    description="逐件考虑物品，在每个容量下比较选择与跳过。",
    initial_scene=dp_grid_scene(labels, object_id, label, []),
    options~,
  )
  for row in 1..<rows {
    let weight = weights[row - 1]
    let item_value = values[row - 1]
    for column in 1..<columns {
      let excluded = table[row - 1][column]
      let included = if weight <= column {
        table[row - 1][column - weight] + item_value
      } else {
        -1
      }
      table[row][column] = if included > excluded { included } else { excluded }
      labels[row][column] = table[row][column].to_string()
      let highlights : Array[Highlight] = [
        Highlight::new(
          target=dp_grid_target(object_id, column, row - 1),
          role=Compared,
        ),
      ]
      if weight <= column {
        highlights.push(
          Highlight::new(
            target=dp_grid_target(object_id, column - weight, row - 1),
            role=Compared,
          ),
        )
      }
      highlights.push(
        Highlight::new(
          target=dp_grid_target(object_id, column, row),
          role=Changed,
        ),
      )
      builder.record(
        event=Update(
          dp_grid_target(object_id, column, row),
          labels[row][column],
        ),
        scene=dp_grid_scene(labels, object_id, label, highlights),
        annotation=Annotation::new(
          title="第 \{row} 件物品，容量 \{column}",
          body=if included > excluded {
            "选择第 \{row} 件物品，当前最优价值更新为 \{included}。"
          } else {
            "跳过第 \{row} 件物品，当前最优价值保持为 \{excluded}。"
          },
        ),
      )
    }
  }
  let result_row = rows - 1
  builder.record(
    event=Complete,
    scene=dp_grid_scene(labels, object_id, label, [
      Highlight::new(
        target=dp_grid_target(object_id, capacity, result_row),
        role=Result,
      ),
    ]),
    annotation=Annotation::new(
      title="背包最优解",
      body="容量 \{capacity} 下的最大价值为 \{table[result_row][capacity]}。",
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(key="items", value=weights.length().to_string()),
    TraceAttribute::new(key="capacity", value=capacity.to_string()),
    TraceAttribute::new(key="states", value=cells.to_string()),
    TraceAttribute::new(key="updates", value=updates.to_string()),
    TraceAttribute::new(
      key="result",
      value=table[result_row][capacity].to_string(),
    ),
  ])
}

///|
/// Build a two-dimensional longest-common-subsequence trace.
pub fn lcs_dp_trace(
  left : String,
  right : String,
  title? : String = "Longest Common Subsequence DP",
  object_id? : String = "dp",
  label? : String = "LCS table",
  options? : TraceOptions = TraceOptions::default(),
) -> AlgorithmTrace raise TraceError {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let rows = left_chars.length() + 1
  let columns = right_chars.length() + 1
  let cells = checked_grid_cell_count(columns, rows, options)
  let updates = left_chars.length() * right_chars.length()
  let maximum_backtrack = left_chars.length() + right_chars.length()
  ensure_adapter_capacity(cells + 1, updates + maximum_backtrack + 1, options)
  let table = Array::makei(rows, fn(_) { Array::make(columns, 0) })
  let labels = Array::makei(rows, fn(row) {
    Array::makei(columns, fn(column) {
      if row == 0 || column == 0 {
        "0"
      } else {
        "?"
      }
    })
  })
  let builder = TraceBuilder::new(
    title~,
    algorithm="longest-common-subsequence-dp",
    description="Fill the LCS table, then backtrack a deterministic subsequence.",
    initial_scene=dp_grid_scene(labels, object_id, label, []),
    options~,
  )
  for row in 1..<rows {
    for column in 1..<columns {
      let matches = left_chars[row - 1] == right_chars[column - 1]
      table[row][column] = if matches {
        table[row - 1][column - 1] + 1
      } else if table[row - 1][column] >= table[row][column - 1] {
        table[row - 1][column]
      } else {
        table[row][column - 1]
      }
      labels[row][column] = table[row][column].to_string()
      let highlights : Array[Highlight] = []
      if matches {
        highlights.push(
          Highlight::new(
            target=dp_grid_target(object_id, column - 1, row - 1),
            role=Compared,
          ),
        )
      } else {
        highlights.push(
          Highlight::new(
            target=dp_grid_target(object_id, column, row - 1),
            role=Compared,
          ),
        )
        highlights.push(
          Highlight::new(
            target=dp_grid_target(object_id, column - 1, row),
            role=Compared,
          ),
        )
      }
      highlights.push(
        Highlight::new(
          target=dp_grid_target(object_id, column, row),
          role=Changed,
        ),
      )
      builder.record(
        event=Update(
          dp_grid_target(object_id, column, row),
          labels[row][column],
        ),
        scene=dp_grid_scene(labels, object_id, label, highlights),
        annotation=Annotation::new(
          title="LCS cell (\{row}, \{column})",
          body=if matches {
            "Characters match: \{left_chars[row - 1].to_string()}."
          } else {
            "Characters differ; keep the longer preceding subsequence."
          },
        ),
      )
    }
  }
  let result_chars : Array[Char] = []
  let result_cells : Array[(Int, Int)] = []
  let mut row = left_chars.length()
  let mut column = right_chars.length()
  while row > 0 && column > 0 {
    let current_row = row
    let current_column = column
    if left_chars[row - 1] == right_chars[column - 1] {
      result_chars.push(left_chars[row - 1])
      result_cells.push((column, row))
      row -= 1
      column -= 1
    } else if table[row - 1][column] >= table[row][column - 1] {
      row -= 1
    } else {
      column -= 1
    }
    let highlights = dp_result_cell_highlights(object_id, result_cells)
    highlights.push(
      Highlight::new(
        target=dp_grid_target(object_id, current_column, current_row),
        role=Current,
      ),
    )
    builder.record(
      event=Visit(dp_grid_target(object_id, current_column, current_row)),
      scene=dp_grid_scene(labels, object_id, label, highlights),
      annotation=Annotation::new(
        title="Backtrack LCS",
        body="Follow the deterministic LCS reconstruction path.",
      ),
    )
  }
  let sequence = String::from_array(result_chars.rev())
  builder.record(
    event=Complete,
    scene=dp_grid_scene(
      labels,
      object_id,
      label,
      dp_result_cell_highlights(object_id, result_cells),
    ),
    annotation=Annotation::new(
      title="LCS complete",
      body="The longest common subsequence is \{sequence}.",
    ),
  )
  builder.finish(summary=[
    TraceAttribute::new(
      key="left_length",
      value=left_chars.length().to_string(),
    ),
    TraceAttribute::new(
      key="right_length",
      value=right_chars.length().to_string(),
    ),
    TraceAttribute::new(key="updates", value=updates.to_string()),
    TraceAttribute::new(
      key="length",
      value=table[left_chars.length()][right_chars.length()].to_string(),
    ),
    TraceAttribute::new(key="sequence", value=sequence),
  ])
}

///|
fn dp_sequence_scene(
  values : Array[String],
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
          items=values.mapi(fn(index, value) {
            SequenceItem::new(id="state-\{index}", value~)
          }),
        ),
      ),
    ],
    highlights~,
  )
}

///|
fn dp_sequence_target(object_id : String, index : Int) -> TargetRef {
  TargetRef::entity(object_id, "state-\{index}")
}

///|
fn dp_grid_scene(
  labels : Array[Array[String]],
  object_id : String,
  label : String,
  highlights : Array[Highlight],
) -> Scene raise TraceError {
  let height = labels.length()
  let width = if height == 0 { 0 } else { labels[0].length() }
  let cells : Array[GridCellState] = []
  for row in 0..<height {
    for column in 0..<width {
      cells.push(
        GridCellState::new(
          id=dp_grid_cell_id(column, row),
          x=column,
          y=row,
          label=labels[row][column],
        ),
      )
    }
  }
  Scene::new(
    objects=[
      Grid(GridState::new(id=object_id, label~, width~, height~, cells~)),
    ],
    highlights~,
  )
}

///|
fn dp_grid_cell_id(column : Int, row : Int) -> String {
  "cell-\{column}-\{row}"
}

///|
fn dp_grid_target(object_id : String, column : Int, row : Int) -> TargetRef {
  TargetRef::entity(object_id, dp_grid_cell_id(column, row))
}

///|
fn dp_result_cell_highlights(
  object_id : String,
  cells : Array[(Int, Int)],
) -> Array[Highlight] {
  cells.map(fn(cell) {
    Highlight::new(
      target=dp_grid_target(object_id, cell.0, cell.1),
      role=Result,
    )
  })
}

///|
fn checked_grid_cell_count(
  width : Int,
  height : Int,
  options : TraceOptions,
) -> Int raise TraceError {
  if width <= 0 || height <= 0 {
    raise InvalidGrid("DP table dimensions must be positive")
  }
  let maximum_cells = options.max_entities_per_scene - 1
  if maximum_cells < 0 || height > maximum_cells / width {
    raise LimitExceeded("DP table exceeds the scene entity limit")
  }
  width * height
}

///|
fn ensure_adapter_capacity(
  entities : Int,
  steps : Int,
  options : TraceOptions,
) -> Unit raise TraceError {
  if entities > options.max_entities_per_scene {
    raise LimitExceeded("Adapter scene entity limit exceeded")
  }
  if steps > options.max_steps {
    raise LimitExceeded("Adapter trace step limit exceeded")
  }
}
