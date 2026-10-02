"""MIX 内文件名哈希。MIX 不存文件名，只存名字的 32 位哈希。

两种算法（实现依据 OpenRA 的开源实现，格式见 ModEnc）：
  classic  Red Alert / Tiberian Dawn
  crc32    Tiberian Sun / Red Alert 2 / Yuri's Revenge（本项目使用）
"""

from __future__ import annotations

import struct
import zlib


def hash_classic(name: str) -> int:
    data = name.upper().encode("ascii", errors="replace")
    data += b"\0" * (-len(data) % 4)
    result = 0
    for (word,) in struct.iter_unpack("<I", data):
        result = (((result << 1) | (result >> 31)) + word) & 0xFFFFFFFF
    return result


def hash_crc32(name: str) -> int:
    data = bytearray(name.upper().encode("ascii", errors="replace"))
    length = len(data)
    rest = length % 4
    if rest:
        # 补齐到 4 的倍数：先补余数长度，再用该余数块首字节填充
        data.append(rest)
        data += bytes([data[length - rest]]) * (3 - rest)
    return zlib.crc32(bytes(data)) & 0xFFFFFFFF
