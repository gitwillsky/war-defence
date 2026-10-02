class_name FlowField
extends RefCounted
## 流场：从目标格出发做加权 Dijkstra，得到每格到目标的代价。
## 占地实体（建筑）可通行但代价高：能绕则绕，被封死时就"穿过"——走到建筑前由战斗系统攻击它。

const DIAG := 1.4142
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var dist := PackedFloat32Array()
var _grid: Grid
var _goal_set: Dictionary = {}  # Vector2i -> true


func compute(grid: Grid, goals: Array[Vector2i], structure_cost: float) -> void:
	_grid = grid
	_goal_set.clear()
	dist.resize(grid.width * grid.height)
	dist.fill(INF)
	var heap := MinHeap.new()
	for g in goals:
		if grid.in_bounds(g):
			_goal_set[g] = true
			dist[grid.index_of(g)] = 0.0
			heap.push(0.0, grid.index_of(g))
	while not heap.is_empty():
		var i := heap.pop()
		var c := grid.cell_of(i)
		var d := dist[i]
		var enter := _enter_cost(c, structure_cost)
		for dir in DIRS:
			var n := c + dir
			if not grid.in_bounds(n) or grid.is_terrain_blocked(n):
				continue
			var diagonal := dir.x != 0 and dir.y != 0
			if diagonal and not _diagonal_ok(c, dir):
				continue
			var nd := d + enter * (DIAG if diagonal else 1.0)
			var ni := grid.index_of(n)
			if nd < dist[ni]:
				dist[ni] = nd
				heap.push(nd, ni)


func is_goal(c: Vector2i) -> bool:
	return _goal_set.has(c)


func has_goals() -> bool:
	return not _goal_set.is_empty()


## 从 c 出发下一步应进入的格；已在目标或无路时返回 c 自身。
func best_neighbor(c: Vector2i) -> Vector2i:
	var best := c
	var best_d := dist[_grid.index_of(c)]
	for dir in DIRS:
		var n := c + dir
		if not _grid.in_bounds(n) or _grid.is_terrain_blocked(n):
			continue
		if dir.x != 0 and dir.y != 0 and not _diagonal_ok(c, dir):
			continue
		var nd := dist[_grid.index_of(n)]
		if nd < best_d:
			best_d = nd
			best = n
	return best


func _enter_cost(c: Vector2i, structure_cost: float) -> float:
	if _goal_set.has(c):
		return 1.0
	return 1.0 + (structure_cost if _grid.occupant_at(c) != 0 else 0.0)


## 斜走时两侧正交格都必须是空地，防止从两栋建筑缝隙里挤过去。
func _diagonal_ok(c: Vector2i, dir: Vector2i) -> bool:
	for side in [c + Vector2i(dir.x, 0), c + Vector2i(0, dir.y)]:
		if not _grid.in_bounds(side) or _grid.is_terrain_blocked(side) or _grid.occupant_at(side) != 0:
			return false
	return true
