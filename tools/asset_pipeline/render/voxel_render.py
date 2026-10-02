"""体素模型 -> 多方向等距精灵。

坐标约定
  模型：+X 车头，+Y 侧向，+Z 向上，单位是体素；1 格 = 30 体素。
  世界：north = 屏幕正上方（网格 (-1,-1) 方向），east = 屏幕右上（网格 (1,-1)），朝向 0 = north，顺时针增加。
  投影：与引擎 IsoProjection 一致（60x30 菱形格）：east 每体素 1.414px，north 每体素 0.707px，向上每体素 1.22px。
渲染：2 倍超采样 + 逐体素 splat + 深度排序，再下采样；法线取自体素占据场梯度，做简单方向光。
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
from PIL import Image

from ..formats.palette import Palette, TEAM_COLOR_RANGE
from ..formats.vxl import Hva, Vxl

VOXELS_PER_CELL = 30.0
PX_EAST = math.sqrt(2.0)          # 屏幕水平：沿 east 每体素
PX_NORTH = math.sqrt(2.0) / 2.0   # 屏幕垂直：沿 north 每体素
PX_UP = math.sqrt(2.0) * math.cos(math.radians(30.0))
SS = 2  # 超采样倍数
LIGHT = np.array([0.35, -0.45, 0.82])  # (north, east, up)，来自左上方


def team_palette(pal: Palette, team: str) -> np.ndarray:
    """返回 256×3 的 uint8 调色板。盟军把 16–31 段红色渐变换成蓝色（交换 R/B），苏军保持红色。"""
    arr = np.array(pal, dtype=np.uint8)
    if team == "allied":
        lo, hi = TEAM_COLOR_RANGE
        arr[lo : hi + 1] = arr[lo : hi + 1][:, ::-1]
    return arr


@dataclass
class _Cloud:
    pos: np.ndarray      # N×3 模型空间位置（体素）
    normal: np.ndarray   # N×3
    color: np.ndarray    # N 调色板索引
    size: np.ndarray     # N 每个体素边长（模型空间体素数），决定 splat 大小


def _limb_normals(limb) -> np.ndarray:
    sx, sy, sz = limb.size
    occ = np.zeros((sx + 2, sy + 2, sz + 2), dtype=np.float32)
    v = limb.voxels
    occ[v[:, 0] + 1, v[:, 1] + 1, v[:, 2] + 1] = 1.0
    sm = np.zeros_like(occ)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                sm += np.roll(occ, (dx, dy, dz), axis=(0, 1, 2))
    gx, gy, gz = np.gradient(sm / 27.0)
    n = -np.stack([gx, gy, gz], axis=-1)[v[:, 0] + 1, v[:, 1] + 1, v[:, 2] + 1]
    length = np.linalg.norm(n, axis=1, keepdims=True)
    n = np.where(length > 1e-4, n / np.maximum(length, 1e-4), np.array([0.0, 0.0, 1.0]))
    return n


def build_cloud(vxl: Vxl, hva: Hva | None, limb_indices: list[int] | None = None, frame: int = 0) -> _Cloud:
    pos_all, nrm_all, col_all, size_all = [], [], [], []
    for i, limb in enumerate(vxl.limbs):
        if limb_indices is not None and i not in limb_indices:
            continue
        if len(limb.voxels) == 0:
            continue
        v = limb.voxels
        span = (limb.max_bounds - limb.min_bounds) / np.array(limb.size, dtype=np.float64)
        p = limb.min_bounds + (v[:, :3] + 0.5) * span
        n = _limb_normals(limb)
        if hva is not None and i < hva.frames.shape[1]:
            m = hva.frames[min(frame, hva.frames.shape[0] - 1), i]
            rot, trans = m[:, :3], m[:, 3] * limb.scale
            p = p @ rot.T + trans
            n = n @ rot.T
        pos_all.append(p)
        nrm_all.append(n)
        col_all.append(v[:, 3])
        size_all.append(np.full(len(v), float(span.max())))
    return _Cloud(np.concatenate(pos_all), np.concatenate(nrm_all), np.concatenate(col_all), np.concatenate(size_all))


def _rotate(cloud: _Cloud, heading: float) -> tuple[np.ndarray, np.ndarray]:
    """模型空间 -> 世界 (north, east, up)。heading 为顺时针弧度（0 = north）。"""
    c, s = math.cos(heading), math.sin(heading)
    # 前向 f = c*N + s*E；右向 r = -s*N + c*E；模型 +Y 取为左侧
    def tf(a: np.ndarray) -> np.ndarray:
        x, y, z = a[:, 0], -a[:, 1], a[:, 2]  # y 取反：模型 +Y 为左，world 右向为正
        return np.stack([x * c - y * s, x * s + y * c, z], axis=1)
    return tf(cloud.pos), tf(cloud.normal)


def _project(world: np.ndarray) -> np.ndarray:
    n, e, u = world[:, 0], world[:, 1], world[:, 2]
    return np.stack([e * PX_EAST, -n * PX_NORTH - u * PX_UP], axis=1)


def render_facings(cloud: _Cloud, pal: np.ndarray, facings: int, pad: int = 4) -> tuple[list[Image.Image], tuple[int, int]]:
    """返回 (各方向图像列表, anchor)。所有帧尺寸一致，anchor 为模型原点（地面中心）在帧内的像素位置。"""
    headings = [i * math.tau / facings for i in range(facings)]
    projected = []
    for h in headings:
        w, _ = _rotate(cloud, h)
        projected.append(_project(w))
        projected[-1] = np.vstack([projected[-1], [[0.0, 0.0]]])  # 把原点也纳入包围盒
    lo = np.min([p.min(axis=0) for p in projected], axis=0)
    hi = np.max([p.max(axis=0) for p in projected], axis=0)
    width = int(math.ceil(hi[0] - lo[0])) + pad * 2
    height = int(math.ceil(hi[1] - lo[1])) + pad * 2
    width += width % 2
    height += height % 2
    anchor = (int(round(-lo[0])) + pad, int(round(-lo[1])) + pad)
    images = []
    for h in headings:
        images.append(_render_one(cloud, pal, h, width, height, anchor))
    return images, anchor


def _render_one(cloud: _Cloud, pal: np.ndarray, heading: float, width: int, height: int, anchor: tuple[int, int]) -> Image.Image:
    world, nrm = _rotate(cloud, heading)
    scr = _project(world)
    # 深度：越靠近镜头（south、向上）越大
    depth = -world[:, 0] * math.cos(math.radians(30)) + world[:, 2] * math.sin(math.radians(30))
    shade = 0.55 + 0.6 * np.clip(nrm @ LIGHT, 0.0, 1.0)
    rgb = np.clip(pal[cloud.color].astype(np.float32) * shade[:, None], 0, 255)
    order = np.argsort(depth)
    px = np.round((scr[order, 0] + anchor[0]) * SS).astype(np.int32)
    py = np.round((scr[order, 1] + anchor[1]) * SS).astype(np.int32)
    rgb = rgb[order]
    side = np.maximum(SS, np.ceil(cloud.size[order] * 2.0 * SS + 0.5)).astype(np.int32)
    buf = np.zeros((height * SS, width * SS, 4), dtype=np.float32)
    for dx in range(int(side.max())):
        for dy in range(int(side.max())):
            m = (dx < side) & (dy < side)
            x = np.clip(px[m] + dx - side[m] // 2, 0, width * SS - 1)
            y = np.clip(py[m] + dy - side[m] // 2, 0, height * SS - 1)
            buf[y, x, :3] = rgb[m]
            buf[y, x, 3] = 255.0
    # 下采样：按 alpha 加权平均，避免边缘变黑
    a = buf[..., 3:4] / 255.0
    pm = buf[..., :3] * a
    pm = pm.reshape(height, SS, width, SS, 3).sum(axis=(1, 3))
    aa = a.reshape(height, SS, width, SS, 1).sum(axis=(1, 3))
    out = np.zeros((height, width, 4), dtype=np.uint8)
    out[..., :3] = np.where(aa > 0, pm / np.maximum(aa, 1e-6), 0).astype(np.uint8)
    out[..., 3] = np.clip(aa[..., 0] / (SS * SS) * 255.0 * 1.6, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")
