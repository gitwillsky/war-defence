"""TMP(TS) 地形图块读取（Tiberian Sun / RA2）。

头：u32 模板宽 | u32 模板高 | i32 图块宽 | i32 图块高 | 偏移表（宽×高 个 u32，0 = 空）。
每块：20 字节头 | extra x y w h (i32×4) | u32 flags | 12 字节 | 菱形像素（行宽 4,8,… 再递减，每行居中）| 深度数据 | extra 像素 | extra 深度。
flags&1 时带 extra（悬崖立面、岩石等超出菱形的部分）：画布取菱形与 extra 的并集，
origin_x/origin_y 是画布左上角相对菱形左上角的偏移（通常为负）。
"""

from __future__ import annotations

import struct
from dataclasses import dataclass


@dataclass
class TmpTile:
    width: int       # 画布宽高（含 extra）
    height: int
    pixels: bytes    # 宽×高 索引色，0 = 透明
    origin_x: int = 0
    origin_y: int = 0
    diamond_w: int = 60
    diamond_h: int = 30


def parse_tmp_ts(data: bytes) -> list[TmpTile | None]:
    tw, th, w, h = struct.unpack_from("<IIii", data, 0)
    offsets = struct.unpack_from(f"<{tw * th}I", data, 16)
    diamond_bytes = sum(min(4 + 4 * j, 4 + 4 * (h - 1 - j)) for j in range(h))
    tiles: list[TmpTile | None] = []
    for k, off in enumerate(offsets):
        if off == 0:
            tiles.append(None)
            continue
        u, v = k % tw, k // tw
        ex, ey, ew, eh, flags = struct.unpack_from("<iiiiI", data, off + 20)
        ex -= (u - v) * w // 2
        ey -= (u + v) * h // 2
        bx, by, bw, bh = 0, 0, w, h
        if flags & 1:
            x0, y0 = min(0, ex), min(0, ey)
            x1, y1 = max(w, ex + ew), max(h, ey + eh)
            bx, by, bw, bh = x0, y0, x1 - x0, y1 - y0
        px = bytearray(bw * bh)
        pos = off + 20 + 16 + 4 + 12
        row_w = 4
        for j in range(h):
            start = (j - by) * bw + (w - row_w) // 2 - bx
            px[start : start + row_w] = data[pos : pos + row_w]
            pos += row_w
            row_w += (1 if j < h // 2 - 1 else -1) * 4
        if flags & 1:
            pos += diamond_bytes  # 跳过菱形深度
            for j in range(eh):
                start = (j + ey - by) * bw + ex - bx
                for i in range(ew):
                    b = data[pos]
                    pos += 1
                    if b:
                        px[start + i] = b
        tiles.append(TmpTile(bw, bh, bytes(px), bx, by, w, h))
    return tiles
