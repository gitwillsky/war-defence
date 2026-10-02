# war-defence 工程入口。`make help` 查看全部命令。

GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
PY    ?= .venv/bin/python

.PHONY: help setup shp-export run editor check format import-assets mix-list

help: ## 列出所有命令
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

setup: ## 创建 .venv 并安装工具依赖
	python3 -m venv .venv
	.venv/bin/pip install -q -r tools/requirements.txt

mix-list: ## 列出原始素材目录中所有 MIX 归档
	$(PY) tools/asset_pipeline/cli.py mix-list

shp-export: ## 导出 SHP 为 PNG：make shp-export NAME=gapris.shp
	$(PY) tools/asset_pipeline/cli.py shp-export $(NAME)

run: ## 运行游戏
	$(GODOT) --path godot

editor: ## 用 Godot 编辑器打开工程
	$(GODOT) --editor --path godot

check: ## 静态规则检查（行数上限、分层依赖）
	python3 tools/check_rules.py

format: ## 格式化 GDScript（需要 pip install gdtoolkit）
	gdformat godot/src

import-assets: ## 运行素材管线（需要 ffmpeg）
	@test -f tools/asset_pipeline/cli.py || { echo "素材管线尚未实现，见 docs/design/asset-pipeline.md"; exit 1; }
	$(PY) tools/asset_pipeline/cli.py all
