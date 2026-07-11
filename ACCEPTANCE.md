# FrontierLab acceptance guide

This is the shortest reproducible path for reviewers of FrontierLab 0.5.0.

## 1. Try it without installing anything

- Open the [live showcase](https://shop1111.github.io/FrontierLab/).
- Open **Trace Playground**.
- Select **Invalid example** to see field-level schema diagnostics.
- Select **Valid example**, move through the timeline, and export the current frame as SVG.
- The page is self-contained: imported trace data never leaves the browser.

## 2. Run the quality gates

```bash
moon version --all
moon update
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
moon test --target all --deny-warn
moon package
```

After `moon info`, a clean committed checkout should also pass `git diff --exit-code`.

## 3. Reproduce the user flow

```bash
mkdir -p _build/acceptance
moon run cmd/main -- playground --output _build/acceptance/playground.html
moon run cmd/main -- demo insertion-sort --format svg --output _build/acceptance/insertion-sort.svg
moon run cmd/main -- demo union-find --format json --output _build/acceptance/union-find.json
moon run cmd/main -- analyze _build/acceptance/union-find.json
moon run cmd/main -- validate _build/acceptance/union-find.json
moon run cmd/main -- render _build/acceptance/union-find.json --format html --output _build/acceptance/union-find.html
```

Expected results: all commands exit successfully; the Playground and replay HTML open without a server or network connection; the JSON validates; the analysis reports event/object/target usage; and `_build/publish/shop1111-frontierlab-0.5.0.zip` exists after packaging.

## 4. Public project locations

- GitHub: <https://github.com/shop1111/FrontierLab>
- Gitlink mirror: <https://gitlink.org.cn/zhengpx/FrontierLab>
- Mooncakes: <https://mooncakes.io/docs/shop1111/frontierlab>
- Pages: <https://shop1111.github.io/FrontierLab/>

The GitHub `main` branch and Gitlink `master` branch should point to the same release commit. The repository version, Git tags/releases, and Mooncakes latest version should also match.
