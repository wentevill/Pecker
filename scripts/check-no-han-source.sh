#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import sys

roots = [
    Path("Pecker"),
    Path("Sources"),
    Path("Shared"),
    Path("PeckerLiveActivity"),
    Path("PeckerTests"),
    Path("Tests"),
    Path("project.yml"),
    Path("Package.swift"),
]
extensions = {".swift", ".yml", ".yaml", ".pbxproj", ".plist"}

def is_han(char):
    code = ord(char)
    return (
        0x3400 <= code <= 0x4DBF
        or 0x4E00 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF
        or 0x20000 <= code <= 0x2A6DF
        or 0x2A700 <= code <= 0x2B73F
        or 0x2B740 <= code <= 0x2B81F
        or 0x2B820 <= code <= 0x2CEAF
    )

def files():
    for root in roots:
        if not root.exists():
            continue
        candidates = [root] if root.is_file() else root.rglob("*")
        for path in candidates:
            if not path.is_file() or path.suffix not in extensions:
                continue
            if ".lproj" in path.parts:
                continue
            if path.parts[0] in {"docs", "releases"}:
                continue
            yield path

failures = []
for path in files():
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if any(is_han(char) for char in line):
            failures.append(f"{path}:{number}:{line}")

if failures:
    print("\n".join(failures))
    sys.exit(1)
PY
