# War Defence

基于 **Godot 4 + GDScript** 的 2.5D（等距视角）**基地防守型塔防**，世界观取自《红色警戒 2》。

玩家在基地中采矿、供电、建造防御设施，抵御分波次涌入的敌军，并用超级武器扭转战局。第一版只实现盟军阵营。

> 项目处于**设计阶段**，尚无可运行版本。路线图见 [docs/design/high-level-design.md](docs/design/high-level-design.md) §8。

## 特点

- **通用引擎 + 游戏层分离**：引擎不含任何红警内容，换素材、换玩法都不改引擎
- **素材与逻辑分离**：原版素材通过离线管线转成中立格式（PNG/OGG/JSON）素材包，运行时只认 asset id
- **数据驱动**：单位、武器、护甲倍率、科技树等全部在 JSON 里，数值源自 `rulesmd.ini`
- **模拟/表现分离**：固定步长、确定性的模拟层，不依赖节点
- **流场寻路 + 空间哈希**：为大量敌人准备

## 快速开始

需要：Godot 4.x、Python 3.10+。

```bash
make help            # 查看所有命令
make import-assets   # 把原始素材转成素材包（M0 实现后可用）
make run             # 运行游戏
make check           # 静态规则检查
```

原始素材需放在仓库根目录的 `尤里科技时代4.0完结版/`（或用环境变量 `WD_RAW_DIR` 指定）。它不会被提交。

## 目录

| 路径 | 说明 |
|------|------|
| `docs/` | 设计文档，入口见 [docs/README.md](docs/README.md) |
| `tools/` | 离线工具：素材管线、规则检查 |
| `godot/` | Godot 工程：`src/engine` 通用引擎、`src/game` 游戏内容、`src/app` 启动装配 |
| `AGENTS.md` | AI 助手与新成员的工程指南（约束、约定、命令） |

## 工程约束

- 单个源文件不超过 2000 行
- 分层依赖：`app → game → engine`，禁止反向
- 全 GDScript，静态类型

详见 [AGENTS.md](AGENTS.md)。

## 版权说明

《红色警戒 2》及其素材版权归 Electronic Arts 所有。本仓库**不包含**任何原版素材，且 `.gitignore` 已将其排除。使用原版素材构建的版本仅限个人学习研究，**请勿公开分发**；如需发布，请替换为自制素材包。

引擎对素材包只依赖 manifest 契约，见 [asset-pipeline.md](docs/design/asset-pipeline.md)。
