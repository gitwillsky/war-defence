class_name Minimap
extends Control
## 小地图：把网格按等距菱形缩放画出来，单位/建筑按阵营着色。只读模拟状态。
## team_colors: team -> Color

var world: SimWorld
var team_colors: Dictionary = {0: Color(0.3, 0.6, 1.0), 1: Color(1.0, 0.25, 0.2)}
var camera: Camera2D
var terrain: TerrainMap
var kind_defs: Dictionary = {}  # 地形类别 -> {minimap: [r,g,b]}
var _terrain_tex: ImageTexture
var _acc := 0.0


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			or event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		var g := _to_grid((event as InputEventMouse).position)
		camera.position = IsoProjection.to_screen(g)
		accept_event()


func _draw() -> void:
	if world == null:
		return
	var w := float(world.grid.width)
	var h := float(world.grid.height)
	var quad := PackedVector2Array([_to_local(Vector2(0, 0)), _to_local(Vector2(w, 0)), _to_local(Vector2(w, h)), _to_local(Vector2(0, h))])
	draw_colored_polygon(quad, Color(0.16, 0.2, 0.24))
	if terrain != null:
		if _terrain_tex == null:
			_bake_terrain()
		draw_texture_rect(_terrain_tex, Rect2(Vector2.ZERO, size * float(w + h + 1.0) / float(w + h)), false)
	for e in world.entities.values():
		if not e.alive or e.kind == &"projectile":
			continue
		var col: Color = team_colors.get(e.team, Color.WHITE)
		var p := _to_local(e.pos)
		if e.layer == &"structure":
			var half := Vector2(e.size) * (size.x / (w + h)) * 1.0
			draw_rect(Rect2(p - half * 0.5, half), col)
		else:
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), col.lightened(0.2))
	draw_polyline(quad + PackedVector2Array([quad[0]]), Color(0.7, 0.8, 0.9, 0.5), 1.0)
	if camera != null:
		var g := IsoProjection.to_grid(camera.position)
		draw_arc(_to_local(g), 6.0, 0, TAU, 12, Color(1, 1, 1, 0.8), 1.0)


## 网格坐标 -> 控件内坐标：等距菱形撑满控件（宽 = w + h 个半格）。
func _to_local(g: Vector2) -> Vector2:
	var w := float(world.grid.width)
	var h := float(world.grid.height)
	var scale_x := size.x / (w + h)
	var scale_y := size.y / (w + h)
	return Vector2((g.x - g.y + h) * scale_x, (g.x + g.y) * scale_y)


func _to_grid(local: Vector2) -> Vector2:
	var w := float(world.grid.width)
	var h := float(world.grid.height)
	var a := local.x / (size.x / (w + h)) - h
	var b := local.y / (size.y / (w + h))
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## 把地形烘成一张等距小图：格 (x,y) 落在像素 (x-y+h, x+y)，每格涂左右两像素以免棋盘状空洞。
func _bake_terrain() -> void:
	var n := terrain.width + terrain.height
	var img := Image.create_empty(n + 1, n + 1, false, Image.FORMAT_RGBA8)
	for y in terrain.height:
		for x in terrain.width:
			var d: Dictionary = kind_defs.get(terrain.kind_at(Vector2i(x, y)), {})
			var c: Array = d.get("minimap", [0.3, 0.3, 0.3])
			var col := Color(float(c[0]), float(c[1]), float(c[2]))
			var px := x - y + terrain.height
			var py := x + y
			img.set_pixel(px, py, col)
			img.set_pixel(px + 1, py, col)
			if py + 1 <= n:
				img.set_pixel(px, py + 1, col)
				img.set_pixel(px + 1, py + 1, col)
	_terrain_tex = ImageTexture.create_from_image(img)
