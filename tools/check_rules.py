#!/usr/bin/env python3
"""项目规则静态检查。

规则：
  R1  单个源文件不得超过 2000 行（硬约束）；超过 1500 行给出告警。
  R2  分层依赖：engine 不得引用 game / app；game 不得引用 app。
  R3  engine 内只有 engine/assets 可以读取素材包（packs/）。

用法：python3 tools/check_rules.py        # 检查全部
退出码：存在违规则为 1，否则 0。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HARD_LIMIT = 2000
WARN_LIMIT = 1500

# 受行数约束的源文件类型
SOURCE_SUFFIXES = {".gd", ".py", ".gdshader", ".tscn", ".tres"}
# 不检查的目录
SKIP_DIRS = {".git", ".godot", ".venv", "third_party", "build", "packs", "__pycache__", "尤里科技时代4.0完结版"}

# 分层规则：目录 -> 禁止出现在其源码中的 res:// 前缀
FORBIDDEN_REFS = {
    "godot/src/engine": ["res://src/game", "res://src/app"],
    "godot/src/game": ["res://src/app"],
}
# 只有 engine/assets 允许出现的字符串
ASSETS_ONLY_PATTERNS = [re.compile(r"res://packs/")]
ASSETS_DIR = "godot/src/engine/assets"


def iter_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        files.append(path)
    return files


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8", errors="replace") as f:
        return sum(1 for _ in f)


def check_line_limits(files: list[Path], errors: list[str], warnings: list[str]) -> None:
    for path in files:
        n = count_lines(path)
        rel = path.relative_to(ROOT)
        if n > HARD_LIMIT:
            errors.append(f"[R1] {rel}: {n} 行，超过硬约束 {HARD_LIMIT}")
        elif n > WARN_LIMIT:
            warnings.append(f"[R1] {rel}: {n} 行，接近上限，建议拆分")


def check_layering(files: list[Path], errors: list[str]) -> None:
    for path in files:
        if path.suffix != ".gd":
            continue
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        for layer, banned in FORBIDDEN_REFS.items():
            if rel.startswith(layer + "/"):
                for ref in banned:
                    if ref in text:
                        errors.append(f"[R2] {rel}: 不允许引用 {ref}")
        if rel.startswith("godot/src/") and not rel.startswith(ASSETS_DIR + "/"):
            for pat in ASSETS_ONLY_PATTERNS:
                if pat.search(text):
                    errors.append(f"[R3] {rel}: 只有 engine/assets 可以直接访问素材包")


def main() -> int:
    files = iter_files()
    errors: list[str] = []
    warnings: list[str] = []
    check_line_limits(files, errors, warnings)
    check_layering(files, errors)

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"检查 {len(files)} 个文件：{len(errors)} 个错误，{len(warnings)} 个告警")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
