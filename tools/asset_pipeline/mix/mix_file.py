"""MIX 归档读取（TS / RA2 / YR 格式，兼容 C&C 旧格式）。

布局：
  新格式  u16 0 | u16 flags(0x2=加密) | [80 字节密钥块] | 头部(u16 数量, u32 数据大小, N×12 字节条目) | 数据
  旧格式  头部直接从 0 开始
条目：u32 哈希 | u32 偏移(相对数据区) | u32 长度
"""

from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

from . import header_crypto
from .name_hash import hash_classic, hash_crc32

ENTRY_SIZE = 12
LOCAL_DB_NAME = "local mix database.dat"


@dataclass(frozen=True)
class MixEntry:
    hash: int
    offset: int  # 相对文件起点的绝对偏移
    length: int


class NotMixError(ValueError):
    """文件不是 MIX（例如 mod 作者改名伪装的 7z 包）。"""


_SEVEN_ZIP_MAGIC = b"7z\xbc\xaf\x27\x1c"


class MixFile:
    def __init__(self, path: Path):
        self.path = Path(path)
        self._f = self.path.open("rb")
        self.encrypted = False
        self.is_old_format = False
        self.entries: list[MixEntry] = []
        self._parse()
        self._by_hash = {e.hash: e for e in self.entries}

    def close(self) -> None:
        self._f.close()

    def __enter__(self) -> "MixFile":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def _parse(self) -> None:
        head = self._f.read(4)
        if head + self._f.read(2) == _SEVEN_ZIP_MAGIC:
            raise NotMixError("7z archive (mod-protected, not a MIX)")
        self._f.seek(4)
        first, flags = struct.unpack("<HH", head)
        if first != 0:
            self.is_old_format = True
            self._read_plain_header(0)
        elif flags & 0x2:
            self.encrypted = True
            self._read_encrypted_header(4)
        else:
            self._read_plain_header(4)

    def _read_plain_header(self, offset: int) -> None:
        self._f.seek(offset)
        count, _size = struct.unpack("<HI", self._f.read(6))
        raw = self._f.read(count * ENTRY_SIZE)
        self._set_entries(raw, count, offset + 6 + count * ENTRY_SIZE)

    def _read_encrypted_header(self, offset: int) -> None:
        self._f.seek(offset)
        key = header_crypto.decrypt_blowfish_key(self._f.read(header_crypto.KEY_BLOCK_SIZE))
        enc_start = offset + header_crypto.KEY_BLOCK_SIZE
        first_block = header_crypto.decrypt_blocks(key, self._f.read(8))
        (count,) = struct.unpack("<H", first_block[:2])
        block_count = (13 + count * ENTRY_SIZE) // 8
        self._f.seek(enc_start)
        plain = header_crypto.decrypt_blocks(key, self._f.read(block_count * 8))
        raw = plain[6 : 6 + count * ENTRY_SIZE]
        self._set_entries(raw, count, enc_start + block_count * 8)

    def _set_entries(self, raw: bytes, count: int, data_start: int) -> None:
        self.data_start = data_start
        for h, off, length in struct.iter_unpack("<III", raw):
            self.entries.append(MixEntry(h, data_start + off, length))

    def read(self, entry: MixEntry) -> bytes:
        self._f.seek(entry.offset)
        return self._f.read(entry.length)

    def find(self, name: str) -> MixEntry | None:
        """按文件名查找；两种哈希都试，因为新旧格式都可能出现。"""
        return self._by_hash.get(hash_crc32(name)) or self._by_hash.get(hash_classic(name))

    def local_names(self) -> list[str]:
        """读 XCC 本地文件名库（若归档里带了）。"""
        entry = self.find(LOCAL_DB_NAME)
        if entry is None:
            return []
        data = self.read(entry)
        (count,) = struct.unpack_from("<i", data, 48)
        names = data[52:].split(b"\0")[:count]
        return [n.decode("ascii", errors="replace") for n in names]
