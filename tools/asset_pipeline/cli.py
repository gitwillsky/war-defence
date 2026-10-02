#!/usr/bin/env python3
"""素材管线入口。设计见 docs/design/asset-pipeline.md。

用法：
  cli.py mix-list [mix 文件 ...]                   列出归档条目与可解析的文件名
  cli.py shp-export NAME.shp [PALETTE.pal] [--out D]  从素材中取出 SHP，按调色板导出逐帧 PNG
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from asset_pipeline.formats.palette import parse_pal  # noqa: E402
from asset_pipeline.formats.png_export import export_frames  # noqa: E402
from asset_pipeline.formats.shp_ts import parse_shp_ts  # noqa: E402
from asset_pipeline.mix import MixFile  # noqa: E402
from asset_pipeline.mix.vfs import MixVfs  # noqa: E402

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


def cmd_shp_export(args: argparse.Namespace) -> int:
    with MixVfs(raw_dir()) as vfs:
        shp_data, pal_data = vfs.read(args.shp), vfs.read(args.palette)
    if shp_data is None or pal_data is None:
        print(f"找不到 {args.shp if shp_data is None else args.palette}")
        return 1
    shp = parse_shp_ts(shp_data)
    paths = export_frames(shp, parse_pal(pal_data), Path(args.out), Path(args.shp).stem)
    print(f"{args.shp}: 画布 {shp.width}x{shp.height}，{len(shp.frames)} 帧 -> {args.out}")
    return 0 if paths else 1


def cmd_all(args: argparse.Namespace) -> int:
    from asset_pipeline.pack.builder import build_pack

    manifest = build_pack(raw_dir(), Path(args.out))
    print(f"素材包已生成：{len(manifest['sprites'])} 个精灵 -> {args.out}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("mix-list", help="列出 MIX 归档")
    p.add_argument("files", nargs="*")
    p.set_defaults(func=cmd_mix_list)
    p = sub.add_parser("shp-export", help="导出 SHP 为 PNG")
    p.add_argument("shp")
    p.add_argument("palette", nargs="?", default="unittem.pal", help="默认 unittem.pal（建筑/单位用 unit 调色板，iso*.pal 是地形用的）")
    p.add_argument("--out", default=str(ROOT / "build" / "shp"))
    p.set_defaults(func=cmd_shp_export)
    p = sub.add_parser("all", help="生成 v1 素材包到 godot/packs/ra2-ta4")
    p.add_argument("--out", default=str(ROOT / "godot" / "packs" / "ra2-ta4"))
    p.set_defaults(func=cmd_all)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
