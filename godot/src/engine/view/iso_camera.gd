class_name IsoCamera
extends Camera2D
## 等距相机：WASD/方向键、屏幕边缘、鼠标中键拖动平移，滚轮缩放，限制在地图范围内。

const PAN_SPEED := 900.0
const EDGE := 12.0

var bounds := Rect2(-2000, 0, 4000, 2000)
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
	position = position.clamp(bounds.position, bounds.end)


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
	var z := clampf(zoom.x * f, 0.5, 2.0)
	zoom = Vector2(z, z)
