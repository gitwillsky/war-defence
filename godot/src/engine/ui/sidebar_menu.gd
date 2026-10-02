class_name SidebarMenu
extends PanelContainer
## 通用竖向按钮栏：每项 {id, label, cost, icon: Texture2D}。只发信号，不知道项目含义。

signal item_pressed(id: String)

var _buttons: Dictionary = {}  # id -> Button
var _list := VBoxContainer.new()


func _init() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(176, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


func set_items(items: Array) -> void:
	for b: Button in _buttons.values():
		b.queue_free()
	_buttons.clear()
	for item: Dictionary in items:
		var b := Button.new()
		b.text = "%s\n$%d" % [item["label"], int(item.get("cost", 0))]
		b.icon = item.get("icon")
		b.expand_icon = false
		b.custom_minimum_size = Vector2(164, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: item_pressed.emit(item["id"]))
		_list.add_child(b)
		_buttons[item["id"]] = b


func set_enabled(id: String, enabled: bool, tooltip: String = "") -> void:
	var b: Button = _buttons.get(id)
	if b != null:
		b.disabled = not enabled
		b.tooltip_text = tooltip
