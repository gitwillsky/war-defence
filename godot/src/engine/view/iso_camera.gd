class_name IsoCamera
extends Camera2D
## 等距相机：WASD/方向键、屏幕边缘、鼠标中键拖动平移，滚轮缩放，限制在地图范围内。

const PAN_SPEED := 900.0
const EDGE := 12.0

var bounds := Rect2(-2000, 0, 4000, 2000)
var map_cells := Vector2i.ZERO  # 设置后相机被限制在"地图 + 装饰带"的菱形内，且视口不越界
var pad_cells := 0
const INSET := 3.0  # 离装饰带最外沿再留几格，避开最外圈
var _dragging := false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	dir.x = Input.get_axis(&"ui_left", &"ui_right")
	dir.y = Input.get_axis(&"ui_up", &"ui_down")
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	var vp := get_viewport()
	var m := vp.get_mouse_position()
	var size := vp.get_visible_rect().size
	if DisplayServer.window_is_focused() and vp.get_visible_rect().has_point(m):
		if m.x < EDGE:
			dir.x -= 1.0
		elif m.x > size.x - EDGE:
			dir.x += 1.0
		if m.y < EDGE:
			dir.y -= 1.0
		elif m.y > size.y - EDGE:
			dir.y += 1.0
	position += dir.limit_length(1.0) * PAN_SPEED * delta / zoom.x
	_clamp_position()


func _clamp_position() -> void:
	if map_cells == Vector2i.ZERO:
		position = position.clamp(bounds.position, bounds.end)
		return
	var w := float(map_cells.x + 2 * pad_cells) - 2.0 * INSET
	var h := float(map_cells.y + 2 * pad_cells) - 2.0 * INSET
	var center := IsoProjection.to_screen(Vector2(map_cells) * 0.5)
	var half_w := (w + h) * 0.5 * 30.0
	var half_h := (w + h) * 0.5 * 15.0
	var view_half := get_viewport_rect().size / (2.0 * zoom.x)
	var avail := 1.0 - view_half.x / half_w - view_half.y / half_h
	if avail <= 0.0:
		position = center
		return
	var off := position - center
	var k := absf(off.x) / half_w + absf(off.y) / half_h
	if k > avail:
		off *= avail / k
	position = center + off


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x


func _zoom_by(f: float) -> void:
	var z := clampf(zoom.x * f, 0.85, 2.0)
	zoom = Vector2(z, z)
