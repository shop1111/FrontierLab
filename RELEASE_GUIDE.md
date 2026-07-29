# FrontierLab 后续发布指引

本文件是未来人工发布手册。本轮 v0.7.0 冲刺不执行其中任何远程写操作。

## 发布前共同检查

1. 从干净候选提交运行 [ACCEPTANCE.md](ACCEPTANCE.md) 的全部门禁。
2. 核对 `moon.mod`、CHANGELOG、包名和构建产物版本一致。
3. 分别读取 GitHub `main` 与 Gitlink `master` 的远程 SHA；不要由一个平台推断
   另一个平台状态。
4. 确认 Pages、Mooncakes 和两个 release 页面当前仍指向旧版本。

## v0.6.1

1. 从本地 v0.6.1 候选提交创建签名或 annotated tag `v0.6.1`。
2. 将该提交分别推到 GitHub `main` 和 Gitlink `master`，再读取两个远程 SHA。
3. 在 GitHub 与 Gitlink 分别创建 v0.6.1 release，并上传由该提交生成的包。
4. 执行 `moon publish`，随后从 Mooncakes 页面和解析器两侧验证 v0.6.1。
5. 触发 Pages，打开线上 Playground 并验证页面版本与静态资源。

## v0.7.0

1. 以本指南最终交付的 v0.7.0 候选 SHA 为唯一来源，重新运行完整门禁。
2. 将消费者依赖从 v0.6.0 升至已发布的 v0.6.1，验证后再升至 v0.7.0；每一步
   都必须由 Mooncakes 解析，禁止本地 override。
3. 创建 `v0.7.0` tag，将候选分别推到 GitHub `main` 和 Gitlink `master`。
4. 分别创建 GitHub/Gitlink release；上传
   `shop1111-frontierlab-0.7.0.zip`、冻结反例和诊断 HTML。
5. 发布 Mooncakes v0.7.0，并用一个全新临时模块验证 `moon add`/`moon tree`。
6. 部署 Pages；在桌面、390px 窄屏和断网重开三种场景验收 AI Trace Clinic。

## 每个平台的完成证据

- GitHub：远程 `main` SHA、tag SHA、release 页面和 CI/Pages 成功记录。
- Gitlink：远程 `master` SHA、tag SHA、release 页面和 CI 成功记录。
- Mooncakes：公开版本页、全新消费者解析出的精确版本。
- Pages：线上 URL、默认 step 10、正确案例 PASS、无外部脚本。

只有四个平台分别核验后，才能把文档中的“公开版本仍为 v0.6.0”改成新版本。
