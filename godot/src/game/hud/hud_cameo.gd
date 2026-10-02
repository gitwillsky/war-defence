class_name HudCameo
extends Control
## 建造栏的一张"卡片"：图标 + 造价，灰显 / 建造进度遮罩 / 悬停高亮。

signal pressed

var icon: Texture2D
var cost := 0
var enabled := true
var progress := -1.0  # <0 表示没有在建造；0..1 为进度
var busy_text := "建造中"
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _draw() -> void:
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2.ZERO, size), false)
	var font := ThemeDB.fallback_font
	if progress >= 0.0:
		draw_rect(Rect2(0, 0, size.x, size.y * (1.0 - progress)), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, size.y * 0.5), busy_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.95, 0.85, 0.3))
	elif not enabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var cost_text := "$%d" % cost
	draw_string_outline(font, Vector2(0, size.y - 6), cost_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 6, Color.BLACK)
	draw_string(font, Vector2(0, size.y - 6), cost_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1.0, 0.9, 0.35) if enabled else Color(0.7, 0.6, 0.3))
	if _hover:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.85, 0.3, 0.9), false, 2.0)
