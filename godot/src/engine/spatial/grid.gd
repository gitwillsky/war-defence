class_name Grid
extends RefCounted
## 逻辑网格：地形阻挡 + 占用者(实体 id，0 表示空)。

var width: int
var height: int
var _terrain_blocked: PackedByteArray
var _occupant: PackedInt32Array
var _move_cost: PackedFloat32Array  # 地表通行代价倍率，1 = 普通（路面 < 1）


func _init(w: int, h: int) -> void:
	width = w
	height = h
	_terrain_blocked = PackedByteArray()
	_terrain_blocked.resize(w * h)
	_occupant = PackedInt32Array()
	_occupant.resize(w * h)
	_move_cost = PackedFloat32Array()
	_move_cost.resize(w * h)
	_move_cost.fill(1.0)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index_of(c: Vector2i) -> int:
	return c.y * width + c.x


func cell_of(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func rect_in_bounds(origin: Vector2i, size: Vector2i) -> bool:
	return in_bounds(origin) and in_bounds(origin + size - Vector2i.ONE)


func is_terrain_blocked(c: Vector2i) -> bool:
	return _terrain_blocked[index_of(c)] != 0


func set_terrain_blocked(c: Vector2i, blocked: bool) -> void:
	_terrain_blocked[index_of(c)] = 1 if blocked else 0


func move_cost(c: Vector2i) -> float:
	return _move_cost[index_of(c)]


func set_move_cost(c: Vector2i, cost: float) -> void:
	_move_cost[index_of(c)] = cost


## 只读快照（写时复制，几乎无开销），供寻路等需要整体扫描的算法使用。
func blocked_flags() -> PackedByteArray:
	return _terrain_blocked


func occupant_ids() -> PackedInt32Array:
	return _occupant


func move_costs() -> PackedFloat32Array:
	return _move_cost


func occupant_at(c: Vector2i) -> int:
	return _occupant[index_of(c)]


func rect_is_free(origin: Vector2i, size: Vector2i) -> bool:
	if not rect_in_bounds(origin, size):
		return false
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			var c := Vector2i(x, y)
			if is_terrain_blocked(c) or occupant_at(c) != 0:
				return false
	return true


func set_rect_occupant(origin: Vector2i, size: Vector2i, entity_id: int) -> void:
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			_occupant[index_of(Vector2i(x, y))] = entity_id
