class_name GameHud
extends CanvasLayer
## 游戏界面，沿用原版红警 2 侧边栏的构成：雷达框（小地图）、资金条、分类选项卡、卡片槽、
## 底部按钮，左侧竖向电力条。素材全部来自素材包 ui.*；这里只负责摆放与状态展示。
## 只读会话状态，操作通过信号交给 app 层转成命令。

signal build_selected(def_id: StringName)
signal sell_toggled
signal next_wave_pressed
signal pause_toggled
signal speed_changed(multiplier: float)
signal superweapon_pressed
signal restart_pressed

const S := 2.0                 # 原版素材是 640x480 时代的，整数放大
const SIDEBAR_W := 168.0
const SLOT_ROWS := 4
const CAMEO_X := [20.0, 86.0]
const CAMEO_SIZE := Vector2(60, 48)
const TABS := [
	{"id": "structure", "sprite": "ui.tab_structure"}, {"id": "defense", "sprite": "ui.tab_defense"},
	{"id": "infantry", "sprite": "ui.tab_infantry"}, {"id": "vehicle", "sprite": "ui.tab_vehicle"},
]
const GOLD := Color(1.0, 0.86, 0.35)

var session: GameSession
var sound: SoundPlayer
var minimap: Minimap

var _assets: AssetProvider
var _root := Control.new()
var _credits_label := Label.new()
var _cameos: Dictionary = {}      # def_id -> HudCameo
var _tab_buttons: Array[TextureButton] = []
var _tab := "structure"
var _power_bar := HudPowerBar.new()
var _power_icon := TextureRect.new()
var _status := Label.new()
var _hint := Label.new()
var _fps := Label.new()
var _storm := Button.new()
var _next := Button.new()
var _speed_btn := Button.new()
var _pause_btn := Button.new()
var _sell_btn := TextureButton.new()
var _overlay := Control.new()
var _overlay_title := Label.new()
var _overlay_detail := Label.new()
var _speeds := [1.0, 2.0, 3.0]
var _speed_i := 0
var _hint_left := 0.0
var _selling := false


func setup(game: GameSession, assets: AssetProvider, sound_player: SoundPlayer) -> void:
	session = game
	_assets = assets
	sound = sound_player
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_sidebar()
	_build_power_bar()
	_build_status_panel()
	_build_hint()
	_build_overlay()
	_select_tab("structure")


func show_hint(text: String, seconds: float = 2.5) -> void:
	_hint.text = text
	_hint_left = seconds


func set_sell_active(active: bool) -> void:
	_selling = active
	_sell_btn.set_pressed_no_signal(active)


func show_game_over(won: bool, kills: int) -> void:
	_overlay_title.text = "防守成功" if won else "基地被摧毁"
	_overlay_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.4, 0.35))
	_overlay_detail.text = "击杀 %d 个敌人\n坚持到第 %d 波" % [kills, session.waves.wave_index]
	_overlay.visible = true
	sound.play("sfx.win" if won else "sfx.lose")


func refresh(delta: float) -> void:
	var eco := session.economy
	_credits_label.text = "$ %d" % int(eco.get_credits(Team.PLAYER))
	var produced: float = eco.power_produced.get(Team.PLAYER, 0.0)
	var consumed: float = eco.power_consumed.get(Team.PLAYER, 0.0)
	_power_bar.set_power(produced, consumed)
	_power_icon.texture = _assets.get_frame_texture("ui.power", 1 if produced >= consumed else 0)
	var w := session.waves
	var enemies := _count_enemies()
	if w.wave_index < w.total_waves():
		_status.text = "第 %d / %d 波    %d 秒后来袭    敌军 %d" % [w.wave_index + 1, w.total_waves(), ceili(w.countdown), enemies]
	else:
		_status.text = "最后一波    敌军 %d" % enemies
	_next.disabled = w.wave_index >= w.total_waves()
	var storm := session.storm
	_storm.visible = storm.unlocked
	_storm.disabled = not storm.is_ready()
	_storm.text = "闪电风暴 就绪" if storm.is_ready() else "闪电风暴 %d%%" % int(100.0 * storm.charge / maxf(storm.charge_time, 1.0))
	_fps.text = "FPS %d" % Engine.get_frames_per_second()
	_update_cameos()
	_hint_left -= delta
	if _hint_left <= 0.0:
		_hint.text = ""


# ---- 构建 ----

func _tex(id: String, frame: int = 0) -> Texture2D:
	return _assets.get_frame_texture(id, frame)


func _place(node: Control, x: float, y: float, w: float, h: float, parent: Control) -> void:
	node.position = Vector2(x, y) * S
	node.size = Vector2(w, h) * S
	parent.add_child(node)


func _image(id: String, frame: int, x: float, y: float, parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(id, frame)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := t.texture.get_size() if t.texture != null else Vector2.ZERO
	_place(t, x, y, sz.x, sz.y, parent)
	return t


func _build_sidebar() -> void:
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -SIDEBAR_W * S
	bar.offset_right = 0
	bar.offset_top = 0
	bar.offset_bottom = 470 * S
	_root.add_child(bar)
	_image("ui.radar", 0, 0, 0, bar)
	minimap = Minimap.new()
	minimap.world = session.world
	_place(minimap, 14, 4, 140, 102, bar)
	_image("ui.credits", 0, 0, 110, bar)
	_credits_label.add_theme_font_size_override("font_size", 22)
	_credits_label.add_theme_color_override("font_color", GOLD)
	_credits_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_credits_label.add_theme_constant_override("outline_size", 5)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_credits_label, 0, 108, SIDEBAR_W, 20, bar)
	_image("ui.tabs", 0, 0, 128, bar)
	for i in TABS.size():
		var b := TextureButton.new()
		var sprite: String = TABS[i]["sprite"]
		b.texture_normal = _tex(sprite, 0)
		b.texture_pressed = _tex(sprite, 1)
		b.texture_hover = _tex(sprite, 4)
		b.texture_disabled = _tex(sprite, 2)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.ignore_texture_size = true
		b.toggle_mode = true
		var tab_id: String = TABS[i]["id"]
		b.disabled = not _tab_has_items(tab_id)
		b.pressed.connect(func() -> void:
			sound.play("sfx.ui.click")
			_select_tab(tab_id))
		_place(b, 12.0 + 38.0 * i, 128, 32, 28, bar)
		_tab_buttons.append(b)
	for r in SLOT_ROWS:
		_image("ui.side_slot", 0, 0, 158 + 50 * r, bar)
	_image("ui.side_bottom", 0, 0, 158 + 50 * SLOT_ROWS, bar)
	_build_cameos(bar)
	_build_buttons(bar)


func _tab_has_items(tab_id: String) -> bool:
	for id in session.buildable_ids():
		if session.world.defs.get_def(&"structure", id).get("tab", "structure") == tab_id:
			return true
	return false


func _build_cameos(bar: Control) -> void:
	for id in session.buildable_ids():
		var d := session.world.defs.get_def(&"structure", id)
		var c := HudCameo.new()
		c.icon = _tex(d.get("icon", ""), 0)
		c.cost = int(d.get("cost", 0))
		c.tooltip_text = _describe(d)
		c.pressed.connect(func() -> void: build_selected.emit(id))
		c.set_meta("tab", d.get("tab", "structure"))
		_cameos[id] = c
		bar.add_child(c)
	# 摆放在选项卡切换时统一做（按当前页排序）


func _describe(d: Dictionary) -> String:
	var p: Dictionary = d.get("power", {})
	var power_text := ""
	if float(p.get("produce", 0)) > 0:
		power_text = "  供电 +%d" % int(p["produce"])
	elif float(p.get("consume", 0)) > 0:
		power_text = "  耗电 -%d" % int(p["consume"])
	return "%s\n造价 $%d%s" % [d.get("name", ""), int(d.get("cost", 0)), power_text]


func _select_tab(tab_id: String) -> void:
	_tab = tab_id
	for i in TABS.size():
		_tab_buttons[i].set_pressed_no_signal(TABS[i]["id"] == tab_id)
	var slot := 0
	for id in session.buildable_ids():
		var c: HudCameo = _cameos[id]
		var show: bool = c.get_meta("tab") == tab_id and slot < SLOT_ROWS * 2
		c.visible = show
		if show:
			var row := slot / 2
			c.position = Vector2(CAMEO_X[slot % 2], 158.0 + 50.0 * row + 1.0) * S
			c.size = CAMEO_SIZE * S
			slot += 1


func _build_buttons(bar: Control) -> void:
	var y := 158.0 + 50.0 * SLOT_ROWS + 28.0
	_sell_btn.texture_normal = _tex("ui.btn_sell", 0)
	_sell_btn.texture_pressed = _tex("ui.btn_sell", 1)
	_sell_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sell_btn.stretch_mode = TextureButton.STRETCH_SCALE
	_sell_btn.ignore_texture_size = true
	_sell_btn.toggle_mode = true
	_sell_btn.tooltip_text = "出售建筑（点击后选择要出售的建筑）"
	_sell_btn.pressed.connect(func() -> void:
		sound.play("sfx.ui.click")
		sell_toggled.emit())
	_place(_sell_btn, 58, y, 52, 32, bar)
	var row_y := y + 40.0
	for spec: Array in [[_next, "下一波", 8.0, "提前呼叫下一波敌人"], [_pause_btn, "暂停", 62.0, "暂停 / 继续"], [_speed_btn, "x1", 116.0, "切换游戏速度"]]:
		var b: Button = spec[0]
		_style_plate(b)
		b.text = spec[1]
		b.tooltip_text = spec[3]
		b.focus_mode = Control.FOCUS_NONE
		_place(b, spec[2], row_y, 44, 24, bar)
	_next.pressed.connect(func() -> void:
		sound.play("sfx.ui.click")
		next_wave_pressed.emit())
	_pause_btn.pressed.connect(func() -> void:
		sound.play("sfx.ui.click")
		pause_toggled.emit())
	_speed_btn.pressed.connect(func() -> void:
		sound.play("sfx.ui.click")
		_speed_i = (_speed_i + 1) % _speeds.size()
		_speed_btn.text = "x%d" % int(_speeds[_speed_i])
		speed_changed.emit(_speeds[_speed_i]))
	_style_plate(_storm)
	_storm.focus_mode = Control.FOCUS_NONE
	_storm.visible = false
	_place(_storm, 8, row_y + 30.0, 152, 26, bar)
	_storm.pressed.connect(func() -> void:
		sound.play("sfx.ui.click")
		superweapon_pressed.emit())


## 银色金属按钮底板：用原版选项卡的空白帧做九宫格。
func _style_plate(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxTexture.new()
		var atlas := _tex("ui.tab_structure", 2)
		sb.texture = atlas
		sb.texture_margin_left = 6
		sb.texture_margin_right = 6
		sb.texture_margin_top = 6
		sb.texture_margin_bottom = 6
		sb.modulate_color = {"normal": Color.WHITE, "hover": Color(1.15, 1.1, 0.9), "pressed": Color(0.75, 0.75, 0.75), "disabled": Color(0.5, 0.5, 0.5)}[state]
		b.add_theme_stylebox_override(state, sb)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(0.35, 0.05, 0.05))
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))


func _build_power_bar() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.offset_left = -(SIDEBAR_W + 22) * S
	holder.offset_right = -SIDEBAR_W * S
	holder.offset_top = 0
	holder.offset_bottom = 470 * S
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	_power_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_power_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_power_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_power_icon, 0, 0, 22, 24, holder)
	for i in 5:
		_power_bar.pip_textures.append(_tex("ui.power_pip", i))
	_power_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_power_bar.segment_height = 4.0 * S
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_power_bar, 3, 26, 16, 430, holder)
	_power_bar.tooltip_text = "电力"


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.82)
	sb.border_color = Color(0.78, 0.62, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _build_status_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(12, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", GOLD)
	row.add_child(_status)
	_fps.add_theme_font_size_override("font_size", 18)
	_fps.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	row.add_child(_fps)
	_root.add_child(panel)


func _build_hint() -> void:
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = -120
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)


func _build_overlay() -> void:
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_overlay_title.add_theme_font_size_override("font_size", 56)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_title)
	_overlay_detail.add_theme_font_size_override("font_size", 26)
	_overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_detail)
	var again := Button.new()
	_style_plate(again)
	again.text = "再来一局"
	again.custom_minimum_size = Vector2(200, 56)
	again.add_theme_font_size_override("font_size", 26)
	again.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(again)


# ---- 刷新 ----

func _count_enemies() -> int:
	var n := 0
	for e in session.world.entities.values():
		if e.team == Team.ENEMY and e.kind == &"unit" and e.alive:
			n += 1
	return n


func _update_cameos() -> void:
	var progress: Dictionary = {}
	for e in session.world.entities.values():
		if e.team == Team.PLAYER and e.layer == &"structure" and e.state.get("build_left", 0.0) > 0.0:
			var total := maxf(float(e.def.get("build_time", 1.0)), 0.001)
			progress[e.def_id] = maxf(progress.get(e.def_id, 0.0), 1.0 - float(e.state["build_left"]) / total)
	for id in _cameos:
		var c: HudCameo = _cameos[id]
		var reason := session.build.afford_reason(session.world, Team.PLAYER, id)
		c.enabled = reason == ""
		c.progress = progress.get(id, -1.0)
		if reason != "":
			c.tooltip_text = _describe(session.world.defs.get_def(&"structure", id)) + "\n" + reason
		c.queue_redraw()
