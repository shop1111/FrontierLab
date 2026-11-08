# Toolchain policy

FrontierLab requires MoonBit `moonc` 0.10.20 or newer. CI pins one fixed
compiler and also watches the latest release:

```text
Pinned (blocking):    moonc v0.10.20+65efd5b93
Latest (advisory):    whatever the official installer serves today
```

The pinned version runs the complete CI, packaging, examples, CLI, coverage,
and generated-interface checks. The latest version runs strict all-target
check, build, and test gates as an early warning; a failure there does not
block a merge, but should be fixed before the next release.

Using a fixed blocking version keeps release status reproducible and prevents
a future toolchain update from changing the status of an otherwise unchanged
release.

To install the pinned compiler on Unix, pass its complete version (including
the build hash) to the official installer:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh |
  bash -s -- "0.10.20+65efd5b93"
```

On Windows, set the version before running the PowerShell installer:

```powershell
$env:MOONBIT_INSTALL_VERSION = "0.10.20+65efd5b93"
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

## Why 0.10.20

`moonc` 0.10.20 deprecates `derive(...)` after a type declaration in favor of
`#derive(...)` before it, and `--deny-warn` turns the deprecation into an
error. Earlier compilers ignore `#derive(...)`, so the sources cannot satisfy
both: FrontierLab 0.11 and later need 0.10.20. Published 0.10.0 still uses the
old syntax and builds as a dependency on 0.10.16 through 0.10.20.

After upgrading a local toolchain, delete stale target outputs
(`_build/native`, `_build/js`, `_build/wasm`, `_build/wasm-gc`) before running
`python scripts/check_coverage.py`; coverage metadata produced by an older
compiler makes `moon coverage analyze` fail with "conflicting trace metadata".
