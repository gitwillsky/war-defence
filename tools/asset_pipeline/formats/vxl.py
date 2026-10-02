"""VXL 体素模型与 HVA 动画矩阵读取（Tiberian Sun / Red Alert 2）。

VXL：
  头(802)  : 16 名 | u32 | u32 肢体数 | u32 肢体数 | u32 体大小 | 2 字节调色板重映射范围 | 768 调色板
  肢体头   : 肢体数 × 28 字节（16 字节名 + 12 保留）
  体       : 体大小字节，含各肢体的列起止偏移表与 span 数据
  肢体尾   : 肢体数 × 92 字节：span 起/止/数据偏移(u32×3) | scale(f32) | 3×4 变换 | min(3f) | max(3f) | sx sy sz normal_type
span：每列若干段 [skip_z u8][count u8][count×(color u8, normal u8)][count u8]；起止偏移为 0xFFFFFFFF 表示空列。
HVA：16 名 | u32 帧数 | u32 肢体数 | 肢体名(16×N) | 每帧每肢体 12 个 f32（3×4 矩阵，行优先）。
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field

import numpy as np

HEADER_SIZE = 802
LIMB_HEADER_SIZE = 28
LIMB_TAILER_SIZE = 92
EMPTY = 0xFFFFFFFF


@dataclass
class VxlLimb:
    name: str
    scale: float
    transform: np.ndarray  # 3x4，VXL 内置的默认变换
    min_bounds: np.ndarray
    max_bounds: np.ndarray
    size: tuple[int, int, int]
    voxels: np.ndarray  # N×5：x y z color normal


@dataclass
class Vxl:
    limbs: list[VxlLimb] = field(default_factory=list)


@dataclass
class Hva:
    section_names: list[str]
    frames: np.ndarray  # [帧, 肢体, 3, 4]


def _cstr(b: bytes) -> str:
    return b.split(b"\0", 1)[0].decode("ascii", errors="replace")


def parse_vxl(data: bytes) -> Vxl:
    magic = data[:15]
    if magic != b"Voxel Animation":
        raise ValueError("不是 VXL")
    _u, n_limbs, _n2, body_size = struct.unpack_from("<IIII", data, 16)
    body_start = HEADER_SIZE + n_limbs * LIMB_HEADER_SIZE
    tailer_start = body_start + body_size
    vxl = Vxl()
    for i in range(n_limbs):
        name = _cstr(data[HEADER_SIZE + i * LIMB_HEADER_SIZE : HEADER_SIZE + i * LIMB_HEADER_SIZE + 16])
        t = tailer_start + i * LIMB_TAILER_SIZE
        span_start, span_end, span_data = struct.unpack_from("<III", data, t)
        (scale,) = struct.unpack_from("<f", data, t + 12)
        mat = np.array(struct.unpack_from("<12f", data, t + 16), dtype=np.float64).reshape(3, 4)
        mn = np.array(struct.unpack_from("<3f", data, t + 64), dtype=np.float64)
        mx = np.array(struct.unpack_from("<3f", data, t + 76), dtype=np.float64)
        sx, sy, sz, _normal_type = struct.unpack_from("<4B", data, t + 88)
        vox = _read_voxels(data, body_start, span_start, span_end, span_data, sx, sy, sz)
        vxl.limbs.append(VxlLimb(name, scale, mat, mn, mx, (sx, sy, sz), vox))
    return vxl


def _read_voxels(data: bytes, body: int, starts_off: int, ends_off: int, data_off: int, sx: int, sy: int, sz: int) -> np.ndarray:
    out: list[tuple[int, int, int, int, int]] = []
    for y in range(sy):
        for x in range(sx):
            col = x + y * sx
            (start,) = struct.unpack_from("<I", data, body + starts_off + col * 4)
            if start == EMPTY:
                continue
            pos = body + data_off + start
            z = 0
            while z < sz:
                skip, count = data[pos], data[pos + 1]
                pos += 2
                z += skip
                for k in range(count):
                    out.append((x, y, z + k, data[pos + k * 2], data[pos + k * 2 + 1]))
                pos += count * 2 + 1  # 末尾重复的 count 字节
                z += count
    return np.array(out, dtype=np.int32).reshape(-1, 5)


def parse_hva(data: bytes) -> Hva:
    n_frames, n_sections = struct.unpack_from("<II", data, 16)
    names = [_cstr(data[24 + i * 16 : 24 + i * 16 + 16]) for i in range(n_sections)]
    off = 24 + n_sections * 16
    mats = np.frombuffer(data, dtype="<f4", count=n_frames * n_sections * 12, offset=off)
    return Hva(names, mats.reshape(n_frames, n_sections, 3, 4).astype(np.float64))
