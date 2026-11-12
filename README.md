# FrontierLab

FrontierLab 是 MoonBit 的数据结构与算法调试库。把你写的数据结构和它的操作交给
FrontierLab，它会自动找出**从哪一步开始出错**，并生成可以前后拖动的离线回放页面。
你的代码不需要改动，也不需要手动打点。

[![CI](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml/badge.svg)](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-package-7c3aed)](https://mooncakes.io/docs/shop1111/frontierlab)

[在线演示](https://shop1111.github.io/FrontierLab/) ·
[Mooncakes](https://mooncakes.io/docs/shop1111/frontierlab) ·
[Trace Schema v1](docs/TRACE_SCHEMA.md)

## 安装

```bash
moon add shop1111/frontierlab
```

然后在 `moon.pkg` 里导入需要的包。只在测试里用时，写在 `for "test"` 下即可：

```
import {
  "shop1111/frontierlab/explore",
} for "test"
```

| 包 | 用途 |
|---|---|
| `shop1111/frontierlab/explore` | **调试你自己的数据结构**：自动找出出错的操作序列并生成回放页面 |
| `shop1111/frontierlab` | 核心：轨迹格式、`TracedArray`、规则检查、逐步 diff、首次分歧、反例搜索、HTML 播放器 |
| `shop1111/frontierlab/profile` | 复杂度拟合、复杂度上界断言、记录开销测量 |
| `shop1111/frontierlab/classics` | 内置经典算法的轨迹（排序、并查集、DP、红黑树），用于教学演示 |

需要 MoonBit `moonc` 0.10.20 或更新版本，CI 固定在 `0.10.20+65efd5b93` 上验证，
详见[工具链策略](TOOLCHAIN.md)。

## 快速开始：数据结构哪里写错了？

假设你写了一棵二叉搜索树，`delete` 有 bug：删除有两个孩子的节点时，后继节点应该从
右子树删掉，代码却写成了从左子树删。下面这段代码**原样不动**，只需要像平常一样带上
`derive(ToJson)`：

```mbt nocheck
#derive(ToJson)
enum Tree {
  Leaf
  Node(Tree, Int, Tree)
}

fn insert(t : Tree, k : Int) -> Tree { ... }
fn delete(t : Tree, k : Int) -> Tree { ... } // 有 bug

// 你希望每次操作之后都成立的性质：中序遍历严格递增
fn is_bst(t : Tree) -> String? { ... }
```

在测试里把它交给 FrontierLab：

```mbt nocheck
test "找出 delete 的 bug" {
  let ops = [@explore.Op::new("insert", insert), @explore.Op::new("delete", delete)]
  match @explore.explore(() => Leaf, ops, invariant=is_bst) {
    Some(found) => {
      found.save_html("bst.html")  // 写到模块根目录
      fail(found.report())
    }
    None => ()
  }
}
```

输出（来自 [examples/explore_bst](examples/explore_bst/main.mbt) 的实际运行结果）：

```
Found after 88 random sequences (seed 1); shrunk from 12 to 4 steps in 5 rounds.
Step 4 of 4 (delete 1) failed: in-order keys 2 and 2 are not increasing
Steps: insert 1, insert 2, insert 0, delete 1
```

FrontierLab 随机生成了 88 串操作，第 88 串让树失效。它把这 12 个操作缩到最短的 4 个，
参数也尽量缩小，然后只对这 4 个操作完整记录。打开 `bst.html`：

- 每一步都画出整棵树，左右孩子的位置和你的数据结构一致；
- 新增或移动过的节点高亮，被删掉的节点写在注释里；
- 拖到第 4 步，能直接看到根是 2、右孩子也是 2，并标红：后继节点没有被删掉。

### 用自己构建的输入回放

想验证某个具体输入时，用 `replay` 加一段操作脚本。脚本用逗号、分号或换行分隔：

```mbt nocheck
let replay = @explore.replay(
  () => Leaf,
  ops,
  @explore.Step::parse("insert 50, insert 30, insert 70, insert 20, insert 40, delete 30"),
  invariant=is_bst,
)
println(replay.report())
// Step 6 of 6 (delete 30) failed: in-order keys 40 and 40 are not increasing
replay.save_html("my-input.html")
```

### 三种检查

| 参数 | 签名 | 适合检查什么 |
|---|---|---|
| `invariant` | `(S) -> String?` | 任何时候都应成立的性质：BST 有序、堆序、红黑树性质、大小不超过容量 |
| `check` | `(S, Step) -> String?` | 和这一步操作有关的要求：`delete k` 之后不应再有 `k`，`push x` 之后栈顶应是 `x` |
| `model` | `Model` | 和一个简单、显然正确的参考实现对照：每一步的返回值必须相同 |

`invariant` 和 `check` 返回 `Some(原因)` 表示失败。没有 `model` 时，操作本身抛出错误
（例如对空栈 `pop`）也算失败，原因会写成 `raised ...`。`check` 里用 `step.int_arg()`
取整数参数。

### 对照参考实现：结构没坏，但答案错了

有些 bug 不会破坏结构。下面这棵字符串集合树，`contains` 查找更大的词时又去了左子树：
树始终有序，`invariant` 发现不了，只有返回值是错的。这时给出一个**参考实现**，
FrontierLab 每一步都同时运行两边，比较返回值：

```mbt nocheck
// 会返回结果的操作用 Op::returning*，返回 (新状态, 结果)；结果只需要 Debug
let ops = [
  @explore.Op::with_gen("add", words(), add),
  @explore.Op::returning_with_gen("contains", words(), (s, w) => (s, contains(s, w))),
]
// 参考实现：一个普通数组，操作同名
let model = @explore.Model::new(() => ([] : Array[String]), [
  @explore.Op::with_gen("add", words(), (list, w) => { if !list.contains(w) { list.push(w) }; list }),
  @explore.Op::returning_with_gen("contains", words(), (list, w) => (list, list.contains(w))),
])
@explore.explore(() => Empty, ops, model~)
```

输出（来自 [examples/explore_model](examples/explore_model/main.mbt)）：

```
Found after 2 random sequences (seed 1); shrunk from 10 to 3 steps in 5 rounds.
Step 3 of 3 (contains "p") failed: returned false, but the model returned true
Steps: add "", add "p", contains "p"
```

- 返回值按 `Debug` 输出比较，例如 `true`、`Some(1)`。
- 两边都抛出错误（例如都对空栈 `pop`）算一致；只有一边抛出才算失败。
- 想比较整个内容时，两边各加一个查询操作，例如
  `Op::returning_without_arg("keys", t => (t, keys(t)))`。
- 回放页面每一步都会显示返回值。

### 任意参数类型

`Op::new` 的参数是 `0..<max_arg` 里的整数，故意取小范围让 key 经常重复。其他参数类型用
`Op::with_gen`，配一个 core `quickcheck` 的生成器：

```mbt nocheck
let words = @quickcheck.elements(["apple", "fig", "kiwi"])
let entries = words.flat_map(k => @quickcheck.int_range(0, 3).map(v => (k, v)))
@explore.Op::with_gen("put", entries, put)        // 参数是 (String, Int)
@explore.Op::with_gen("add", @quickcheck.spawn(), add)  // 任何实现了 Arbitrary 的类型
```

参数类型需要 `ToJson` 和 `FromJson`：步骤里按 JSON 记录参数，所以可以显示、写进脚本、
自动缩小。手写脚本时参数也写成 JSON：`put ["apple", 1], get "apple"`。缩小时数字趋向 0，
字符串和数组变短，同一个值在多个步骤里出现时会一起缩小。

### 看操作内部：`mark`

回放默认只拍每次操作前后的结构。想看操作内部某一行的状态，在那一行调用
`@explore.mark(value)`：

```mbt nocheck
fn HashMap::grow(self : HashMap) -> Unit {
  ...
  self.buckets = wider
  @explore.mark(self, note="after grow")
}
```

`replay` 运行被测操作时，每个 `mark` 都成为播放器里单独的一步，标题带源码位置
（`examples/explore_views/main.mbt:38`），后一个 mark 会高亮相对前一个的变化。行号由
编译器自动填入。只有 `replay` 运行被测操作时才记录，搜索和参考实现里的 `mark` 只做一次判断
就返回，所以可以留在代码里。每一步最多记录 200 个 mark。

### 自动逐行回放：`frontierlab-instrument`

不想手写 `mark` 时，让工具在函数的每条语句前自动插入：

```bash
frontierlab-instrument examples/explore_views/main.mbt --fn HashMap::grow --watch wider
moon run examples/explore_views          # grow 的每一行都成了回放里的一步
frontierlab-instrument --remove examples/explore_views/main.mbt
```

工具用官方的 `moonbitlang/parser` 解析源码，在 `HashMap::grow` 的每条语句前插入
`@explore.auto_mark(wider, 32, "for i, bucket in self.buckets {")`，回放时每一行都显示
`wider` 在这一行执行前的样子：

```text
Step 3: put ["f",0]
  at examples/explore_views/main.mbt:32 (before: for i, bucket in self.buckets {):
    State:
      0: -
      1: -
      2: -
      3: -
  at examples/explore_views/main.mbt:34 (before: wider[i].push(entry)):
    + "": 0 in bucket 0
  ...
```

- `--watch` 默认是函数的第一个参数。局部变量只在它的作用域里记录：`let` 之后，或绑定它的
  循环体内。被记录的部分如果正好是某个视图画的那一块（这里 `wider` 就是 `buckets`），
  也按那个视图画。
- 标记插在语句所在的那一行，并带着原来的行号，所以文件行号不变；即使 `moon fmt` 把标记
  挪到单独的行，回放里显示的仍是原来的行号，`--remove` 也能把整行删掉，文件逐字节恢复。
- 闭包和局部函数的函数体不插。插入后会重新解析一遍，解析失败就不写文件。
- 被测函数所在包的 `moon.pkg` 要导入 `shop1111/frontierlab/explore`，没导入时工具会提示。

工具在单独的 [instrument](instrument/README.md) 模块里，FrontierLab 库本身不依赖解析器。
GitHub Release 提供 `frontierlab-instrument.exe`，也可以在 `instrument/` 目录里
`moon run main -- ...` 运行。

### 文字报告和回归测试

`report()` 只有一行结论。`explain()` 给出逐步的文字记录，适合在终端里看，也适合交给
AI 助手分析：每一步的返回值、`mark` 记录的中间状态、结构的变化（`+` 新增、`-` 删除、
`~` 移动或改变），以及出错后的完整结构。下面是
[examples/explore_views](examples/explore_views/main.mbt) 的输出，一个扩容时没有重新哈希的
哈希表：

```text
Step 3: put ["f",0]
  at examples/explore_views/main.mbt:38 (after grow):
    buckets:
      0: "": 0, f: 0
      1: ant: 0
      2: -
      3: -
    fields: [size=3]
  fields: [size=2] -> [size=3]
  + f: 0 in bucket 0
Step 4: get "ant" -> None
  (no change)
  FAILED: returned None, but the model returned Some(0)
```

修 bug 之前，用 `regression_test()` 把最短序列存成测试，粘进自己包的 `_test.mbt`：

```mbt nocheck
println(found.regression_test(
  name="get finds every key after a grow",
  init="HashMap::new",
  ops="ops()",
  checks="model=model()",
))
```

生成的测试在任何检查失败时都失败，修好之后通过，以后再改坏会重新失败。

### 可变数据结构

`init` 每次调用都要返回一个新的初始状态，因为每串随机操作都从头开始。原地修改的结构
在操作里返回自身即可：

```mbt nocheck
let ops = [
  @explore.Op::new("push", (s : Stack, x) => { s.push(x); s }),
  @explore.Op::without_arg("pop", (s : Stack) => { ignore(s.pop()); s }),
]
@explore.explore(() => Stack::new(), ops, check=top_is_pushed)
```

### 能画出哪些结构

FrontierLab 不需要知道你的类型，它读 `derive(ToJson)` 的输出：

| 你的类型 | 画成 |
|---|---|
| `enum Tree { Leaf; Node(Tree, Int, Tree) }` | 二叉树。恰好两个子树位置时画成左、右孩子；`Leaf` 这类无参构造器是空孩子 |
| `enum Rb { E; N(Color, Rb, Int, Rb) }` | 二叉树，节点标签 `Black, 2`。从不放子树的位置（如颜色）进入标签 |
| `enum List { Nil; Cons(head~ : Int, tail~ : List) }` | 链表，边名为 `tail` |
| `struct Node { key : Int; left : Node?; right : Node? }` | 二叉树，`None` 字段不画 |
| `struct Trie { word : Bool; kids : Map[String, Trie] }` | 多叉树，边名为 `kids.a` |
| `struct N { key : Int; children : Array[N] }` | 多叉树，边名为 `children[0]` |
| `Array[Int]`，或只有数组和标量字段的结构体（如数组实现的堆） | 一行或几行序列，标量字段单独一行 |

节点按标签识别：同一个 key 移动后仍是同一个节点，所以旋转、上移能正确高亮。重复的
标签会按先序编号为 `40`、`40#2`。

有些结构从 `ToJson` 的输出看不出是什么：邻接表看起来是一个 map，哈希表看起来是数组
套数组。用 `views` 告诉 FrontierLab 某个字段该怎么画，字段路径用点分隔，`""` 表示
整个状态，没被视图画到的其余字段照常画：

| 视图 | 适用的值 | 画成 |
|---|---|---|
| `Graph("adj")` | `Map[K, Array[K]]`、`Array[Array[Int]]`，或 `Map[K, Map[K, W]]` | 有向图；邻居写成 `(node, weight)` 或带 `to` 字段的记录时，其余部分作为边的标签 |
| `Buckets("buckets")` | 桶的数组，每个桶是 `None`/`Some(entry)`、条目数组，或 `Cons(key, value, rest)` 这样的构造器链 | 哈希表，一行一个桶，键值对显示为 `key: value` |
| `Matrix("cells")` | 行的数组，每行是数组或字符串 | 网格，变化的格子高亮 |
| `NodeId("N#2")` | 树节点的字段名，或构造器参数位置（从 0 数） | 节点按这个字段识别：红黑树节点变色时仍是同一个节点，而不是删掉旧节点、加一个新节点 |

```mbt nocheck
@explore.explore(HashMap::new, ops(), model=model(), views=[Buckets("buckets")])
@explore.replay(() => E, rb_ops, steps, views=[NodeId("N#2")])
```

### 限制

- 每个操作最多一个参数；需要多个值时用元组，例如 `(String, Int)`。
- 带父指针或循环引用的结构无法用 `derive(ToJson)` 序列化，需要自己写不含父指针的
  `ToJson`。
- 每一步仍要把整个结构转换成快照，几千步的脚本请用 `window`，见下文的优化记录。
  回放页面里只存每一步的变化，所以页面本身不会随步数膨胀。
- 默认只看到每次操作前后的结构。操作内部要手动加 `mark`，或用 `frontierlab-instrument`
  自动插入；自动插入只记录一个变量，这个变量需要实现 `ToJson`。

## 数组算法：`TracedArray`

对于排序这类数组算法，把参数类型从 `Array` 换成 `TracedArray`，就能逐次记录比较和交换：

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

`a.less(i, j)`、`a.compare(i, j)` 记录比较，`a.swap(i, j)` 记录交换，`a[i] = v`
记录更新，读取 `a[i]` 只计数。直接写 `a[i] < a[j]` 不会被记录为比较。

不想改参数类型时，用 `SequenceProbe`：算法继续用普通 `Array`，每次变化后调用一次
`probe.observe(values)`，FrontierLab 比较前后快照推断交换、移动、插入和删除。

两者都接受 `level`：`Full` 记录完整轨迹，`Count` 只计数，`Off` 什么都不做。

### 自动找最小反例

```mbt nocheck
match @frontierlab.search_sequence_counterexample(my_sort, reference=simple_sort) {
  Some(found) => println(found.report())
  None => ()
}
```

随机生成整数数组，在 `Count` 档下只比较输出；找到错误后把输入缩到最小，只对最小输入
记录完整轨迹，并报告第一次与参考实现不同的步骤。`match_events=true` 时，输出相同但
操作顺序不同也算反例，能发现"结果对但做法不对"的实现。

## 复杂度断言：`profile`

操作次数是确定的，所以可以在 CI 里断言复杂度上界，不受机器快慢影响：

```mbt nocheck
let profile = @profile.profile_traced_array(
  [128, 256, 512, 1024, 2048],
  fn(n) { Array::makei(n, fn(i) { n - i }) },
  bubble_sort,
  metric=Compares,
)
println(profile.report()) // Best fit: O(n^2), cost ≈ 0.5 · n^2 ...
assert_true(profile.check_bound(Quadratic, factor=0.5).is_empty())
```

`measure_tracing_overhead` 在 `Off`、`Count`、`Full` 三档下分别计时，报告记录本身
的开销。可运行示例见 `examples/complexity_profile`。

## 这一版做了哪些优化

下面的数字来自本机 native release 构建的单次运行（Windows，`moonc 0.10.20`），
换机器请重新测量。复现命令：`moon run bench/explore_bench --target native --release`。

### 1. 零埋点接入：新增 `explore` 包

以前要调试自己的数据结构，只能用 `TraceBuilder` 手写每一步的场景，内置的红黑树
Adapter 画的也是库作者自己的树，不是你的。现在只要 `derive(ToJson)` 和一张操作表，
FrontierLab 就能运行、检查、缩减并画出你自己的代码。

### 2. 搜索时不拍快照，只完整记录最短出错序列

`explore` 在搜索阶段只运行操作和检查，不序列化、不画图；找到失败后先截掉失败之后的
操作，再缩减，最后只对缩减后的序列做一次完整回放：

| 情形 | 尝试的操作序列 | 最终步数 | 总耗时 |
|---|---:|---:|---:|
| 有 bug 的 `delete`（搜索 + 缩减 + 回放） | 88 | 4 | 0.35 ms |
| 正确的 `delete`（跑满 300 串都没找到问题） | 300 | — | 0.79 ms |

### 3. 回放窗口：只画出错前的最后 N 步

`replay(..., window=N)` 先不拍快照跑一遍，找到失败的位置，再只记录失败前的 N 步，
前面的步骤只执行不记录。失败编号仍然是脚本里的绝对位置。插入 n 个 key 的回放：

| n | 只跑操作 | 操作 + 不变量 | 完整回放 | `window=20` |
|---:|---:|---:|---:|---:|
| 50 | 0.010 ms | 0.023 ms | 5.5 ms | 3.5 ms |
| 200 | 0.073 ms | 0.22 ms | 80 ms | 16 ms |
| 1000 | 0.68 ms | 3.6 ms | 1,995 ms | 92 ms |

完整回放的代价主要来自"每一步都把整个结构转换成快照"：1000 步、平均 500 个节点，就是
50 万个节点。调试时一般只需要出错点附近，所以几千步的脚本建议加上 `window`。

### 4. 回放页面只存每一步的变化

以前回放页面里每一步都存一份完整的场景，1000 步、平均 500 个节点的回放页面有 149 MB，
浏览器几乎打不开。现在页面里只存第一个场景，之后每一步只存和上一步相比变化的部分
（对象里改了哪些字段、数组里中间换了哪几个元素），播放器打开时再还原。轨迹本身的
JSON 格式（Trace Schema v1）不变，所有使用 HTML 播放器的轨迹都会受益。

| n | 页面（修改前） | 页面（修改后） | `window=20` 页面（修改前 → 后） | 生成页面耗时（修改前 → 后） |
|---:|---:|---:|---:|---:|
| 50 | 448 KB | 61 KB | 305 KB → 51 KB | 7.6 ms → 3.7 ms |
| 200 | 6.1 MB | 130 KB | 1.3 MB → 67 KB | 110 ms → 41 ms |
| 1000 | 149 MB | 505 KB | 6.4 MB → 155 KB | 2,813 ms → 929 ms |

同时，生成快照时不再反复复制构造器参数，1000 次插入的完整回放从 4,059 ms 降到
1,995 ms。

### 5. 核心校验从 O(n²) 改为线性

构造场景时，节点 ID 唯一性、边的端点、高亮目标原来都靠两两比较或逐个线性查找，一个
n 个实体的场景要做 O(n²) 次比较。现在改为哈希表单遍扫描，报错内容不变（仍然报告第
一个重复的 ID）。所有使用图、序列、网格的轨迹都会受益。

| 场景（二叉树形状的图，所有节点高亮） | 修改前 | 修改后 |
|---:|---:|---:|
| 1,000 个节点 | 6 ms | 4 ms |
| 5,000 个节点 | 103 ms | 19 ms |
| 10,000 个节点 | 438 ms | 45 ms |

`explore` 的完整回放（1000 次插入）因此从 7,756 ms 降到 4,059 ms。

### 6. 拆包，并删掉偏离核心的功能

- 原来所有功能都在一个包里。现在按用途拆成 `explore`、核心、`profile`、`classics`
  四个包，只用其中一部分时，公开接口一眼就能看清。
- 删除了 AI Trace Clinic：它在浏览器 JavaScript 里重写了一遍校验、规则检查和分歧
  定位，每改一条规则都要改两处。离线诊断页面改用 `diagnose --report`。
- 删除了已弃用的 SVG 渲染、早期的网格寻路 API，以及 lint 和多种 Markdown 报告格式。

完整列表见[变更记录](CHANGELOG.md)。

## 内置经典算法：`classics`

用于教学演示的现成轨迹，可以直接交给 JSON、HTML、diff 和诊断 API：

| 类别 | 函数 | 场景 |
|---|---|---|
| 排序 | `insertion_sort_trace`、`insertion_sort_items_trace` | `Sequence` |
| 集合 | `union_find_trace` | `Sets` |
| 一维 DP | `fibonacci_dp_trace`、`coin_change_dp_trace` | `Sequence` |
| 二维 DP | `zero_one_knapsack_dp_trace`、`lcs_dp_trace` | `Grid` |
| 平衡树 | `red_black_tree_trace` | `Graph` |

```mbt nocheck
let lcs = @classics.lcs_dp_trace("ABCBDAB", "BDCABA")
let tree = @classics.red_black_tree_trace([
  @classics.Insert(30),
  @classics.Insert(10),
  @classics.Find(20),
])
```

## 手写轨迹与诊断

自动方式不够用时，可以用 `TraceBuilder` 手写场景和语义事件，再交给统一诊断：

```mbt nocheck
let trace = @classics.insertion_sort_trace([3, 1, 2])
let result = @frontierlab.diagnose_trace(
  trace,
  contract=@frontierlab.sorted_int_sequence_contract(object_id="values"),
  expected=trace,
)
assert_true(result.passed())
```

| 用途 | 主要 API |
|---|---|
| 记录轨迹 | `TraceBuilder::new`、`record`、`finish` |
| 统一诊断 | `diagnose_trace`、`TraceDiagnosis::passed` |
| 调试与比较 | `diff`、`breakpoint_hits`、`slice`、`first_divergence` |
| JSON 协议 | `encode_json`、`AlgorithmTrace::decode_json`、`validate` |
| 输出 | `render_trace_html` |

完整代码见 [API 示例](API.mbt.md) 和[集成说明](docs/INTEGRATION.md)，公开接口见各包的
`pkg.generated.mbti`。

## CLI

CLI 处理已经存在的 Schema v1 JSON 轨迹，以及内置算法：

```bash
moon run cmd/main -- diagnose \
  fixtures/agent-traces/selection-sort-expected.json \
  fixtures/agent-traces/selection-sort-actual.json \
  --contract sorted-int-sequence --object values \
  --report _build/diagnosis.html
moon run cmd/main -- render trace.json --format html --output trace.html
moon run cmd/main -- demo red-black-tree --format html --output red-black-tree.html
moon run cmd/main -- profile quick-sort --input sorted --bound "O(n log n)" --factor 2
moon run cmd/main -- search faulty-quick-sort --reference quick-sort
```

退出码：`0` 通过；`2` 输入有效但违反规则、与参考不同或超出复杂度上界；`1` 参数、
文件、JSON 或 Schema 无效。`diagnose --timings` 按阶段输出耗时。

GitHub Release 提供 Windows 可执行文件 `frontierlab.exe` 和
`frontierlab-instrument.exe` 及各自的 SHA256，也可以本地构建：`python scripts\build_cli.py`。

## 后续方向

- **一行记录多个变量**：`frontierlab-instrument` 现在每行只记录一个变量；同时看
  `self` 和局部变量需要把它们画进同一个场景。
- **跟随调用**：自动插入目前只处理点名的函数，它调用的辅助函数要另外点名。

0.13 是功能完整的版本。Mooncakes 目前只接受 0.x 版本号，等它开放 1.x 后会以 1.0.0
发布，之后遵循语义化版本：公开 API 的不兼容改动只在主版本号变化时出现。

## 独立 consumer 示例

`consumer/frontierlab_consumer_demo` 是一个单独的 MoonBit 项目，通过 Mooncakes 安装
已发布的 FrontierLab，用来验证发布包能被外部项目安装和调用。它扮演一个外部用户：自己写了
一个最小堆，`pop` 下沉时漏比较了右孩子，用 `explore` 找出 5 步的最短出错序列，修好后再跑一遍
确认通过。普通用户不需要运行它。

## 开发与验证

```bash
moon check --target all --deny-warn
moon fmt --check
moon info
moon test --target all --deny-warn
python scripts/check_coverage.py
python scripts/validate_cli.py
moon run examples/explore_bst -- _build/explore.html
moon run examples/explore_model -- _build/explore-model.html
moon run examples/explore_views -- _build/explore-views.html
(cd instrument && moon test --deny-warn)
moon run bench/explore_bench --target native --release
moon package
```

更多资料：[Trace Schema v1](docs/TRACE_SCHEMA.md) ·
[集成说明](docs/INTEGRATION.md) · [渲染与安全模型](docs/RENDERING.md) ·
[性能记录](BENCHMARKS.md) · [变更记录](CHANGELOG.md) · [贡献指南](CONTRIBUTING.md)

## License

MIT
