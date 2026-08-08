# FrontierLab

FrontierLab 是一个 MoonBit 算法轨迹库。它把算法执行过程记录为带稳定实体 ID
的语义事件和场景快照，并提供检查、对比、调试、JSON 编解码和离线 HTML/SVG
渲染能力。

[![CI](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml/badge.svg)](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-v0.7.1-7c3aed)](https://mooncakes.io/docs/shop1111/frontierlab)

[在线打开 AI Trace Clinic](https://shop1111.github.io/FrontierLab/playground.html) ·
[Mooncakes](https://mooncakes.io/docs/shop1111/frontierlab) ·
[Trace Schema v1](docs/TRACE_SCHEMA.md)

## 安装

在 MoonBit 项目中添加依赖：

```bash
moon add shop1111/frontierlab@0.7.1
```

然后在需要使用 FrontierLab 的包中导入 `shop1111/frontierlab`。

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
| 输出 | `render_trace_html`、`render_trace_svg`、`render_trace_playground` | 生成离线 HTML、SVG 或诊断页面 |

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
