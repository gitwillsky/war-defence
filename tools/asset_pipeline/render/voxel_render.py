"""体素模型 -> 多方向等距精灵。

坐标约定
  模型：+X 车头，+Y 侧向，+Z 向上，单位是体素；1 格 = 30 体素。
  世界：north = 屏幕正上方（网格 (-1,-1) 方向），east = 屏幕右上（网格 (1,-1)），朝向 0 = north，顺时针增加。
  投影：与引擎 IsoProjection 一致（60x30 菱形格）：east 每体素 1.414px，north 每体素 0.707px，向上每体素 1.22px。
渲染：2 倍超采样 + 逐体素 splat + 深度排序，再下采样。
着色按原版做法：每个体素自带法线下标（查 RA2/TS 法线表），按 n·光照 选 voxels.vpl 的明暗段，
再由 VPL 把基础色映射到该段的调色板色。调色板里的基础色只是暗部，直接用会整体发暗发脏。
法线表来自 OpenRA（make setup 下载到 third_party/）；缺失时退回用占据场梯度估算法线。
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

from ..formats.palette import Palette, TEAM_COLOR_RANGE
from ..formats.vxl import Hva, Vxl

VOXELS_PER_CELL = 30.0
PX_EAST = math.sqrt(2.0)          # 屏幕水平：沿 east 每体素
PX_NORTH = math.sqrt(2.0) / 2.0   # 屏幕垂直：沿 north 每体素
PX_UP = math.sqrt(2.0) * math.cos(math.radians(30.0))
SS = 1  # 超采样倍数（1 = 与原版一样逐像素、不做抗锯齿，画面锐利；2 会把相邻体素颜色混成一片发虚）
SPLAT = 1.5  # 每个体素 splat 的边长（像素/体素）
LIGHT = np.array([0.35, -0.45, 0.82])  # (north, east, up)，来自左上方
LIGHT = LIGHT / np.linalg.norm(LIGHT)
NORMALS_FILE = Path(__file__).resolve().parents[3] / "third_party" / "openra" / "VoxelNormalsPalette.cs"
# VPL 段号 = AMBIENT_SECTION + DIFFUSE_SECTIONS * max(n·L, 0)；背光面停在环境段
AMBIENT_SECTION = 4.0
DIFFUSE_SECTIONS = 19.0
_normal_tables: dict[int, np.ndarray] | None = None


def _load_normal_tables() -> dict[int, np.ndarray]:
    global _normal_tables
    if _normal_tables is None:
        _normal_tables = {}
        if NORMALS_FILE.exists():
            text = NORMALS_FILE.read_text(encoding="utf-8")
            for key, name in ((2, "TSNormals"), (4, "RA2Normals")):
                m = re.search(name + r"\s*=\s*\[(.*?)\]", text, re.S)
                if m:
                    nums = [float(x) for x in re.findall(r"-?\d+\.\d+", m.group(1))]
                    _normal_tables[key] = np.array(nums, dtype=np.float64).reshape(-1, 3)
    return _normal_tables


def parse_vpl(data: bytes) -> np.ndarray:
    """voxels.vpl：16 字节头（remap 起止、段数、保留）+ 768 字节调色板 + 段数×256 查找表。"""
    n = int.from_bytes(data[8:12], "little")
    return np.frombuffer(data, dtype=np.uint8, count=n * 256, offset=16 + 768).reshape(n, 256)


TEAM_TINT = {"allied": (0.22, 0.45, 1.0)}  # 队伍色相对亮度的 RGB 系数；苏军保持原版红


def team_palette(pal: Palette, team: str) -> np.ndarray:
    """返回 256×3 的 uint8 调色板。16–31 段是红色渐变（队伍色），按亮度重新着色成队伍色。"""
    arr = np.array(pal, dtype=np.uint8)
    tint = TEAM_TINT.get(team)
    if tint is not None:
        lo, hi = TEAM_COLOR_RANGE
        v = arr[lo : hi + 1].max(axis=1).astype(np.float32)
        arr[lo : hi + 1] = np.clip(v[:, None] * np.array(tint, dtype=np.float32), 0, 255).astype(np.uint8)
    return arr


@dataclass
class _Cloud:
    pos: np.ndarray      # N×3 模型空间位置（体素）
    normal: np.ndarray   # N×3
    color: np.ndarray    # N 调色板索引
    size: np.ndarray     # N 每个体素边长（模型空间体素数），决定 splat 大小


def _limb_normals(limb) -> np.ndarray:
    sx, sy, sz = limb.size
    occ = np.zeros((sx + 6, sy + 6, sz + 6), dtype=np.float32)
    v = limb.voxels
    occ[v[:, 0] + 3, v[:, 1] + 3, v[:, 2] + 3] = 1.0
    # 车体是表层壳体，单次 3x3x3 平滑的梯度很噪（顶面出现网状斑点），连做三遍得到平滑的曲面法线
    sm = occ
    for _ in range(3):
        acc = np.zeros_like(sm)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    acc += np.roll(sm, (dx, dy, dz), axis=(0, 1, 2))
        sm = acc / 27.0
    gx, gy, gz = np.gradient(sm)
    n = -np.stack([gx, gy, gz], axis=-1)[v[:, 0] + 3, v[:, 1] + 3, v[:, 2] + 3]
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
        table = _load_normal_tables().get(limb.normal_type)
        n = _limb_normals(limb)
        if table is not None:
            # 自带法线是量化的，相邻体素跳变大，单用会出现颗粒/条纹（看起来像半透明）；与平滑的几何法线平均
            n = n + table[np.clip(v[:, 4], 0, len(table) - 1)]
            n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-4)
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


def render_facings(cloud: _Cloud, pal: np.ndarray, facings: int, vpl: np.ndarray | None = None, pad: int = 4) -> tuple[list[Image.Image], tuple[int, int]]:
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
        images.append(_render_one(cloud, pal, h, width, height, anchor, vpl))
    return images, anchor


def _render_one(cloud: _Cloud, pal: np.ndarray, heading: float, width: int, height: int, anchor: tuple[int, int], vpl: np.ndarray | None) -> Image.Image:
    world, nrm = _rotate(cloud, heading)
    scr = _project(world)
    # 深度：越靠近镜头（south、向上）越大
    depth = -world[:, 0] * math.cos(math.radians(30)) + world[:, 2] * math.sin(math.radians(30))
    diffuse = np.clip(nrm @ LIGHT, 0.0, 1.0)
    if vpl is not None:
        section = np.clip(np.round(AMBIENT_SECTION + DIFFUSE_SECTIONS * diffuse), 0, len(vpl) - 1).astype(np.int32)
        rgb = pal[vpl[section, cloud.color]].astype(np.float32)
    else:
        rgb = np.clip(pal[cloud.color].astype(np.float32) * (0.7 + 0.5 * diffuse)[:, None], 0, 255)
    order = np.argsort(depth)
    px = np.round((scr[order, 0] + anchor[0]) * SS).astype(np.int32)
    py = np.round((scr[order, 1] + anchor[1]) * SS).astype(np.int32)
    rgb = rgb[order]
    # 体素投影后约 1.41px 宽；splat 再大会让近处体素糊住相邻细节（整体发虚），再小会漏出背后的体素
    side = np.maximum(SS, np.ceil(cloud.size[order] * SPLAT * SS)).astype(np.int32)
    buf = np.zeros((height * SS, width * SS, 4), dtype=np.float32)
    # 深度缓冲：splat 按偏移分多遍写，只靠排序的话后一遍的远处体素会盖住前一遍的近处体素（看起来像半透明）
    zbuf = np.full((height * SS, width * SS), -np.inf, dtype=np.float64)
    dsorted = depth[order]
    for dx in range(int(side.max())):
        for dy in range(int(side.max())):
            m = (dx < side) & (dy < side)
            x = np.clip(px[m] + dx - side[m] // 2, 0, width * SS - 1)
            y = np.clip(py[m] + dy - side[m] // 2, 0, height * SS - 1)
            d = dsorted[m]
            win = d >= zbuf[y, x]  # 同一遍内重复像素按排序后写者（更近）胜出
            x, y, d = x[win], y[win], d[win]
            buf[y, x, :3] = rgb[m][win]
            buf[y, x, 3] = 255.0
            zbuf[y, x] = d
    # 下采样：按 alpha 加权平均，避免边缘变黑
    a = buf[..., 3:4] / 255.0
    pm = buf[..., :3] * a
    pm = pm.reshape(height, SS, width, SS, 3).sum(axis=(1, 3))
    aa = a.reshape(height, SS, width, SS, 1).sum(axis=(1, 3))
    out = np.zeros((height, width, 4), dtype=np.uint8)
    out[..., :3] = np.where(aa > 0, pm / np.maximum(aa, 1e-6), 0).astype(np.uint8)
    out[..., 3] = np.clip(aa[..., 0] / (SS * SS) * 255.0 * 1.6, 0, 255).astype(np.uint8)
    _fill_pinholes(out)
    return Image.fromarray(out, "RGBA")


def _fill_pinholes(out: np.ndarray) -> None:
    """投影取整会在表面留下单像素空洞（露出背景），用四邻域都不透明的空像素的邻居均值补上。"""
    a = out[..., 3] > 0
    n = np.zeros(a.shape, dtype=np.int32)
    acc = np.zeros(out.shape[:2] + (3,), dtype=np.float32)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        sa = np.roll(a, (dy, dx), axis=(0, 1))
        n += sa
        acc += np.roll(out[..., :3], (dy, dx), axis=(0, 1)).astype(np.float32) * sa[..., None]
    hole = (~a) & (n == 4)
    out[hole, :3] = (acc[hole] / 4).astype(np.uint8)
    out[hole, 3] = 255
