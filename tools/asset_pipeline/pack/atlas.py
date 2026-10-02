"""把等大小的 RGBA 帧排成网格图集。"""

from __future__ import annotations

from PIL import Image


def pack_grid(frames: list[Image.Image], columns: int) -> tuple[Image.Image, tuple[int, int]]:
    fw, fh = frames[0].size
    rows = (len(frames) + columns - 1) // columns
    sheet = Image.new("RGBA", (fw * columns, fh * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % columns) * fw, (i // columns) * fh))
    return sheet, (fw, fh)


def pick_columns(count: int, frame_w: int, max_width: int = 4096) -> int:
    return max(1, min(count, max_width // frame_w))
