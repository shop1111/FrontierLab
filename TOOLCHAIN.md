# Toolchain policy

FrontierLab validates two fixed MoonBit compiler versions:

```text
Minimum supported: moonc v0.10.4+2cc641edf
Current stable:    moonc v0.10.6+80dc50f24
```

The minimum version runs the complete CI, packaging, examples, CLI, coverage,
and generated-interface checks. The current stable version runs strict
all-target check, build, and test gates. Both jobs are blocking.

Using fixed versions keeps release status reproducible and prevents a future
floating toolchain update from changing the status of an otherwise unchanged
release.

To install either compiler on Unix, pass its complete version to the official
installer, for example:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh |
  bash -s -- "0.10.6+80dc50f24"
```
