"""建筑的附加部件：底座（BibShape）、建造动画（Buildup）、常驻动画层（ActiveAnim*/UnderDoorAnim）、开火动画（SpecialAnim）。

原版建筑只有主体 SHP 是不完整的：门坡、涡轮、灯光等都在单独的 SHP 里，由 artmd.ini 描述。
所有部件 SHP 与主体共用画布中心，所以锚点 = 主体锚点按画布尺寸差平移。
帧布局：前半是画面（正常 + 受损段），后半是对应的阴影帧。
"""

from __future__ import annotations

from typing import Callable

from PIL import Image

from ..formats.ini_file import Ini

# 常驻动画层的键，按绘制顺序
ACTIVE_KEYS = ("underdooranim", "activeanim", "activeanimtwo", "activeanimthree", "activeanimfour")
BUILDUP_FPS = 1  # 建造动画由引擎按建造进度取帧，帧率无意义


def _fps(sec: dict[str, str]) -> int:
    # artmd 的 Rate 越大越快；按观感换算成每秒帧数
    return max(4, round(int(sec.get("rate", "200")) / 25))


def _loop_range(sec: dict[str, str], total: int) -> tuple[int, int]:
    start = int(sec.get("loopstart", sec.get("start", "0")))
    end = int(sec.get("loopend", sec.get("end", str(start + 1))))
    end = min(end, total)
    return start, max(end - start, 1)


def _frames(src, shp, pal, idxs: list[int], with_shadow: bool) -> list[Image.Image]:
    half = len(shp.frames) // 2
    out = []
    for i in idxs:
        img = src.shp_frame(shp, i, pal)
        if with_shadow and i + half < len(shp.frames):
            img = Image.alpha_composite(src.shadow_layer(shp, i + half), img)
        out.append(img)
    return out


def _crop(frames: list[Image.Image], anchor: tuple[float, float]) -> tuple[list[Image.Image], tuple[float, float]]:
    """裁到所有帧的并集包围盒，图集小很多。"""
    box = None
    for f in frames:
        b = f.getbbox()
        if b is None:
            continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        return frames[:1], anchor
    return [f.crop(box) for f in frames], (anchor[0] - box[0], anchor[1] - box[1])


def build_parts(src, art: Ini, art_name: str, sid: str, base_size: tuple[int, int], base_anchor: tuple[float, float], pal, write: Callable) -> tuple[dict, dict]:
    """返回 (parts 元数据, {部件精灵 id: manifest 条目})。"""
    sec = art.get(art_name, {})
    parts: dict = {}
    sprites: dict[str, dict] = {}

    def load(name: str):
        data = src.vfs.read(name.lower() + ".shp")
        return src.shp(name.lower() + ".shp") if data else None

    def anchor_for(shp) -> tuple[float, float]:
        return (base_anchor[0] + (shp.width - base_size[0]) / 2, base_anchor[1] + (shp.height - base_size[1]) / 2)

    bib_name = sec.get("bibshape")
    bib = load(bib_name) if bib_name else None
    if bib is not None:
        idxs = [0, 1] if len(bib.frames) >= 4 else [0]
        frames, anchor = _crop(_frames(src, bib, pal, idxs, True), anchor_for(bib))
        anims = {"idle": {"start": 0, "count": 1, "fps": 1, "loop": True}}
        if len(frames) > 1:
            anims["damaged"] = {"start": 1, "count": 1, "fps": 1, "loop": True}
        pid = sid + ".bib"
        sprites[pid] = write(pid, frames, anchor, anims)
        parts["bib"] = pid

    mk_name = sec.get("buildup")
    mk = load(mk_name) if mk_name else None
    if mk is not None:
        n = max(len(mk.frames) // 2, 1)
        frames, anchor = _crop(_frames(src, mk, pal, list(range(n)), True), anchor_for(mk))
        pid = sid + ".buildup"
        sprites[pid] = write(pid, frames, anchor, {"idle": {"start": 0, "count": 1, "fps": 1, "loop": True}, "build": {"start": 0, "count": n, "fps": BUILDUP_FPS, "loop": False}})
        parts["buildup"] = pid

    overlays = []
    # SpecialAnim 含义因建筑而异（矿场卸矿、光棱塔蓄能）；只有"开火前播动画"的建筑才当开火动画用
    keys = ACTIVE_KEYS + (("specialanim",) if sec.get("isanimdelayedfire", "no").lower() in ("yes", "true") else ())
    for key in keys:
        name = sec.get(key)
        anim_sec = art.get(name.lower(), {}) if name else {}
        image = anim_sec.get("image", name) if name else None
        shp = load(image) if image else None
        if shp is None:
            continue
        shadow = anim_sec.get("shadow", "no").lower() in ("yes", "true")
        half = len(shp.frames) // 2 if shadow else len(shp.frames)
        start, count = _loop_range(anim_sec, half)
        idxs = list(range(start, start + count))
        anims = {"idle": {"start": 0, "count": count, "fps": _fps(anim_sec), "loop": key != "specialanim"}}
        dname = sec.get(key + "damaged")
        dsec = art.get(dname.lower(), {}) if dname else {}
        if dsec and dsec.get("image", dname).lower() == image.lower():
            ds, dc = _loop_range(dsec, half)
            anims["damaged"] = {"start": len(idxs), "count": dc, "fps": _fps(dsec), "loop": key != "specialanim"}
            idxs += list(range(ds, ds + dc))
        frames, anchor = _crop(_frames(src, shp, pal, idxs, shadow), anchor_for(shp))
        pid = f"{sid}.{key}"
        sprites[pid] = write(pid, frames, anchor, anims)
        # specialanim 是开火时播一次的动画（如光棱塔蓄能），其余常驻循环
        overlays.append({"sprite": pid, "on": "fire"} if key == "specialanim" else {"sprite": pid})
    if overlays:
        parts["overlays"] = overlays
    return parts, sprites
