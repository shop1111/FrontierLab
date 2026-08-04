# FrontierLab 发布与核验指引

v0.7.0 以 GitHub 与 Mooncakes 为正式发布面；Gitlink 是需要独立同步和核验的
镜像，不能由 GitHub 状态推断。

## 发布前共同检查

1. 从干净候选提交运行 [ACCEPTANCE.md](ACCEPTANCE.md) 的全部门禁。
2. 核对 `moon.mod`、CHANGELOG、包名和构建产物版本一致。
3. 分别读取 GitHub `main` 与 Gitlink `master` 的远程 SHA；不要由一个平台推断
   另一个平台状态。
4. 确认 Pages、Mooncakes 和 release 页面没有同名 tag 或版本冲突。

## v0.6.1 候选锚点

`fe75f65dadb1fb0ab4f517240729bf838c7134c4` 保留为严格工具链修复锚点；
其修复已包含在 v0.7.0 中，不要求为了发布 v0.7.0 先创建一个公开 v0.6.1。

## v0.7.0

1. 以通过完整门禁的发布提交为唯一来源。
2. 创建 `v0.7.0` annotated tag，将发布提交推到 GitHub `main`。
3. 创建 GitHub release；上传
   `shop1111-frontierlab-0.7.0.zip`、冻结反例和诊断 HTML。
4. 发布 Mooncakes v0.7.0，并用一个全新临时模块验证 `moon add`/`moon tree`。
5. 由 `main` 推送触发 Pages；在线核验默认 step 10 和正确案例 PASS。
6. 若需要 Gitlink，同步 Gitlink `master`/tag 并单独创建 release。

## 每个平台的完成证据

- GitHub：远程 `main` SHA、tag SHA、release 页面和 CI/Pages 成功记录。
- Gitlink：远程 `master` SHA、tag SHA、release 页面和 CI 成功记录。
- Mooncakes：公开版本页、全新消费者解析出的精确版本。
- Pages：线上 URL、默认 step 10、正确案例 PASS、无外部脚本。

对外说明必须明确区分 GitHub、Mooncakes、Pages 与 Gitlink 的实际状态。
