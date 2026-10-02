"""audio.idx / audio.bag：RA2 的音效包。

idx：'GABA' | u32 版本 | u32 条目数 | 条目×N（36 字节：名称 16 | 偏移 u32 | 大小 u32 | 采样率 u32 | 标志 u32 | 块大小 u32）
bag：各条目数据首尾相接。标志 0x0C 表示单声道 16 位 IMA ADPCM（块大小 512，块头为 WAV 式 4 字节：预测值 + 索引），
此处只把它包成 WAV 容器（格式 0x11）交给 ffmpeg 解码，不自己实现解码器。
"""

from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

IMA_FLAGS = 0x0C


@dataclass
class BagEntry:
    name: str
    offset: int
    size: int
    rate: int
    flags: int
    chunk: int


class AudioBag:
    def __init__(self, idx_path: Path, bag_path: Path) -> None:
        data = idx_path.read_bytes()
        if data[:4] != b"GABA":
            raise ValueError("不是 audio.idx")
        (count,) = struct.unpack_from("<I", data, 8)
        self.entries: dict[str, BagEntry] = {}
        for i in range(count):
            base = 12 + i * 36
            name = data[base : base + 16].split(b"\0", 1)[0].decode("latin1").lower()
            off, size, rate, flags, chunk = struct.unpack_from("<5I", data, base + 16)
            self.entries[name] = BagEntry(name, off, size, rate, flags, chunk)
        self._bag = bag_path

    def has(self, name: str) -> bool:
        return name.lower() in self.entries

    def wav_bytes(self, name: str) -> bytes:
        e = self.entries[name.lower()]
        with open(self._bag, "rb") as f:
            f.seek(e.offset)
            payload = f.read(e.size)
        if not e.flags & 0x08:  # 未压缩 PCM：0x02 = 16 位，0x01 = 立体声
            ch, bits = (2 if e.flags & 0x01 else 1), (16 if e.flags & 0x02 else 8)
            fmt = struct.pack("<HHIIHH", 1, ch, e.rate, e.rate * ch * bits // 8, ch * bits // 8, bits)
            body = b"WAVEfmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(payload)) + payload
            return b"RIFF" + struct.pack("<I", len(body)) + body
        block = e.chunk or 512
        samples_per_block = (block - 4) * 2 + 1
        fmt = struct.pack("<HHIIHHHH", 0x11, 1, e.rate, e.rate * block // samples_per_block, block, 4, 2, samples_per_block)
        fact = struct.pack("<I", e.size // block * samples_per_block)
        body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"fact" + struct.pack("<I", len(fact)) + fact
        body += b"data" + struct.pack("<I", len(payload)) + payload
        return b"RIFF" + struct.pack("<I", len(body)) + body
