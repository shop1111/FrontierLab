# FrontierLab

FrontierLab 是一个 MoonBit 算法轨迹库。它把算法执行过程记录为带稳定实体 ID
的语义事件和场景快照，并提供检查、对比、调试、JSON 编解码和精修后的离线
HTML 可视化能力。

[![CI](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml/badge.svg)](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-package-7c3aed)](https://mooncakes.io/docs/shop1111/frontierlab)

[在线打开 AI Trace Clinic](https://shop1111.github.io/FrontierLab/playground.html) ·
[Mooncakes](https://mooncakes.io/docs/shop1111/frontierlab) ·
[Trace Schema v1](docs/TRACE_SCHEMA.md)

## 安装

在 MoonBit 项目中添加依赖：

```bash
moon add shop1111/frontierlab
```

然后在需要使用 FrontierLab 的包中导入 `shop1111/frontierlab`。

FrontierLab 需要 MoonBit `moonc` 0.10.16 或更新版本，CI 固定在
`0.10.18+6c83a7f62` 上验证，详见[工具链策略](TOOLCHAIN.md)。

## 最小示例

下面的例子生成一条插入排序轨迹，再检查最终序列是否有序：

```mbt nocheck
let trace = @frontierlab.insertion_sort_trace([3, 1, 2])
let result = @frontierlab.diagnose_trace(
  trace,
  contract=@frontierlab.sorted_int_sequence_contract(object_id="values"),
  expected=trace,
)
assert_true(result.passed())
```

这里的“轨迹规则”（代码类型为 `TraceContract`）是一个检查器：它检查轨迹中的
步骤或最终结果是否违反预先定义的要求，并返回具体的失败步骤和原因。
`sorted_int_sequence_contract` 检查最终整数序列是否有序；
`sequence_transition_contract` 检查事件描述的变化是否与场景快照一致。

自定义算法通常按以下顺序接入：

1. 用稳定 ID 表示元素、节点或网格单元；元素移动后 ID 不变。
2. 用 `TraceBuilder` 记录 `Compare`、`Swap`、`Visit`、`Union`、`Relax`
   等有意义的事件和对应场景。
3. 调用 `finish` 得到 `AlgorithmTrace`。
4. 将轨迹交给规则检查、差异分析、JSON 编解码或渲染 API。

可直接运行的完整代码见 [API 示例](API.mbt.md) 和[集成说明](docs/INTEGRATION.md)。

## 自动适配：不写埋点代码

对于数组类算法，不必手动调用 `TraceBuilder`。有两种自动方式：

**追踪容器 `TracedArray`**：把参数类型从 `Array` 换成 `TracedArray`，算法
正文照常写。`a.less(i, j)`、`a.compare(i, j)` 记录比较，`a.swap(i, j)` 记录
交换，`a[i] = v` 记录更新，读取 `a[i]` 只计数不生成步骤。直接写
`a[i] < a[j]` 不会被记录为比较，需要比较时请用 `less` 或 `compare`。

```mbt nocheck
fn bubble_sort(a : @frontierlab.TracedArray[Int]) -> Unit {
  for end = a.length() - 1; end > 0; end = end - 1 {
    for i in 0..<end {
      if a.less(i + 1, i) {
        a.swap(i, i + 1)
      }
    }
  }
}

let a = @frontierlab.TracedArray::new([5, 2, 4, 1, 3], title="Bubble sort")
bubble_sort(a)
let html = @frontierlab.render_trace_html(a.finish())
```

**快照推断 `SequenceProbe`**：算法继续使用普通 `Array`，每次变化后调用一次
`probe.observe(values)`。FrontierLab 比较前后快照，自动推断交换、更新、移动、
插入和删除事件，并保持元素 ID 稳定；比较不会改变数据，需要时用
`probe.compare(i, j)` 补充。

两者都接受 `level` 参数：`Full` 记录完整轨迹，`Count` 只统计比较、交换、读、
写次数（`counts()`），`Off` 什么都不做，用作测量追踪开销的基准。记录过程中
的错误（例如超过步数上限）会保留到 `finish()` 时再抛出，因此被追踪的算法
不需要声明 `raise`。完整示例见 `examples/traced_sort`。

## 复杂度与开销分析

`TraceLevel::Count` 下只累加计数器，不记录轨迹，因此可以对大规模输入测量算法
本身的操作次数，并拟合复杂度量级：

```mbt nocheck
let profile = @frontierlab.profile_traced_array(
  [128, 256, 512, 1024, 2048],
  fn(n) { Array::makei(n, fn(i) { n - i }) },
  bubble_sort,
  metric=Compares,
)
println(profile.report()) // Best fit: O(n^2), cost ≈ 0.5 · n^2 ...
assert_true(profile.check_bound(Quadratic, factor=0.5).is_empty())
```

- `profile_traced_array` / `profile_complexity`：按输入规模统计比较、交换、读、
  写次数，用相对误差最小二乘拟合 O(1) 到 O(2^n)，并给出对数坐标下的经验指数。
- `check_bound`：操作计数是确定的，可以在测试或 CI 中断言“比较次数不超过
  k·n log n”这类复杂度上界，算法退化时测试直接失败。
- `measure_tracing_overhead`：同一算法分别在 `Off`、`Count`、`Full` 下计时，
  报告追踪带来的倍率、每步开销和轨迹体积。计时函数由调用方传入（例如
  `@env.now`），库本身不依赖平台时钟。

实测结果见[性能记录](BENCHMARKS.md)：只计数的开销约 14%，完整轨迹的开销主要来自
每一步保存完整快照。可运行示例见 `examples/complexity_profile`。

## 内置算法 Adapter

Adapter 把算法输入和执行步骤转换成统一的 `AlgorithmTrace`，因此这些轨迹可以
直接交给 JSON、HTML、分析、断点、diff 和诊断 API：

| 类别 | Adapter | 场景 | 主要语义事件 |
|---|---|---|---|
| 排序 | `insertion_sort_trace`、`insertion_sort_items_trace` | `Sequence` | `Compare`、`Swap` |
| 集合 | `union_find_trace` | `Sets` | `Compare`、`Union`、`Update` |
| 一维 DP | `fibonacci_dp_trace`、`coin_change_dp_trace` | `Sequence` | `Update`、依赖高亮 |
| 二维 DP | `zero_one_knapsack_dp_trace`、`lcs_dp_trace` | `Grid` | `Update`、`Visit` |
| 平衡树 | `red_black_tree_trace` | `Graph` | 插入、重着色、旋转、查找 |
| 路径搜索桥接 | `search_trace_to_algorithm_trace` | `Grid` | `Visit`、`Relax` |

Fibonacci 和零钱兑换保留各自简单的算法级入口，但内部共享一维 DP 场景表达。
红黑树支持 `Insert` 和 `Find` 操作；节点标签中的 `[R]`、`[B]` 在不修改
Trace Schema v1 的前提下持久表示颜色。

```mbt nocheck
let lcs = @frontierlab.lcs_dp_trace("ABCBDAB", "BDCABA")
let tree = @frontierlab.red_black_tree_trace([
  @frontierlab.Insert(30),
  @frontierlab.Insert(10),
  @frontierlab.Insert(20),
  @frontierlab.Find(20),
])
```

## CLI

从源码运行统一诊断命令：

```bash
moon run cmd/main -- diagnose \
  fixtures/agent-traces/selection-sort-expected.json \
  fixtures/agent-traces/selection-sort-actual.json \
  --contract sorted-int-sequence \
  --object values \
  --format text \
  --counterexample _build/counterexample.json \
  --report _build/diagnosis.html
```

这组示例输入故意包含错误，所以命令返回退出码 `2`，并报告第一次差异在
step 10。CLI 的退出码含义为：

- `0`：输入有效，并且轨迹通过检查且与参考轨迹一致；
- `2`：输入有效，但轨迹违反规则或与参考轨迹不同；
- `1`：参数、文件、JSON 或 Schema 无效。

GitHub Release 同时提供 Windows 可执行文件和 SHA256。也可以在本地构建：

```powershell
python scripts\build_cli.py
.\_dist\frontierlab.exe --version
```

## 生成算法可视化

最直接的用法是让 CLI 生成一个完全离线的 HTML 文件，然后双击打开。页面默认
使用中文，可切换 English，并会显示比较对象、交换方向、旧值到新值、DP 依赖、
网格坐标、图节点移动、Adapter 注释和伪代码行。

```powershell
New-Item -ItemType Directory -Force _build\visual | Out-Null
moon run cmd/main -- demo insertion-sort --format html --output _build/visual/insertion-sort.html
moon run cmd/main -- demo fibonacci --format html --output _build/visual/fibonacci.html
moon run cmd/main -- demo coin-change --format html --output _build/visual/coin-change.html
moon run cmd/main -- demo knapsack --format html --output _build/visual/knapsack.html
moon run cmd/main -- demo lcs --format html --output _build/visual/lcs.html
moon run cmd/main -- demo union-find --format html --output _build/visual/union-find.html
moon run cmd/main -- demo pathfinding --format html --output _build/visual/pathfinding.html
moon run cmd/main -- demo red-black-tree --format html --output _build/visual/red-black-tree.html
```

如果已经有 Schema v1 JSON 轨迹，则使用：

```powershell
moon run cmd/main -- render trace.json --format html --output trace.html
```

`render_trace_svg` 与 `render_trace_svg_frames` 在 v0.9 仅保留为旧代码兼容入口，
已经标记弃用，并计划在 v1.0 删除。新项目应选择交互 HTML；需要交换或长期存档
轨迹数据时选择 Schema v1 JSON。

## 离线浏览器工具

AI Trace Clinic 是一个单文件离线页面，可导入、回放和比较轨迹，不依赖服务器、
CDN 或外部脚本：

```bash
moon run cmd/main -- playground --output _build/playground.html
```

生成后直接用浏览器打开 `_build/playground.html`。页面自带一个错误示例，用于
展示规则失败、第一次差异、状态变化和聚焦切片。

## 核心 API

| 用途 | 主要 API | 说明 |
|---|---|---|
| 记录轨迹 | `TraceBuilder::new`、`record`、`finish` | 把算法执行过程记录为语义事件和完整场景快照 |
| 统一诊断 | `diagnose_trace`、`TraceDiagnosis::passed` | 同时执行规则检查、参考轨迹比较和聚焦切片 |
| 调试与比较 | `diff`、`breakpoint_hits`、`slice`、`first_divergence` | 查看步骤变化、命中语义断点并定位第一次差异 |
| JSON 协议 | `encode_json`、`AlgorithmTrace::decode_json`、`validate` | 读写并校验稳定的 Trace Schema v1 |
| 输出 | `render_trace_html`、`render_trace_playground` | 生成交互式离线 HTML 或诊断页面；SVG API 仅作弃用兼容 |

完整公开接口由 `moon info` 生成在 [pkg.generated.mbti](pkg.generated.mbti) 中。

## 独立 consumer 示例

`consumer/frontierlab_consumer_demo` 是一个单独的 MoonBit 项目。它通过
Mooncakes 安装 `shop1111/frontierlab`，不引用当前仓库中的源码，因此可以模拟
一个真正的外部使用者。

这个项目有两个作用：验证发布包确实能被其他项目安装和调用，以及提供一个完整
的集成示例。普通用户不需要运行它；安装依赖并调用上面的公开 API 即可。

发布后可用以下命令核验：

```bash
cd consumer/frontierlab_consumer_demo
moon tree
moon check --target all --deny-warn
moon test --target all --deny-warn
```

consumer 不会被打入 FrontierLab 的 Mooncakes 源码包，它运行时生成的
`evidence/` 目录也不会提交到 Git。

## 开发与验证

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
moon test --target all --deny-warn
python scripts/check_coverage.py
node scripts/check_playground.mjs
node scripts/check_renderer.mjs _build/renderer/insertion-sort.html
python scripts/validate_cli.py
moon package --list
moon package
```

更多资料：

- [Trace Schema v1](docs/TRACE_SCHEMA.md)
- [算法集成说明](docs/INTEGRATION.md)
- [渲染与安全模型](docs/RENDERING.md)
- [可复现性能记录](BENCHMARKS.md)
- [变更记录](CHANGELOG.md)
- [贡献指南](CONTRIBUTING.md)

## License

MIT
