# Toolchain policy

FrontierLab's required CI baseline is:

```text
moonc v0.10.4+2cc641edf
```

Every workflow that installs MoonBit passes this complete compiler version to
the official installer. The normal check, build, test, Pages, packaging, and
Copilot setup paths therefore use the same compiler.

GitHub also runs a `continue-on-error` latest-toolchain compatibility job.
Gitlink performs the equivalent probe by collecting every command's exit code,
printing a compatibility summary, and deliberately returning success. These
probes expose upcoming compiler changes without weakening the required pinned
gate.

To reproduce the required compiler on Unix:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh |
  bash -s -- "0.10.4+2cc641edf"
```

The checked-in module version is a local release candidate until its commit is
tagged, published to Mooncakes, and deployed. Do not infer the live release
version from `moon.mod`.
