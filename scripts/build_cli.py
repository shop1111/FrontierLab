#!/usr/bin/env python3
"""Build and smoke-check the native FrontierLab command-line tools.

Builds `frontierlab` (the trace CLI, from cmd/main) and `frontierlab-instrument`
(the mark inserter, from the separate instrument/ module) into _dist/, each with
a SHA256 file, and checks that both start.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "_dist"
SUFFIX = ".exe" if os.name == "nt" else ""
VERSION = "1.0.0"


def build(module: Path, package: str, name: str, probe: list[str], expect: str) -> None:
    subprocess.run(
        ["moon", "build", package, "--target", "native", "--release", "--deny-warn"],
        cwd=module,
        check=True,
    )
    source = module / "_build" / "native" / "release" / "build" / package / f"main{SUFFIX}"
    if not source.is_file():
        raise FileNotFoundError(f"MoonBit native executable not found: {source}")
    DIST.mkdir(exist_ok=True)
    target = DIST / f"{name}{SUFFIX}"
    shutil.copy2(source, target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_name(f"{target.name}.sha256").write_text(
        f"{digest}  {target.name}\n", encoding="utf-8"
    )
    output = subprocess.run(
        [str(target), *probe], cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout
    if expect not in output:
        raise RuntimeError(f"Unexpected output from {target.name}: {output!r}")
    print(f"Built {target}")
    print(f"SHA256 {digest}")


def main() -> int:
    build(ROOT, "cmd/main", "frontierlab", ["--version"], f"FrontierLab {VERSION}")
    build(
        ROOT / "instrument",
        "main",
        "frontierlab-instrument",
        ["--help"],
        "frontierlab-instrument <file.mbt> --fn NAME",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
