"""按 spec_v1 生成素材包（PNG 图集 + manifest.json）。"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from ..mix.vfs import MixVfs
from . import spec_v1 as spec
from .atlas import pack_grid, pick_columns
from .audio import build_audio
from .sources import Sources


def _write(out: Path, sid: str, frames: list[Image.Image], anchor: tuple[float, float], facings: int, anims: dict) -> dict:
    cols = pick_columns(len(frames), frames[0].width)
    sheet, (fw, fh) = pack_grid(frames, cols)
    rel = f"sprites/{sid}.png"
    (out / "sprites").mkdir(parents=True, exist_ok=True)
    sheet.save(out / rel, optimize=True)
    return {"atlas": rel, "frame_size": [fw, fh], "columns": cols, "anchor": [anchor[0], anchor[1]], "facings": facings, "anims": anims}


def _anim(start: int, count: int, fps: int = 1, loop: bool = True) -> dict:
    return {"start": start, "count": count, "fps": fps, "loop": loop}


def _building(src: Sources, out: Path, sid: str, name: str, fw: int, fh: int) -> dict:
    shp = src.shp(name + ".shp")
    pal = src.palette(spec.UNIT_PAL, "allied")
    frames = []
    for i in range(min(2, len(shp.frames))):
        img = src.shp_frame(shp, i, pal)
        if len(shp.frames) > i + 3:
            img = Image.alpha_composite(src.shadow_layer(shp, i + 3), img)
        frames.append(img)
    f0 = shp.frames[0]
    anchor = (shp.width / 2, f0.y + f0.height - (fw + fh) * 7.5)
    anims = {"idle": _anim(0, 1)}
    if len(frames) > 1:
        anims["damaged"] = _anim(1, 1)
    return _write(out, sid, frames, anchor, 1, anims)


def _infantry(src: Sources, out: Path, spec_row: tuple) -> tuple[str, dict]:
    sid, name, team, anchor, shadow, anims_spec = spec_row
    shp, pal = src.shp(name + ".shp"), src.palette(spec.UNIT_PAL, team)
    facings, frames, anims = 8, [], {}
    for aname, start, count, step, fps, loop in anims_spec:
        anims[aname] = _anim(len(frames), count, fps, loop)
        for f in range(facings):
            # SHP 方向序：0=西北起逆时针；引擎序：0=北起顺时针
            src_dir = (7 - f) % 8
            for k in range(count):
                frames.append(src.shp_frame(shp, start + src_dir * step + k, pal, shadow))
    return sid, _write(out, sid, frames, anchor, facings, anims)


def _effect(src: Sources, out: Path, sid: str, name: str, pal_name: str, fps: int) -> dict:
    shp, pal = src.shp(name + ".shp"), src.palette(pal_name)
    frames = [src.shp_frame(shp, i, pal) for i in range(len(shp.frames))]
    return _write(out, sid, frames, (shp.width / 2, shp.height / 2), 1, {"idle": _anim(0, 1), "play": _anim(0, len(frames), fps, False)})


def build_pack(raw_dir: Path, out: Path, pack_id: str = "ra2-ta4") -> dict:
    out.mkdir(parents=True, exist_ok=True)
    sprites: dict[str, dict] = {}
    with MixVfs(raw_dir) as vfs:
        src = Sources(vfs)
        for sid, name, fw, fh in spec.BUILDINGS:
            sprites[sid] = _building(src, out, sid, name, fw, fh)
        for sid, team, parts in spec.VOXELS:
            imgs, anchor = src.voxel_facings(parts, spec.VOXEL_FACINGS, team)
            sprites[sid] = _write(out, sid, imgs, anchor, spec.VOXEL_FACINGS, {"idle": _anim(0, 1), "move": _anim(0, 1)})
        for row in spec.INFANTRY:
            sid, meta = _infantry(src, out, row)
            sprites[sid] = meta
        for sid, name, pal, fps in spec.EFFECTS:
            sprites[sid] = _effect(src, out, sid, name, pal, fps)
        for sid, name in spec.ICONS.items():
            img = src.icon(name + ".shp")
            sprites[sid] = _write(out, sid, [img], (img.width / 2, img.height / 2), 1, {"idle": _anim(0, 1)})
        for sid, name, idx in spec.TERRAIN:
            img = src.terrain_tile(name, spec.TERRAIN_PAL, idx)
            sprites[sid] = _write(out, sid, [img], (img.width / 2, img.height / 2), 1, {"idle": _anim(0, 1)})
        for sid, name in spec.PROPS:
            shp = src.shp(name + ".sno")
            img = src.shp_frame(shp, 0, src.palette(spec.TERRAIN_PAL))
            f0 = shp.frames[0]
            sprites[sid] = _write(out, sid, [img], (shp.width / 2, f0.y + f0.height - 6), 1, {"idle": _anim(0, 1)})
        for sid, name, only in spec.UI:
            shp, pal = src.shp(name + ".shp"), src.palette(spec.UI_PAL)
            idxs = only if only is not None else list(range(len(shp.frames)))
            frames = [src.shp_frame(shp, i, pal) for i in idxs]
            sprites[sid] = _write(out, sid, frames, (0, 0), 1, {"idle": _anim(0, 1)})
        sounds = build_audio(raw_dir, out)
    manifest = {"pack_id": pack_id, "format_version": 1, "iso_tile": {"w": 60, "h": 30}, "sprites": sprites, "sounds": sounds}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    return manifest
