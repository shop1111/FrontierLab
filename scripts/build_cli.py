#!/usr/bin/env python3
"""Build and smoke-check a local FrontierLab native CLI artifact."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "_dist"
EXECUTABLE = "frontierlab.exe" if os.name == "nt" else "frontierlab"
SOURCE = (
    ROOT
    / "_build"
    / "native"
    / "release"
    / "build"
    / "cmd"
    / "main"
    / ("main.exe" if os.name == "nt" else "main")
)


def main() -> int:
    subprocess.run(
        [
            "moon",
            "build",
            "cmd/main",
            "--target",
            "native",
            "--release",
            "--deny-warn",
        ],
        cwd=ROOT,
        check=True,
    )
    if not SOURCE.is_file():
        raise FileNotFoundError(f"MoonBit native executable not found: {SOURCE}")
    DIST.mkdir(exist_ok=True)
    target = DIST / EXECUTABLE
    shutil.copy2(SOURCE, target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    checksum = target.with_name(f"{target.name}.sha256")
    checksum.write_text(f"{digest}  {target.name}\n", encoding="utf-8")
    probe = subprocess.run(
        [str(target), "--version"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    if "FrontierLab 0.7.0 candidate" not in probe.stdout:
        raise RuntimeError(f"Unexpected version output: {probe.stdout!r}")
    print(f"Built {target}")
    print(f"SHA256 {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
