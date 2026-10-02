"""把索引色帧合成到整幅画布并导出 PNG。"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from .palette import Palette
from .shp_ts import Shp


def frame_to_image(shp: Shp, index: int, pal: Palette) -> Image.Image:
    """还原为 shp 整幅画布大小的 RGBA 图（帧按其偏移摆放，索引 0 透明）。"""
    canvas = Image.new("RGBA", (shp.width, shp.height), (0, 0, 0, 0))
    frame = shp.frames[index]
    if frame.empty:
        return canvas
    rgba = bytearray()
    for idx in frame.pixels:
        rgba += bytes((*pal[idx], 0 if idx == 0 else 255))
    img = Image.frombytes("RGBA", (frame.width, frame.height), bytes(rgba))
    canvas.paste(img, (frame.x, frame.y))
    return canvas


def export_frames(shp: Shp, pal: Palette, out_dir: Path, stem: str) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for i in range(len(shp.frames)):
        path = out_dir / f"{stem}_{i:03d}.png"
        frame_to_image(shp, i, pal).save(path)
        paths.append(path)
    return paths
