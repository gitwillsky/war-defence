"""音效与音乐：audio.bag 条目 / 归档里的 wav -> OGG。"""

from __future__ import annotations

import subprocess
from pathlib import Path

from ..formats.audio_bag import AudioBag
from ..mix.vfs import MixVfs
from . import spec_v1 as spec


def _to_ogg(wav: bytes, dest: Path, quality: str = "4") -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    # ffmpeg 自带的 vorbis 编码器是实验性的，需要 -strict -2；声道数固定 2 以保证可编码
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", "pipe:0", "-c:a", "vorbis", "-strict", "-2", "-ac", "2", "-q:a", quality, str(dest)]
    r = subprocess.run(cmd, input=wav, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg 失败：{r.stderr.decode(errors='replace')[:200]}")


def build_audio(raw_dir: Path, out: Path) -> dict:
    sounds: dict[str, dict] = {}
    bag = AudioBag(raw_dir / "audio.idx", raw_dir / "audio.bag")
    for sid, names in spec.SOUNDS.items():
        files = []
        for n in names:
            if not bag.has(n):
                continue
            rel = f"audio/{n}.ogg"
            if not (out / rel).exists():
                _to_ogg(bag.wav_bytes(n), out / rel)
            files.append(rel)
        if files:
            sounds[sid] = {"files": files, "volume_db": 0}
    with MixVfs(raw_dir) as vfs:
        for sid, name in spec.MUSIC.items():
            data = vfs.read(name)
            if data is None:
                continue
            rel = f"audio/{sid}.ogg"
            if not (out / rel).exists():
                _to_ogg(data, out / rel, "3")
            sounds[sid] = {"files": [rel], "volume_db": -6, "music": True}
    return sounds
