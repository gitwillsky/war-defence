"""虚拟文件系统：把原始素材目录里的散文件与多层 MIX 归档合成一个按文件名查找的整体。

优先级与游戏一致：散文件 > 后加载的归档覆盖先加载的。嵌套 MIX（如 ra2.mix 里的 conquer.mix）
按"已知名字表"自动挂载，因为 MIX 只存哈希，必须有名字才能反查。
"""

from __future__ import annotations

from pathlib import Path

from .mix_file import MixEntry, MixFile, NotMixError

# 内嵌 MIX 的常见名字（RA2 / YR）。找不到的会被忽略。
KNOWN_NESTED_MIXES = """
conquer.mix conqmd.mix local.mix localmd.mix cache.mix cachemd.mix generic.mix genermd.mix
isotemp.mix isosnow.mix isourb.mix isolun.mix isodes.mix isoubn.mix isogen.mix
isotemmd.mix isosnomd.mix isourbmd.mix isolunmd.mix isodesmd.mix isoubnmd.mix isogenmd.mix
temperat.mix snow.mix urban.mix lunar.mix desert.mix urbann.mix tem.mix sno.mix urb.mix lun.mix des.mix ubn.mix
sidec01.mix sidec02.mix sidenc01.mix sidenc02.mix sidec01md.mix sidec02md.mix
load.mix loadmd.mix ntrl.mix ntrlmd.mix npatch.mix mapsmd03.mix maps01.mix maps02.mix
audio.mix audiomd.mix keyboard.mix theme.mix thememd.mix
""".split()

# 加载顺序：靠后的优先级更高（与游戏的覆盖规则一致）
_LOAD_ORDER = [
    "ra2.mix", "ra2md.mix", "langmd.mix", "language.mix", "multimd.mix",
    "Expandmd01.mix", "Expandmd02.mix", "Expandmd03.mix", "Expandmd97.mix", "Expandmd98.mix",
    "Ecachemd99.mix",
]


class MixVfs:
    def __init__(self, raw_dir: Path, extra_names: list[str] | None = None):
        self.raw_dir = Path(raw_dir)
        self._loose = {p.name.lower(): p for p in self.raw_dir.iterdir() if p.is_file()}
        self._mixes: list[MixFile] = []
        self._extra_names = list(extra_names or [])
        self._mount_top_level()

    def _mount_top_level(self) -> None:
        for name in _LOAD_ORDER:
            path = self.raw_dir / name
            if path.exists():
                self._mount(MixFile(path))

    def _mount(self, mix: MixFile) -> None:
        self._mixes.append(mix)
        candidates = KNOWN_NESTED_MIXES + [n for n in mix.local_names() if n.lower().endswith(".mix")]
        for name in dict.fromkeys(candidates):
            entry = mix.find(name)
            if entry is None:
                continue
            try:
                self._mount(mix.open_nested(entry, name))
            except (NotMixError, ValueError, OSError):
                pass  # 不是 MIX 或头部损坏，忽略

    def close(self) -> None:
        for m in self._mixes:
            m.close()

    def __enter__(self) -> "MixVfs":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def locate(self, name: str) -> tuple[MixFile, MixEntry] | None:
        for mix in reversed(self._mixes):  # 后挂载的优先
            entry = mix.find(name)
            if entry is not None:
                return mix, entry
        return None

    def read(self, name: str) -> bytes | None:
        loose = self._loose.get(name.lower())
        if loose is not None:
            return loose.read_bytes()
        hit = self.locate(name)
        return hit[0].read(hit[1]) if hit else None

    def mounted(self) -> list[str]:
        return [m.name for m in self._mixes]
