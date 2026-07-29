# FrontierLab v0.7.0 候选验收

本指南只验收本地候选。公开 Mooncakes、Pages、GitHub `main` 和 Gitlink
`master` 仍是 v0.6.0，本轮不执行推送、tag 或发布。

## 1. 三条命令看到闭环

```bash
moon run cmd/main -- diagnose fixtures/agent-traces/selection-sort-expected.json fixtures/agent-traces/selection-sort-actual.json --contract insertion-sort-int --object values --format text --counterexample _build/acceptance/counterexample.json --report _build/acceptance/diagnosis.html
moon run cmd/main -- playground --output _build/acceptance/playground.html
moon run cmd/main -- diagnose fixtures/agent-traces/selection-sort-expected.json fixtures/agent-traces/selection-sort-expected.json --contract insertion-sort-int --object values --format json
```

第一条返回 2，首次分歧与 focus 均为 step 10，并生成最小反例和离线报告；
第二条生成无外部脚本的 AI Trace Clinic；第三条返回 0，证明正确轨迹不误报。

## 2. 严格质量门禁

```bash
moon version --all
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
moon test --target all --deny-warn
python scripts/check_coverage.py
moon package --list
moon package
```

预期：四后端测试全部通过；五个核心调试文件零未覆盖；扣除
`coverage-exemptions.json` 中带理由的边界入口后不超过 20 行；包清单不包含
`consumer/frontierlab_consumer_demo`；产物为
`_build/publish/shop1111-frontierlab-0.7.0.zip`。

## 3. 独立消费者证明

```bash
cd consumer/frontierlab_consumer_demo
moon tree
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run . -- evidence
```

`moon tree` 必须显示 `shop1111/frontierlab@0.6.0`，不得出现本地路径 override。
消费者生成的错误选择排序在第 3 轮使用过期下标，首次事件分歧固定为 step 10，
最终序列无序。

## 4. 浏览器验收

直接打开 `_build/acceptance/playground.html`：

1. 保持默认 **Faulty selection sort**，点击一次 **Run diagnosis**。
2. 页面应自动定位 step 10，并同时展示契约、预期/实际事件、状态变化和最小反例。
3. 切换 **Correct selection sort**，结果应为 PASS。
4. 切换 Custom，只导入 actual，首次分歧应明确显示 SKIPPED。
5. 验证反例 JSON、诊断 HTML 和修复提示三个操作均有页面内反馈。
6. 在窄屏验证无横向溢出；断网后重新打开，功能仍可用。

## 5. 公开位置（仍为 v0.6.0）

- GitHub: <https://github.com/shop1111/FrontierLab>
- Gitlink: <https://gitlink.org.cn/zhengpx/FrontierLab>
- Mooncakes: <https://mooncakes.io/docs/shop1111/frontierlab>
- Pages: <https://shop1111.github.io/FrontierLab/>

未来发布顺序和逐平台核验见 [RELEASE_GUIDE.md](RELEASE_GUIDE.md)。
