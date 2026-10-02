"""SHP(TS) 精灵解码（Tiberian Sun / Red Alert 2 使用）。

文件：u16 0 | u16 宽 | u16 高 | u16 帧数 | 帧头 × 帧数(24 字节) | 帧数据
帧头：u16 x, y, w, h | u8 压缩格式 | 11 字节(对齐/雷达色/保留) | u32 数据偏移
格式：3 = 逐行 RLE-零；2 = 逐行带长度前缀的原始数据；0/1 = 整块原始数据
索引 0 为透明。解码依据 OpenRA 的开源 ShpTSLoader。
"""

from __future__ import annotations

import struct
from dataclasses import dataclass


@dataclass
class ShpFrame:
    x: int
    y: int
    width: int
    height: int
    pixels: bytes  # width*height 个调色板索引；空帧为 b""

    @property
    def empty(self) -> bool:
        return not self.pixels


@dataclass
class Shp:
    width: int
    height: int
    frames: list[ShpFrame]


def _decode_rle_zero(line: bytes, width: int) -> bytes:
    out = bytearray()
    i = 0
    while i < len(line) and len(out) < width:
        b = line[i]
        i += 1
        if b == 0:
            out += b"\0" * line[i]  # 0 后跟透明像素个数
            i += 1
        else:
            out.append(b)
    return bytes(out[:width]).ljust(width, b"\0")


def _decode_frame(data: bytes, x: int, y: int, w: int, h: int, fmt: int, offset: int) -> ShpFrame:
    if offset == 0 or w == 0 or h == 0:
        return ShpFrame(x, y, w, h, b"")
    rows: list[bytes] = []
    pos = offset
    for _ in range(h):
        if fmt == 3:
            (length,) = struct.unpack_from("<H", data, pos)
            rows.append(_decode_rle_zero(data[pos + 2 : pos + length], w))
            pos += length
        elif fmt == 2:
            (length,) = struct.unpack_from("<H", data, pos)
            rows.append(data[pos + 2 : pos + 2 + w].ljust(w, b"\0"))
            pos += length
        else:
            rows.append(data[pos : pos + w])
            pos += w
    return ShpFrame(x, y, w, h, b"".join(rows))


def parse_shp_ts(data: bytes) -> Shp:
    zero, width, height, count = struct.unpack_from("<HHHH", data, 0)
    if zero != 0:
        raise ValueError("不是 SHP(TS)：首个 u16 应为 0")
    frames = []
    for i in range(count):
        base = 8 + i * 24
        x, y, w, h = struct.unpack_from("<HHHH", data, base)
        fmt = data[base + 8]
        (offset,) = struct.unpack_from("<I", data, base + 20)
        frames.append(_decode_frame(data, x, y, w, h, fmt, offset))
    return Shp(width, height, frames)
