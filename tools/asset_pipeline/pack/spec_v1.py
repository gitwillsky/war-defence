"""v1 素材包清单：每个 id 取自哪些原始文件。契约见 docs/design/asset-pipeline.md §9。

选用雪地主题（snow）：该 mod 里只有它的建筑 SHP 与地形图块都能在已挂载的归档中找到。
"""

from __future__ import annotations

UNIT_PAL = "unitsno.pal"
TERRAIN_PAL = "isosno.pal"

# id, shp 名, 占地宽, 占地高
BUILDINGS = [
    ("allied.construction_yard", "gacnst", 4, 4),
    ("allied.power_plant", "gapowr", 2, 2),
    ("allied.ore_refinery", "garefn", 4, 3),
    ("allied.barracks", "gapile", 3, 2),
    ("allied.war_factory", "gaweap", 5, 3),
    ("allied.pillbox", "gapill", 1, 1),
    ("allied.prism_tower", "gapris", 1, 1),
    ("allied.patriot", "nasam", 1, 1),
    ("allied.grand_cannon", "gagcan", 2, 2),
]

# id, 队伍, [(体素文件名, 肢体下标或 None)]
VOXELS = [
    ("allied.ore_miner", "allied", [("cmin", None)]),
    ("allied.grand_cannon.turret", "allied", [("gtgcantur", None), ("gtgcanbarl", None)]),
    ("allied.patriot.turret", "allied", [("sam", None)]),
    ("soviet.rhino", "soviet", [("htnk", None), ("htnktur", None), ("htnkbarl", None)]),
    ("soviet.apocalypse", "soviet", [("mtnk", None), ("mtnktur", None)]),
    ("soviet.v3", "soviet", [("v3", None)]),
    ("soviet.kirov", "soviet", [("zep", [0])]),
]
VOXEL_FACINGS = 16

# 步兵：id, shp, 队伍, 画布内脚下锚点, 阴影色索引；动画 = (名, 起始帧, 帧数, 每方向步长, fps, 循环)
INFANTRY = [
    (
        "soviet.conscript", "swainb", "soviet", (39, 50), 12,
        [
            ("idle", 0, 1, 1, 1, True),
            ("move", 8, 6, 6, 8, True),
            ("fire", 164, 6, 6, 10, False),
            ("die", 134, 15, 0, 12, False),
        ],
    ),
]

# id, shp, 调色板, fps
EFFECTS = [
    ("fx.explosion_large", "explolrg", "anim.pal", 20),
    ("fx.explosion_small", "piffpiff", "anim.pal", 20),
    ("fx.lightning_strike", "twlt026", "anim.pal", 14),
]

# 建造栏图标：sprite id -> cameo shp
ICONS = {
    "icon.allied.power_plant": "powricon",
    "icon.allied.ore_refinery": "reficon",
    "icon.allied.barracks": "brrkicon",
    "icon.allied.war_factory": "gwepicon",
    "icon.allied.pillbox": "pillicon",
    "icon.allied.prism_tower": "prisicon",
    "icon.allied.patriot": "samicon",
    "icon.allied.grand_cannon": "gcanicon",
}

# 地面：id, 图块文件, 模板内第几块。第 0 个是主地面，其余是少量点缀变体
TERRAIN = [
    ("terrain.ground", "clear01.sno", 0), ("terrain.ground_1", "rough01.sno", 0), ("terrain.ground_2", "rough01.sno", 1),
    ("terrain.ground_3", "rough02.sno", 0), ("terrain.ground_4", "rough03.sno", 0), ("terrain.ground_5", "rough04.sno", 0),
]

# 地表物件（树）：id, shp 名；用 TERRAIN_PAL
PROPS = [(f"prop.tree_{i + 1}", name) for i, name in enumerate(["tree02", "tree03", "tree05", "tree06", "tree08", "tree12", "tree17", "tree20"])]

# 界面素材（sidebar.pal）：id, shp 名, 取哪些帧（None = 全部）
UI_PAL = "sidebar.pal"
UI = [
    ("ui.side_top", "side1", None), ("ui.side_slot", "side2", None), ("ui.side_bottom", "side3", None),
    ("ui.radar", "radar", [32]), ("ui.tabs", "tabs", None),
    ("ui.tab_structure", "tab00", None), ("ui.tab_defense", "tab01", None),
    ("ui.tab_infantry", "tab02", None), ("ui.tab_vehicle", "tab03", None),
    ("ui.power", "power", None), ("ui.power_pip", "powerp", None),
    ("ui.btn_repair", "repair", None), ("ui.btn_sell", "sell", None), ("ui.credits", "credits", None),
]

# 音效：manifest id -> audio.bag 里的条目名（多个 = 随机变体）。名称取自 soundmd.ini 的对应声音定义
SOUNDS = {
    "sfx.fire.pillbox": ["bpilatta", "bpilattb", "bpilattc"],
    "sfx.fire.prism": ["bpriat1a"],
    "sfx.fire.patriot": ["bpatatta"],
    "sfx.fire.grand_cannon": ["bgraatta"],
    "sfx.fire.conscript": ["iconatta", "iconattb", "iconattc"],
    "sfx.fire.rhino": ["vrhiatta", "vrhiattb"],
    "sfx.fire.apocalypse": ["vapoat1a"],
    "sfx.fire.v3": ["vv3latta", "vv3lattb"],
    "sfx.fire.kirov": ["vkirbo2a", "vkirbo2b"],
    "sfx.explosion.small": ["gexp01a", "gexp06a"],
    "sfx.explosion.large": ["gexp14a", "gexp14b", "gexpapoa"],
    "sfx.die.building": ["bgendiea", "bgendieb", "bgendiec"],
    "sfx.die.power_plant": ["bpowdiea"],
    "sfx.die.infantry": ["icondia"],
    "sfx.ui.click": ["umenucl1"],
    "sfx.ui.build_start": ["uqeue"],
    "sfx.ui.place": ["uplace"],
    "sfx.ui.sell": ["uselbuil"],
    "sfx.ui.base_attack": ["ubase"],
    "sfx.ui.warning": ["uwarning"],
    "sfx.win": ["awin01a"],
    "sfx.lose": ["vflosea"],
}
# 音乐：manifest id -> 归档里的 wav
MUSIC = {"music.power": "power.wav", "music.intro": "intro.wav"}
