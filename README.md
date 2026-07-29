# FrontierLab

**把 AI 或算法生成的错误轨迹，收敛成可定位、可复现、可修复的证据。**

[![CI](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml/badge.svg)](https://github.com/shop1111/FrontierLab/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-live%20v0.6.0-7c3aed)](https://mooncakes.io/docs/shop1111/frontierlab)

[AI Trace Clinic](https://shop1111.github.io/FrontierLab/playground.html) ·
[GitHub](https://github.com/shop1111/FrontierLab) ·
[Gitlink](https://gitlink.org.cn/zhengpx/FrontierLab) ·
[Schema v1](docs/TRACE_SCHEMA.md)

> 当前工作树是 **v0.7.0 未发布候选**；Mooncakes、Pages 与远程仓库仍是
> **v0.6.0**。本轮没有推送、打标签或发布。

## 三条命令体验完整闭环

```bash
# 1. 对冻结的正确/错误轨迹执行契约、首次分歧与反例切片
moon run cmd/main -- diagnose fixtures/agent-traces/selection-sort-expected.json fixtures/agent-traces/selection-sort-actual.json --contract insertion-sort-int --object values --format text --counterexample _build/counterexample.json --report _build/diagnosis.html

# 2. 生成完全离线、单文件的 AI Trace Clinic
moon run cmd/main -- playground --output _build/playground.html

# 3. 独立消费者只从 Mooncakes v0.6.0 解析依赖并复现实例
cd consumer/frontierlab_consumer_demo && moon test --target all --deny-warn
```

第一条命令预期返回退出码 `2`，自动定位到 **step 10**：正确轨迹交换
`item-2/item-4`（值 4 与 3），错误轨迹却使用过期下标交换
`item-2/item-0`（值 4 与 5）。这是有效输入上的语义失败，不是 CLI 错误。

```mermaid
flowchart LR
  A["导入错误轨迹"] --> B["Schema / 契约检查"]
  B --> C["首次分歧 step 10"]
  C --> D["状态变化"]
  D --> E["最小反例 JSON"]
  E --> F["可复制修复提示"]
```

## 产品闭环

FrontierLab 不是算法合集，也不是通用绘图库。算法或 Agent 记录
`Compare`、`Swap`、`Visit`、`Union`、`Relax` 等语义事件和完整场景快照；
同一份 schema-v1 轨迹随后可被：

- 契约检查，区分“格式正确”和“过程正确”；
- 与参考轨迹比较，定位第一次事件或状态分歧；
- 按稳定实体 ID 展示字段变化，而不是只比较数组下标；
- 切成便携的最小反例，并生成离线 HTML 与修复提示；
- 通过 JSON CLI 接入 Agent/CI，或在浏览器本地一键诊断。

`diagnose` 的退出语义固定为：

- `0`：轨迹一致且契约通过；
- `2`：输入有效，但存在契约失败或首次分歧；
- `1`：参数、文件、JSON 或 Schema 错误。

旧有 `verify`、`diverge`、`diff`、`breakpoints`、`render` 等命令和
`frontierlab-debug-report/1.0` 外层报告保持兼容。

## 三种集成路径

1. **MoonBit 库**：用 `TraceBuilder` 记录过程，再调用
   `TraceContract::check`、`first_divergence`、`slice` 或渲染器。
2. **CLI / AI Agent**：使用稳定 JSON 报告与退出码，在流水线中直接运行
   `diagnose`。
3. **离线浏览器**：生成 `playground.html`，无需服务器、CDN、框架或联网；
   默认错误案例一次点击即跳到 step 10。

完整示例见 [集成说明](docs/INTEGRATION.md)、[Schema 说明](docs/TRACE_SCHEMA.md)
和[独立消费者证明](consumer/frontierlab_consumer_demo/README.md)。

## 核心 API

- 构建：`TraceBuilder::new`、`record`、`finish`
- 模型：`AlgorithmTrace`、`TraceEvent`、`Scene`、`TargetRef`
- 调试：`diff`、`breakpoint_hits`、`slice`、`first_divergence`
- 契约：`sequence_transition_contract`、`insertion_sort_int_contract`、
  `grid_path_contract`
- 协议：`encode_json`、`decode_json`、`validate`
- 输出：`render_trace_html`、`render_trace_svg`、`render_trace_playground`
- 兼容算法：BFS、Dijkstra、A*、插入排序、Union-Find

`AlgorithmTrace::decode_json` 接受可选 `TraceOptions`，因此大规模但明确授权
的 50,000 步基准可以突破默认 10,000 步安全上限，同时普通调用保持原行为。

## 开发与验收

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
moon test --target all --deny-warn
python scripts/check_coverage.py
moon package
```

覆盖率门禁要求调试器、契约、codec、report、quality 五个核心文件零未覆盖，
且扣除带理由的薄 I/O、benchmark、示例入口后，全仓不超过 20 行。规则记录在
[`coverage-exemptions.json`](coverage-exemptions.json)。

## Documentation

- [三分钟演示脚本](DEMO_SCRIPT.md)
- [评委逐步验收](ACCEPTANCE.md)
- [Trace Schema v1](docs/TRACE_SCHEMA.md)
- [三种集成路径](docs/INTEGRATION.md)
- [渲染与安全模型](docs/RENDERING.md)
- [可复现性能记录](BENCHMARKS.md)
- [未来发布指引](RELEASE_GUIDE.md)
- [变更记录](CHANGELOG.md)

## License

MIT
