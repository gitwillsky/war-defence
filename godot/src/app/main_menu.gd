class_name MainMenu
extends CanvasLayer
## 标题菜单与暂停菜单：压在实时地图之上的半透明面板。只发信号，不碰游戏状态。

signal start_pressed
signal resume_pressed
signal restart_pressed
signal quit_pressed

var _assets: AssetProvider
var _root := Control.new()
var _panel := _MenuPanel.new()
var _title := Label.new()
var _subtitle := Label.new()
var _box := VBoxContainer.new()
var _tips := Label.new()


func setup(assets: AssetProvider) -> void:
	_assets = assets
	layer = 20
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 440)
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = -230
	_panel.offset_bottom = 210
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 30
	col.offset_bottom = -30
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", HudStyle.GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	_title.add_theme_constant_override("outline_size", 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(0.65, 0.8, 0.95))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	_box.add_theme_constant_override("separation", 16)
	col.add_child(_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_tips.add_theme_font_size_override("font_size", 16)
	_tips.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
	_tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tips.text = "WASD / 屏幕边缘：移动视角    滚轮：缩放\n左侧卡片：建造    Shift：连续放置    右键：取消    Esc：暂停"
	col.add_child(_tips)


## 标题菜单（title=true）或暂停菜单。
func open(title: bool) -> void:
	for c in _box.get_children():
		c.queue_free()
	_title.text = "基地防线" if title else "游戏暂停"
	_subtitle.text = "盟军 · 冰原防守战" if title else ""
	if title:
		_add_button("开始作战", start_pressed)
	else:
		_add_button("继续", resume_pressed)
		_add_button("重新开始", restart_pressed)
	_add_button("退出游戏", quit_pressed)
	_root.visible = true
	visible = true


func close() -> void:
	visible = false


func _add_button(text: String, sig: Signal) -> void:
	var b := Button.new()
	HudStyle.style_plate(b, _assets.get_frame_texture("ui.tab_structure", 2), 30)
	b.text = text
	b.custom_minimum_size = Vector2(0, 66)
	b.pressed.connect(func() -> void: sig.emit())
	_box.add_child(b)


class _MenuPanel extends Control:
	func _draw() -> void:
		HudStyle.draw_plate(self, size, 22.0)
