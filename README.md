# FrontierLab

**A semantic time-travel debugger for MoonBit algorithms and AI-generated traces.**

[![CI](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml/badge.svg)](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-shop1111%2Ffrontierlab-7c3aed)](https://mooncakes.io/docs/shop1111/frontierlab)

[中文](#中文) · [English](#english) · [Live demo](https://shop1111.github.io/FrontierLab/) · [Playground](https://shop1111.github.io/FrontierLab/playground.html) · [GitHub](https://github.com/shop1111/FrontierLab) · [Gitlink](https://gitlink.org.cn/zhengpx/FrontierLab) · [Trace schema](docs/TRACE_SCHEMA.md)

| Insertion sort | Union-Find | A* frontier |
|---|---|---|
| ![Insertion sort trace](docs/insertion-sort.svg) | ![Union-Find trace](docs/union-find.svg) | ![A star trace](docs/pathfinding.svg) |

## 中文

FrontierLab 不是另一个算法合集，也不是通用绘图库。它为 MoonBit 算法提供统一的**语义事件 + 场景快照**协议，并在其上提供时间旅行调试：算法记录 `Compare`、`Swap`、`Visit`、`Union`、`Relax` 等事件；开发者或 AI Agent 可以设置语义断点、比较相邻场景、执行过程 contract、定位第一次分歧并导出最小反例。

### 为什么值得用

- 任意步骤随机跳转，不需要从头重放事件。
- 事件保留“为什么变化”，场景保留“应该画什么”。
- 生成的 HTML 不依赖 CDN、Node.js、服务器或浏览器插件。
- 稳定实体 ID 让元素在交换、合并和寻路过程中仍可追踪。
- `analyze()` 可在渲染前统计事件、目标引用、对象规模和完成状态。
- `diff()`、语义断点和 trace slice 可定位某个逻辑实体第一次发生异常的步骤。
- Trace Contract 检查算法过程而不只检查最终答案，JSON CLI 可直接接入 AI Agent 和 CI。
- 原有 BFS、Dijkstra、A*、ASCII/SVG API 完整保留。

### 五分钟体验

无需安装即可打开[在线 Playground](https://shop1111.github.io/FrontierLab/playground.html)，拖入或粘贴 schema-v1 JSON，完成校验、质量诊断、分析、回放和 SVG 导出。所有处理均在浏览器本地完成。

```bash
moon check --target all
moon test

# 生成可交互的单文件 HTML
moon run cmd/main -- demo insertion-sort --format html --output insertion-sort.html
moon run cmd/main -- demo union-find --format html --output union-find.html
moon run cmd/main -- demo pathfinding --format html --output pathfinding.html

# 也可以输出 SVG 或 JSON；使用 - 输出到标准输出
moon run cmd/main -- demo pathfinding --format svg --output pathfinding.svg
moon run cmd/main -- demo insertion-sort --format json --output trace.json
moon run cmd/main -- analyze trace.json
moon run cmd/main -- validate trace.json
moon run cmd/main -- render trace.json --format html --output replay.html

# 生成完全离线的 Trace Playground
moon run cmd/main -- playground --output playground.html

# 时间旅行调试与 Agent JSON 接口
moon run cmd/main -- diff trace.json --from 10 --to 11 --format json
moon run cmd/main -- breakpoints trace.json --event swap --target values/item-0 --changed-only --format json
moon run cmd/main -- verify trace.json --contract insertion-sort-int --object values --format json
moon run cmd/main -- diverge expected.json actual.json --format json
```

浏览器直接打开生成的 HTML，即可使用播放、暂停、时间轴、速度控制以及左右方向键。

### 把任意算法接入可视化

```mbt check
test {
  let initial = @frontierlab.Scene::new(objects=[
    @frontierlab.Sequence(@frontierlab.SequenceState::new(
      id="values",
      label="My algorithm",
      items=[
        @frontierlab.SequenceItem::new(id="a", value="3"),
        @frontierlab.SequenceItem::new(id="b", value="1"),
      ],
    )),
  ])
  let recorder = @frontierlab.TraceBuilder::new(
    title="Tiny trace",
    algorithm="my-algorithm",
    initial_scene=initial,
  )
  recorder.record(
    event=@frontierlab.Compare([
      @frontierlab.TargetRef::entity("values", "a"),
      @frontierlab.TargetRef::entity("values", "b"),
    ]),
    scene=initial,
    annotation=@frontierlab.Annotation::new(
      title="Compare",
      body="Compare the two stable entity ids.",
    ),
  )
  let html = @frontierlab.render_trace_html(recorder.finish())
  assert_true(html.contains("Tiny trace"))
}
```

完整接入方式见 [docs/INTEGRATION.md](docs/INTEGRATION.md)。

### 渲染前分析 trace

```mbt check
test {
  let trace = @frontierlab.insertion_sort_trace([3, 1, 2])
  let stats = trace.analyze()
  assert_eq(stats.event_count("compare"), 3)
  assert_eq(stats.event_count("swap"), 2)
  assert_true(stats.completed)
  assert_true(trace.summary_report().contains("Insertion Sort"))
}
```

### 验证 AI 生成的算法过程

```mbt check
test {
  let trace = @frontierlab.insertion_sort_trace([3, 1, 2])
  let report = @frontierlab.insertion_sort_int_contract(
    object_id="values",
  ).check(trace)
  assert_true(report.passed)
  let swaps = trace.breakpoint_hits(
    @frontierlab.TraceBreakpoint::new(event_kind="swap", changed_only=true),
  )
  assert_true(!swaps.is_empty())
}
```

### 内置能力

- `AlgorithmTrace` / `AlgorithmTraceStep`：版本化 trace 文档与不可变步骤快照。
- `TargetRef`：使用对象 ID + 可选实体 ID，消除跨对象同名实体歧义。
- `encode_json` / `decode_json` / `validate`：稳定 schema-v1 双向协议与完整验证。
- `TraceEvent`：初始化、比较、交换、访问、更新、合并、松弛、完成及自定义事件。
- `SceneObject`：`Sequence`、`Sets`、`Graph`、`Grid`。
- `Highlight` / `Annotation`：统一视觉角色、教学说明和伪代码行号。
- `render_trace_html`：自包含、响应式、支持深浅主题的交互播放器。
- `render_trace_playground`：自包含的 trace 导入、校验、分析、回放与 SVG 导出工作台。
- `TraceFrameDiff` / `TraceBreakpoint` / `TraceCounterexample`：场景差异、语义断点和最小反例。
- `TraceContract` / `ContractReport`：可扩展过程验证与机器可读诊断。
- `first_divergence`：定位参考 trace 与实际 trace 第一次事件或场景分歧。
- `render_trace_svg` / `render_trace_svg_frames`：单帧与批量确定性 SVG。
- `TraceStats` / `EventCount` / `ObjectUsage` / `TargetUsage`：事件统计、对象规模和目标引用分析。
- `insertion_sort_trace` / `union_find_trace`：可复用算法适配器，不只是内置 demo。
- `search_trace_to_algorithm_trace`：原有路径搜索 trace 的兼容适配器。

### 旗舰示例

```bash
moon run examples/insertion_sort > insertion-sort.html
moon run examples/union_find > union-find.html
moon run examples/pathfinding_trace > pathfinding.html

# 原有教学示例仍可运行
moon run examples/maze_bfs
moon run examples/weighted_astar
moon run examples/compare
```

### 与相邻项目的区别

- 绘图库解决“如何画”；FrontierLab 定义“算法过程如何记录和解释”。
- 图算法库解决“如何计算”；FrontierLab 不要求算法属于图领域。
- 性能 tracing 记录耗时和调用区间；FrontierLab 记录 compare、swap、union、relax 等教学语义。
- 可视化页面只是消费者；`AlgorithmTrace` JSON 可继续接入课程、IDE、评测平台或视频生成工具。

## English

FrontierLab records algorithm semantics and complete visual scenes in MoonBit. An algorithm emits events such as `Compare`, `Swap`, `Union`, or `Relax` and snapshots a sequence, set, graph, or grid. The same trace can then become an offline interactive HTML player, deterministic SVG frames, or portable JSON.

The original pathfinding APIs remain compatible. BFS, Dijkstra, and A* now serve as a flagship adapter alongside insertion sort and Union-Find.

### Public API map

- Build: `TraceBuilder::new`, `record`, `finish`
- Model: `AlgorithmTrace`, `TraceEvent`, `Scene`, `SceneObject`
- Visual state: `SequenceState`, `SetState`, `GraphState`, `GridState`
- Explain: `Highlight`, `HighlightRole`, `Annotation`
- Export: `render_trace_html`, `render_trace_svg`, `render_trace_svg_frames`
- Playground: `render_trace_playground`
- Debug: `AlgorithmTrace::diff`, `breakpoint_hits`, `slice`, `first_divergence`
- Verify: `TraceContract::check`, `sequence_transition_contract`, `insertion_sort_int_contract`, `grid_path_contract`
- Analyze: `AlgorithmTrace::analyze`, `summary_report`, `event_counts`, `target_usage`
- Adapt: `insertion_sort_trace`, `union_find_trace`, `search_trace_to_algorithm_trace`

### Development and release readiness

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
git diff --exit-code
moon test --target all --deny-warn
```

`moon fmt --deny-warn` and `moon info --deny-warn` are not valid MoonBit commands in the current documented toolchain. CI therefore uses `moon fmt --check` and `moon info && git diff --exit-code` as the reviewable equivalents.

The repository includes CI, generated interfaces, executable examples, an offline trace playground, a Pages deployment workflow, schema fixtures, an MIT license, contribution guidance, and mooncakes publishing metadata.

## Documentation

- [Trace schema and compatibility](docs/TRACE_SCHEMA.md)
- [Integrating a third-party algorithm](docs/INTEGRATION.md)
- [Rendering and security model](docs/RENDERING.md)
- [Reproducible benchmarks](BENCHMARKS.md)
- [Three-minute acceptance guide](ACCEPTANCE.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

MIT
