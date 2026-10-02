"""从 VFS 取素材并转成 RGBA 帧（SHP、体素、图标、地形）。"""

from __future__ import annotations

import numpy as np
from PIL import Image

from ..formats.palette import Palette, parse_pal
from ..formats.shp_ts import Shp, parse_shp_ts
from ..formats.tmp_ts import parse_tmp_ts
from ..formats.vxl import parse_hva, parse_vxl
from ..mix.vfs import MixVfs
from ..render.voxel_render import _Cloud, build_cloud, render_facings, team_palette

SHADOW_ALPHA = 90


class Sources:
    def __init__(self, vfs: MixVfs) -> None:
        self.vfs = vfs
        self._pal: dict[tuple[str, str], Palette] = {}

    def need(self, name: str) -> bytes:
        data = self.vfs.read(name)
        if data is None:
            raise FileNotFoundError(name)
        return data

    def palette(self, name: str, team: str | None = None) -> Palette:
        key = (name, team or "")
        if key not in self._pal:
            pal = parse_pal(self.need(name))
            if team:
                pal = [tuple(int(c) for c in row) for row in team_palette(pal, team)]
            self._pal[key] = pal
        return self._pal[key]

    def shp(self, name: str) -> Shp:
        return parse_shp_ts(self.need(name))

    def shp_frame(self, shp: Shp, index: int, pal: Palette, shadow_idx: int | None = None) -> Image.Image:
        """整幅画布 RGBA；shadow_idx 对应的像素改画成半透明黑。"""
        canvas = Image.new("RGBA", (shp.width, shp.height), (0, 0, 0, 0))
        f = shp.frames[index]
        if f.empty:
            return canvas
        px = np.frombuffer(f.pixels, dtype=np.uint8).reshape(f.height, f.width)
        rgba = np.zeros((f.height, f.width, 4), dtype=np.uint8)
        rgba[..., :3] = np.array(pal, dtype=np.uint8)[px]
        rgba[..., 3] = np.where(px == 0, 0, 255)
        if shadow_idx is not None:
            sh = px == shadow_idx
            rgba[sh] = (0, 0, 0, SHADOW_ALPHA)
        canvas.paste(Image.fromarray(rgba, "RGBA"), (f.x, f.y))
        return canvas

    def shadow_layer(self, shp: Shp, index: int) -> Image.Image:
        canvas = Image.new("RGBA", (shp.width, shp.height), (0, 0, 0, 0))
        f = shp.frames[index]
        if f.empty:
            return canvas
        px = np.frombuffer(f.pixels, dtype=np.uint8).reshape(f.height, f.width)
        rgba = np.zeros((f.height, f.width, 4), dtype=np.uint8)
        rgba[..., 3] = np.where(px != 0, SHADOW_ALPHA, 0)
        canvas.paste(Image.fromarray(rgba, "RGBA"), (f.x, f.y))
        return canvas

    def voxel_cloud(self, parts: list[tuple[str, list[int] | None]]) -> _Cloud:
        clouds = []
        for name, limbs in parts:
            vxl = parse_vxl(self.need(name + ".vxl"))
            hva_data = self.vfs.read(name + ".hva")
            hva = parse_hva(hva_data) if hva_data else None
            clouds.append(build_cloud(vxl, hva, limbs))
        return _Cloud(
            np.concatenate([c.pos for c in clouds]),
            np.concatenate([c.normal for c in clouds]),
            np.concatenate([c.color for c in clouds]),
            np.concatenate([c.size for c in clouds]),
        )

    def voxel_facings(self, parts, facings: int, team: str, pal_name: str = "unitsno.pal"):
        pal = np.array(self.palette(pal_name, team), dtype=np.uint8)
        return render_facings(self.voxel_cloud(parts), pal, facings)

    def icon(self, name: str) -> Image.Image:
        shp = self.shp(name)
        return self.shp_frame(shp, 0, self.palette("cameo.pal"))

    def terrain_tile(self, name: str, pal_name: str, index: int = 0) -> Image.Image:
        tile = [t for t in parse_tmp_ts(self.need(name)) if t][index]
        pal = self.palette(pal_name)
        px = np.frombuffer(tile.pixels, dtype=np.uint8).reshape(tile.height, tile.width)
        rgba = np.zeros((tile.height, tile.width, 4), dtype=np.uint8)
        rgba[..., :3] = np.array(pal, dtype=np.uint8)[px]
        rgba[..., 3] = np.where(px == 0, 0, 255)
        return Image.fromarray(rgba, "RGBA")
