# AGENTS.md

给 AI 编码助手和新成员的工程指南。开工前先读 [docs/design/high-level-design.md](docs/design/high-level-design.md)。

## 项目是什么

用 **Godot 4 + 纯 GDScript** 做的 2.5D（等距）**红警 2 题材基地防守塔防**。引擎层通用，红警内容全在游戏层和素材包里。第一版只做盟军。

## 硬约束（违反即不合格）

1. **单个源文件 ≤ 2000 行**。超过 1500 行就该拆。`make check` 会检查。
2. **分层依赖只能向下**：`app → game → engine`。`engine` 里禁止出现 `res://src/game`、`res://src/app`，禁止红警专有名词、硬编码单位名或素材路径。
3. **素材与逻辑分离**：逻辑代码只用字符串 asset id（如 `"allied.prism_tower"`）；只有 `engine/assets` 可以读 `res://packs/`；`.mix/.shp/.vxl/.ini` 等专有格式只能出现在 `tools/`。
4. **全 GDScript，必须写静态类型**（变量、参数、返回值）。
5. **原版素材不入库**。`尤里科技时代4.0完结版/`、`godot/packs/`、`build/`、`third_party/` 已在 `.gitignore`，不要提交，也不要把里面的内容拷进别处。
6. 前期**不写单元测试**，但保持可测性：`sim` 及以下不依赖 Node，只用 `RefCounted` 和 Packed 数组。

## 命令

```
make help           列出命令
make check          静态规则检查（行数、分层依赖）—— 提交前必跑
make format         格式化 GDScript（需 pip install gdtoolkit）
make run            运行游戏（默认 /Applications/Godot.app，可用 GODOT=路径 覆盖）
make editor         用编辑器打开工程
make import-assets  运行素材管线（M0 之后可用）
```

## 目录

```
docs/design/        设计文档（改行为先改文档）
tools/              离线工具，不进 Godot 工程：check_rules.py、asset_pipeline/
godot/              Godot 工程根（project.godot 在此）
  src/engine/       通用引擎：core data assets spatial sim nav combat economy view audio input ui
  src/game/         红警塔防内容与规则：rules waves content superweapons hud levels
  src/app/          启动、场景装配、主菜单
  content/          数据定义 JSON（defs/ 单位建筑武器…，levels/ 关卡与波次）
  scenes/           .tscn 场景
  packs/            素材包（管线生成，git 忽略）
```

各模块职责与依赖关系见设计文档 §4。新增模块前先看它该放哪一层。

## 代码约定

- 文件名 `snake_case.gd`；`class_name` 用 `PascalCase`，且全局唯一。一个文件一个主要类型。
- 模块内文件按职责命名，如 `flow_field.gd`、`iso_projection.gd`、`event_bus.gd`；不要 `utils.gd`、`manager.gd` 这类杂物间。
- 跨模块通信优先用 **EventBus 事件**、**Command 命令**、**接口基类**；不要直接读写别的模块的内部字段。
- 玩家输入只产生 Command，由模拟层下一 tick 执行；表现层不得修改模拟状态。
- 数值、名称、数量等内容放 `content/` 的 JSON，不要写进代码。
- 大量同类实体（敌人、弹丸）用 SoA（Packed 数组），不要每个实体一个对象。
- 注释写"为什么"，不复述代码；不加无用注释。
- 缩进：GDScript 用 Tab，其余见 `.editorconfig`。

## 工作流程

1. 动手前：确认任务属于哪个里程碑（设计文档 §8），并确认放在哪一层、哪个模块。
2. 改完：`make check`；能运行就 `make run` 实际看一眼。
3. 设计有变化：同步更新 `docs/`。
4. 若发现某个文件逼近 1500 行：先拆分再继续加功能。

## 当前进度

文档与工程骨架已就绪。**M0（素材管线验证）进行中**：MIX 读取已完成（含加密头），详见 [asset-pipeline.md](docs/design/asset-pipeline.md) §7、§8。下一步：SHP + 调色板解码、`rulesmd.ini` 转 JSON、VXL 方向渲染。

工具链首次使用：`make setup`（创建 `.venv`，管线脚本用 `.venv/bin/python`）。**mod 里被 7zAES 密码保护的 `.mix`（实为 7z）不要尝试破解。**
