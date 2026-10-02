"""调色板（.pal）：256 色 × RGB，每分量 6 位（0..63），索引 0 为透明。"""

from __future__ import annotations

Palette = list[tuple[int, int, int]]

# 玩家色（队伍色）所在的调色板索引段。已用光棱塔 + unittem.pal 验证：16..31 是红色渐变
TEAM_COLOR_RANGE = (16, 31)


def parse_pal(data: bytes) -> Palette:
    if len(data) < 768:
        raise ValueError(f"调色板应为 768 字节，实际 {len(data)}")
    pal: Palette = []
    for i in range(256):
        r, g, b = (min(63, v) for v in data[i * 3 : i * 3 + 3])
        # 6 位扩展到 8 位，白色保持 255
        pal.append(tuple((v << 2) | (v >> 4) for v in (r, g, b)))  # type: ignore[arg-type]
    return pal
