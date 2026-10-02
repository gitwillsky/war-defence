"""TMP(TS) 地形图块读取（Tiberian Sun / RA2）。

头：u32 模板宽 | u32 模板高 | i32 图块宽 | i32 图块高 | 偏移表（宽×高 个 u32，0 = 空）。
每块：20 字节头 | extra x y w h (i32×4) | u32 flags | 12 字节 | 菱形像素（行宽 4,8,… 再递减，每行居中）| 深度数据。
只取菱形主体；cliff 等 extra 数据对平地图块无用，忽略。
"""

from __future__ import annotations

import struct
from dataclasses import dataclass


@dataclass
class TmpTile:
    width: int
    height: int
    pixels: bytes  # 宽×高 索引色，0 = 透明


def parse_tmp_ts(data: bytes) -> list[TmpTile | None]:
    tw, th, w, h = struct.unpack_from("<IIii", data, 0)
    offsets = struct.unpack_from(f"<{tw * th}I", data, 16)
    tiles: list[TmpTile | None] = []
    for off in offsets:
        if off == 0:
            tiles.append(None)
            continue
        pos = off + 20 + 16 + 4 + 12
        px = bytearray(w * h)
        row_w = 4
        for j in range(h):
            start = j * w + (w - row_w) // 2
            px[start : start + row_w] = data[pos : pos + row_w]
            pos += row_w
            row_w += (1 if j < h // 2 - 1 else -1) * 4
        tiles.append(TmpTile(w, h, bytes(px)))
    return tiles
