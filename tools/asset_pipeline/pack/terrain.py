"""地形素材：地面、路面、水面、岸线自动拼接、山体岩石。"""

from __future__ import annotations

import numpy as np
from PIL import Image

from ..formats.tmp_ts import parse_tmp_ts
from . import spec_v1 as spec
from .sources import Sources

# 8 个邻格（格坐标偏移），bit i 表示"该邻格是水"。引擎按 manifest 里同一张表读取。
NEIGHBORS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]


# 调色板 17、19 号是地图编辑器的格角标记（洋红/粉），游戏里不应出现
EDITOR_MARKS = (17, 19)


def _rgba(tile, pal: np.ndarray) -> Image.Image:
    px = np.frombuffer(tile.pixels, dtype=np.uint8).reshape(tile.height, tile.width)
    rgba = np.zeros((tile.height, tile.width, 4), dtype=np.uint8)
    rgba[..., :3] = pal[px]
    rgba[..., 3] = np.where((px == 0) | np.isin(px, EDITOR_MARKS), 0, 255)
    return Image.fromarray(rgba, "RGBA")


def tiles_of(src: Sources, name: str, pal: np.ndarray) -> list[Image.Image]:
    return [_rgba(t, pal) for t in parse_tmp_ts(src.need(name)) if t]


def _water_mask(img: Image.Image) -> np.ndarray:
    a = np.asarray(img, dtype=np.int32)
    return (a[..., 2] > a[..., 0] + 25) & (a[..., 3] > 0)


def _sector_fractions(img: Image.Image) -> list[float]:
    """菱形外圈按 8 个邻格方向分区，各区水像素占比。"""
    water = _water_mask(img)
    alpha = np.asarray(img)[..., 3] > 0
    h, w = water.shape
    ys, xs = np.mgrid[0:h, 0:w]
    dx, dy = (xs - w / 2 + 0.5) / (w / 2), (ys - h / 2 + 0.5) / (h / 2)
    ring = alpha & (np.abs(dx) + np.abs(dy) > 0.45)
    # 邻格 (ox,oy) 在归一化屏幕坐标里的方向是 (ox-oy, ox+oy)
    dirs = np.array([(ox - oy, ox + oy) for ox, oy in NEIGHBORS], dtype=np.float64)
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    proj = dx[..., None] * dirs[:, 0] + dy[..., None] * dirs[:, 1]
    sector = proj.argmax(axis=-1)
    out = []
    for i in range(8):
        m = ring & (sector == i)
        out.append(float(water[m].mean()) if m.any() else 0.0)
    return out


def build_shore(src: Sources, pal: np.ndarray) -> tuple[list[Image.Image], list[int]]:
    """返回 (去重后的图块帧, 长度 256 的 mask->帧号 表；全陆地 mask 为 -1)。"""
    cands: list[tuple[Image.Image, list[float]]] = []
    for name in spec.SHORE_FILES:
        for img in tiles_of(src, name, pal):
            if img.size != (60, 30):
                continue
            frac = _sector_fractions(img)
            if 0.02 < sum(frac) / 8 < 0.98:
                cands.append((img, frac))
    chosen: dict[int, int] = {}
    frames: list[Image.Image] = []
    table: list[int] = []
    for mask in range(256):
        if mask == 0:
            table.append(-1)
            continue
        want = np.array([(mask >> i) & 1 for i in range(8)], dtype=np.float64)
        best = min(range(len(cands)), key=lambda k: float(np.abs(np.array(cands[k][1]) - want).sum()))
        if best not in chosen:
            chosen[best] = len(frames)
            frames.append(cands[best][0])
        table.append(chosen[best])
    return frames, table


def rock_frame(src: Sources, name: str, pal: np.ndarray) -> tuple[Image.Image, tuple[float, float]]:
    tile = [t for t in parse_tmp_ts(src.need(name)) if t][0]
    img = _rgba(tile, pal)
    return img, (-tile.origin_x + tile.diamond_w / 2, -tile.origin_y + tile.diamond_h / 2)
