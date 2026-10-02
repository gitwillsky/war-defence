class_name TerrainMap
extends RefCounted
## 每格一个地形类别。类别名与属性（阻挡、通行代价、贴图）来自数据定义，引擎不预设有哪些类别。
## 逻辑属性通过 apply_to_grid 写进 Grid；表现由 TerrainView 读取。

var width: int
var height: int
var _kinds: Array[StringName] = []
var _cells: PackedByteArray


func _init(w: int, h: int, base_kind: StringName) -> void:
	width = w
	height = h
	_kinds.append(base_kind)
	_cells = PackedByteArray()
	_cells.resize(w * h)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func kind_at(c: Vector2i) -> StringName:
	return _kinds[_cells[c.y * width + c.x]]


func set_kind(c: Vector2i, kind: StringName) -> void:
	var i := _kinds.find(kind)
	if i < 0:
		i = _kinds.size()
		_kinds.append(kind)
	_cells[c.y * width + c.x] = i


func apply_to_grid(grid: Grid, kind_defs: Dictionary) -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var d: Dictionary = kind_defs.get(kind_at(c), {})
			grid.set_terrain_blocked(c, d.get("blocked", false))
			grid.set_move_cost(c, float(d.get("cost", 1.0)))
