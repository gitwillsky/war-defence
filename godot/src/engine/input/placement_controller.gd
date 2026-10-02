class_name PlacementController
extends Node2D
## 世界内的鼠标交互：放置建筑 / 选取攻击落点 / 出售。只发信号，不改模拟状态。
## 作为世界视图的子节点使用（坐标系与世界一致）。

signal place_requested(cell: Vector2i)
signal target_requested(pos: Vector2)
signal sell_requested(entity_id: int)
signal cancelled

enum Mode { NONE, PLACE, TARGET, SELL }

var world: SimWorld
var mode: Mode = Mode.NONE
## PLACE 模式：(cell, size) -> bool，决定虚影颜色
var validator: Callable = Callable()
var place_size := Vector2i.ONE
var target_radius := 3.0

var _hover := Vector2.ZERO


func begin_place(size: Vector2i, valid_fn: Callable) -> void:
	mode = Mode.PLACE
	place_size = size
	validator = valid_fn
	queue_redraw()


func begin_target(radius: float) -> void:
	mode = Mode.TARGET
	target_radius = radius
	queue_redraw()


func begin_sell() -> void:
	mode = Mode.SELL
	queue_redraw()


func end() -> void:
	mode = Mode.NONE
	queue_redraw()


func _process(_delta: float) -> void:
	if mode == Mode.NONE:
		return
	_hover = IsoProjection.to_grid(get_local_mouse_position())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.NONE:
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_cancel()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_click()
			get_viewport().set_input_as_handled()


func _click() -> void:
	var g := IsoProjection.to_grid(get_local_mouse_position())
	match mode:
		Mode.PLACE:
			place_requested.emit(_place_cell(g))
		Mode.TARGET:
			target_requested.emit(g)
		Mode.SELL:
			var cell := Vector2i(floori(g.x), floori(g.y))
			var id: int = world.grid.occupant_at(cell) if world.grid.in_bounds(cell) else 0
			if id != 0:
				sell_requested.emit(id)


func _cancel() -> void:
	end()
	cancelled.emit()


## 鼠标位于占地中心，换算成占地左上格。
func _place_cell(g: Vector2) -> Vector2i:
	return Vector2i(roundi(g.x - place_size.x * 0.5), roundi(g.y - place_size.y * 0.5))


func _draw() -> void:
	match mode:
		Mode.PLACE:
			var cell := _place_cell(_hover)
			var ok: bool = validator.call(cell, place_size) if validator.is_valid() else true
			var col := Color(0.2, 1.0, 0.3, 0.45) if ok else Color(1.0, 0.2, 0.2, 0.45)
			for y in place_size.y:
				for x in place_size.x:
					_diamond(Vector2(cell.x + x + 0.5, cell.y + y + 0.5), col)
		Mode.TARGET:
			var pts := PackedVector2Array()
			for i in 33:
				var a := TAU * i / 32.0
				pts.append(IsoProjection.to_screen(_hover + Vector2(cos(a), sin(a)) * target_radius))
			draw_polyline(pts, Color(0.7, 0.85, 1.0, 0.9), 2.0)
		Mode.SELL:
			var cell := Vector2i(floori(_hover.x), floori(_hover.y))
			_diamond(Vector2(cell) + Vector2(0.5, 0.5), Color(1.0, 0.8, 0.1, 0.5))


func _diamond(center_grid: Vector2, col: Color) -> void:
	var c := IsoProjection.to_screen(center_grid)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -IsoProjection.TILE_H * 0.5), c + Vector2(IsoProjection.TILE_W * 0.5, 0),
		c + Vector2(0, IsoProjection.TILE_H * 0.5), c + Vector2(-IsoProjection.TILE_W * 0.5, 0)]), col)
