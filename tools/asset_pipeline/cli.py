#!/usr/bin/env python3
"""素材管线入口。设计见 docs/design/asset-pipeline.md。

用法：
  python3 tools/asset_pipeline/cli.py mix-list [mix 文件 ...]   列出归档条目与可解析的文件名
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from asset_pipeline.mix import MixFile  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_RAW = ROOT / "尤里科技时代4.0完结版"


def raw_dir() -> Path:
    return Path(os.environ.get("WD_RAW_DIR", DEFAULT_RAW))


def cmd_mix_list(args: argparse.Namespace) -> int:
    paths = [Path(p) for p in args.files] or sorted(
        p for p in raw_dir().iterdir() if p.suffix.lower() == ".mix"
    )
    for path in paths:
        try:
            with MixFile(path) as mix:
                kind = "old" if mix.is_old_format else "new"
                enc = " encrypted" if mix.encrypted else ""
                names = mix.local_names()
                print(f"{path.name:18} {kind}{enc:10} entries={len(mix.entries):5} local_db_names={len(names)}")
        except Exception as e:  # 非 MIX（如 7z）等
            print(f"{path.name:18} SKIP ({type(e).__name__}: {e})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("mix-list", help="列出 MIX 归档")
    p.add_argument("files", nargs="*")
    p.set_defaults(func=cmd_mix_list)
    p = sub.add_parser("all", help="完整管线（尚未实现）")
    p.set_defaults(func=lambda _a: print("完整管线尚未实现，见 docs/design/asset-pipeline.md") or 1)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
