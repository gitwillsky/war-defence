"""RA2 风格 INI 解析：节名/键名不区分大小写，分号后为注释，重复节后者覆盖前者的同名键。"""

from __future__ import annotations

import re

Ini = dict[str, dict[str, str]]


def parse_ini(text: str) -> Ini:
    out: Ini = {}
    cur: dict[str, str] | None = None
    for raw in text.replace("\r", "").split("\n"):
        line = raw.split(";", 1)[0].strip()
        if not line:
            continue
        m = re.match(r"\[(.+?)\]", line)
        if m:
            cur = out.setdefault(m.group(1).lower(), {})
        elif cur is not None and "=" in line:
            k, v = line.split("=", 1)
            cur[k.strip().lower()] = v.strip()
    return out


def parse_ini_bytes(data: bytes) -> Ini:
    for enc in ("utf-8-sig", "gbk", "latin-1"):
        try:
            return parse_ini(data.decode(enc))
        except UnicodeDecodeError:
            continue
    raise ValueError("无法解码 INI")
