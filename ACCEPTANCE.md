# FrontierLab acceptance guide

This is the shortest reproducible path for reviewers of the local FrontierLab
0.6.1 candidate. The public Mooncakes and hosted Playground release remains
0.6.0 until a later publication step.

## 1. Try it without installing anything

- Open the [live showcase](https://shop1111.github.io/FrontierLab/).
- Open **Semantic Time-Travel Debugger**.
- Select **Faulty sort**, run `sequence-transition`, and jump to the first illegal mutation.
- Inspect the previous-frame diff, set a `compare` breakpoint, and export the counterexample.
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
moon run cmd/main -- demo faulty-insertion-sort --format json --output _build/acceptance/faulty.json
moon run cmd/main -- verify _build/acceptance/faulty.json --contract sequence-transition --object values --format json --counterexample _build/acceptance/counterexample.json
```

Expected results: quality gates and valid examples exit successfully; the faulty contract command exits 2 and writes a counterexample; the debugger works without a server or network connection; and `_build/publish/shop1111-frontierlab-0.6.1.zip` exists after packaging.

## 4. Public project locations

- GitHub: <https://github.com/shop1111/FrontierLab>
- Gitlink mirror: <https://gitlink.org.cn/zhengpx/FrontierLab>
- Mooncakes: <https://mooncakes.io/docs/shop1111/frontierlab>
- Pages: <https://shop1111.github.io/FrontierLab/>

The GitHub `main` branch and Gitlink `master` branch should point to the same release commit. The repository version, Git tags/releases, and Mooncakes latest version should also match.
