# 素材管线设计

> 状态：草案 v0.1　|　上位文档：[high-level-design.md](high-level-design.md)

## 1. 原则

1. **离线转换，运行时零专有格式**：Godot 工程只读中立格式（PNG、OGG、JSON）。`.mix`、`.shp`、`.vxl`、`.pal`、`.ini`、`.csf` 等只出现在 `tools/` 里。
2. **manifest 是唯一契约**：管线产出"素材包"，引擎只依赖包内的 `manifest.json`。换一套素材 = 换一个包。
3. **优先复用开源工具**，缺口才自己写，且自写部分也放在 `tools/`，不污染引擎。
4. **可重复**：同样的输入跑同样的命令得到同样的输出；管线输出不入库。

## 2. 阶段

```
原始素材目录
  │  ① extract   解开 .mix（含嵌套）
  ▼
工作目录 build/extracted/        （原始 .shp .vxl .pal .tmp .ini .wav .csf …）
  │  ② decode    按格式解码
  ▼
中间表示（帧序列、体素、调色板、键值表）
  │  ③ convert   渲染/重采样/重映射
  ▼
  │  ④ pack      图集打包 + 写 manifest
  ▼
godot/packs/<pack_id>/            （PNG、OGG、JSON）
```

## 3. 输入与格式

| 原始内容 | 来源（该 mod 目录中） | 目标 |
|----------|----------------------|------|
| 归档 | `ra2.mix`、`ra2md.mix`、`Expandmd*.mix`、`Ecachemd*.mix`、`language*.mix` 等 | 解包得到下列文件 |
| 建筑、步兵、特效 | `.shp`（带 `.pal` 调色板） | 逐帧 PNG → 图集 |
| 载具、飞行器 | `.vxl` + `.hva`（体素模型 + 动画矩阵） | 渲染成 N 方向 PNG → 图集 |
| 地形图块 | `.tem` / `.sno` 等 `.tmp` 格式 | 图块 PNG 图集 |
| 调色板 | `.pal` | 用于 SHP 着色；队伍色对应的重映射段另行记录 |
| 规则数据 | `rulesmd.ini`、`artmd.ini` | JSON 草稿 → 人工校对入 `content/defs/` |
| 文本 | `.csf`（字符串表） | JSON 字符串表 |
| 音效/语音 | `audio.bag`/`.idx`、`.wav`（IMA ADPCM 等） | OGG |
| 音乐 | `THEME.MIX` 等 | OGG |
| 视频 | `.bik`、`movmd*.mix` | 第一版不处理 |
| 地图 | `.yrm`、`.map`（INI 风格） | 可选：只提取地形层做参考 |

## 4. 工具选型

> 以下是调研方向，**具体能否解开本 mod 的文件需要 M0 实测**（该 mod 的 `.mix` 可能带加密头或自定义文件名）。

| 任务 | 首选开源方案 | 备选 |
|------|-------------|------|
| 解包 MIX | [OpenRA](https://github.com/OpenRA/OpenRA)（GPLv3，C#）里的 MIX 读取与 `Utility` 命令行 | XCC Utilities（开源）；自写 Python 读取（格式在 ModEnc 有公开文档，支持 Blowfish/RSA 加密头与文件名 CRC 哈希） |
| SHP/PAL → PNG | OpenRA Utility 的 `--png`、`--remap` 等命令 | 自写 Python（SHP(TS) 格式简单，含 RLE 压缩帧） |
| VXL → 方向精灵 | 没有现成命令行导出；参考 OpenRA 的 `VxlReader`/`HvaReader` 实现 | 自写 Python：读 VXL/HVA → 正交投影 + 深度缓冲 → 渲染 N 方向 |
| INI → JSON | Python `configparser`（注意 RA2 的 `[section]` 继承、重复键等怪癖） | — |
| CSF → JSON | 自写（格式简单） | — |
| WAV/BAG → OGG | `ffmpeg`；BAG/IDX 解包参考开源实现 | — |
| 图集打包 | Python + Pillow | TexturePacker 等 |

**授权隔离**：OpenRA 等 GPL 工具只作为**独立外部进程**使用，不链接进工程，不把其代码拷进 `godot/`。它们的下载/构建放 `third_party/`（git 忽略）。

## 5. 素材包契约（manifest）

```
godot/packs/ra2-ta4/
├─ manifest.json
├─ sprites/
│  ├─ allied.prism_tower.png        # 图集
│  └─ allied.grizzly.png
├─ terrain/
├─ audio/
└─ text/strings.json
```

`manifest.json` 草案：

```json
{
  "pack_id": "ra2-ta4",
  "format_version": 1,
  "iso_tile": { "w": 60, "h": 30 },
  "palettes": {
    "unit": { "team_remap": [16, 31] }
  },
  "sprites": {
    "allied.grizzly": {
      "atlas": "sprites/allied.grizzly.png",
      "facings": 32,
      "anchor": [40, 52],
      "shadow": true,
      "team_mask": "sprites/allied.grizzly.mask.png",
      "anims": {
        "idle": { "frames": [0, 0], "fps": 1 },
        "move": { "frames": [0, 0], "fps": 1 },
        "fire": { "frames": [0, 3], "fps": 12 }
      },
      "frame_size": [96, 80]
    }
  },
  "sounds": {
    "sfx.prism_fire": { "file": "audio/prism_fire.ogg", "volume_db": 0 }
  },
  "strings": "text/strings.json"
}
```

要点：

- **ID 约定**：`<阵营或类别>.<名称>`，全小写，与 `content/defs/` 里 Definition 的 `sprite` 字段一致。
- **队伍色**：不把颜色烘进 PNG，而是另存蒙版，运行时着色，这样敌我可以用不同颜色区分。（RA2 的玩家色在调色板的一段索引上，具体段位待验证。）
- **阴影**：单独标记，由 `view` 层以半透明方式绘制。
- manifest 有 `format_version`，引擎启动时校验。

## 6. 目录与配置

```
tools/asset_pipeline/
├─ cli.py             # 入口：extract / decode / convert / pack / all
├─ config.toml        # 源目录、输出目录、要转换的 ID 清单
├─ mix/               # MIX 读取（若自写）
├─ formats/           # shp / vxl / hva / pal / csf / ini 解码
├─ render/            # VXL 方向渲染
├─ pack/              # 图集与 manifest 写出
└─ README.md
```

- 源目录默认 `./尤里科技时代4.0完结版`，可用环境变量 `WD_RAW_DIR` 覆盖。
- 只转换 `config.toml` 清单里列出的 ID，而不是全量转换，保持迭代快速。
- 入口：`make import-assets`（等价 `python3 tools/asset_pipeline/cli.py all`）。

## 7. M0 验证清单

| # | 检查项 | 通过标准 |
|---|--------|----------|
| 1 | 选定的开源工具能列出并提取 `ra2md.mix`、`Expandmd*.mix` 内文件 | 得到可读的 `.shp`/`.vxl`/`.pal`/`.ini` |
| 2 | 提取 `rulesmd.ini` 并解析出盟军防御建筑与苏军单位数值 | JSON 草稿可用 |
| 3 | 一个 SHP 建筑（光棱塔）正确着色并导出 PNG | 颜色与游戏内一致 |
| 4 | 一个 VXL 载具渲染出 ≥ 8 方向精灵 | 方向连续、无明显破面 |
| 5 | 一段音效转 OGG | 能在 Godot 播放 |
| 6 | 生成 manifest，Godot 里通过 `AssetProvider` 显示 1–2 个精灵 | 引擎代码里没有任何红警专有格式 |

若第 1 项失败，则优先排查：文件名哈希表是否缺失、加密头版本、嵌套 MIX 路径；必要时先自写 MIX 读取器。

## 8. M0 探测结果（2026-10-02）

**第 1 项已通过。** 没有可用的 dotnet，也无需引入 OpenRA 本体：对照 OpenRA 的开源 `MixFile.cs` / `BlowfishKeyProvider.cs` / `PackageEntry.cs`，在 `tools/asset_pipeline/mix/` 里用 Python 重新实现了 MIX 读取（依赖 `pycryptodome` 做 Blowfish）。目录下 22 个 `.mix` 的归类：

| 类型 | 文件 | 说明 |
|------|------|------|
| 明文新格式 | `ra2md`、`Ecachemd99`、`Expandmd01/02/03/97/98`、`NPSE2.0`、`language`、`langmd`、`mapsmd03`、`thememd` | 直接读 |
| Westwood 加密头 | `ra2`（21 项）、`multimd`（173）、`movmd03`（57） | 公开 RSA 公钥 + Blowfish，已解 |
| 旧格式 | `THEME.MIX` | 已解 |
| **7zAES 加密的 7z 包** | `Ecachemd01–04`、`Expandmd04`、`Expandmd96` | mod 作者的**密码保护**，连文件名都加密；**不尝试破解，直接跳过** |

要点：

- **美术资源在 `Ecachemd99.mix`**：自带本地文件名库，686 个文件，包含 `.shp`（建筑/图标）、`.vxl` + `.hva`（载具与炮塔）。
- **经典内嵌包在 `ra2.mix`**：`conquer.mix`、`generic.mix`、`isotemp.mix`、`isosnow.mix`、`isourb.mix`、`sidec01/02.mix` 等，需递归打开。
- 文件名需要靠"本地文件名库 + 已知名字表"反查哈希；`multimd`、`Expandmd02/03` 等无库的归档，后续从 `rulesmd.ini` / `artmd.ini` 里的 `Image=` 等字段生成候选名。
- 被密码保护的 7z 包里大概率是 mod 新增内容。这印证了 **D4**：第一版只用原版盟军单位。

剩余 M0 项：#2 `rulesmd.ini` → JSON；#3 SHP 解码 + 调色板；#4 VXL 方向渲染；#5 音频；#6 manifest 与 Godot 加载。
