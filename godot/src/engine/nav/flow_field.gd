class_name FlowField
extends RefCounted
## 流场：从目标格出发做加权 Dijkstra，得到每格到目标的代价。
## 占地实体（建筑）可通行但代价高：能绕则绕，被封死时就"穿过"——走到建筑前由战斗系统攻击它。

const DIAG := 1.4142
static var DX := PackedInt32Array([1, -1, 0, 0, 1, 1, -1, -1])
static var DY := PackedInt32Array([0, 0, 1, -1, 1, -1, 1, -1])
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var dist := PackedFloat32Array()
var _grid: Grid
var _goal_set: Dictionary = {}  # Vector2i -> true


## 热点路径：每次放置/出售建筑都会重算，所以用扁平数组 + 内联堆，避免 Vector2i 与方法调用开销。
func compute(grid: Grid, goals: Array[Vector2i], structure_cost: float) -> void:
	_grid = grid
	_goal_set.clear()
	var w := grid.width
	var h := grid.height
	var n := w * h
	var blocked := grid.blocked_flags()
	var occ := grid.occupant_ids()
	var move := grid.move_costs()
	dist.resize(n)
	dist.fill(INF)
	var enter := PackedFloat32Array()
	enter.resize(n)
	for i in n:
		enter[i] = move[i] + (structure_cost if occ[i] != 0 else 0.0)
	var heap_p := PackedFloat32Array()
	var heap_v := PackedInt32Array()
	heap_p.resize(n * 8 + goals.size() + 8)
	heap_v.resize(n * 8 + goals.size() + 8)
	var hn := 0
	for g in goals:
		if grid.in_bounds(g):
			var gi := g.y * w + g.x
			_goal_set[g] = true
			dist[gi] = 0.0
			enter[gi] = move[gi]
			heap_p[hn] = 0.0
			heap_v[hn] = gi
			hn += 1
	while hn > 0:
		var d := heap_p[0]
		var i := heap_v[0]
		hn -= 1
		if hn > 0:
			var last_p := heap_p[hn]
			var last_v := heap_v[hn]
			var k := 0
			while true:
				var l := 2 * k + 1
				if l >= hn:
					break
				var m := l
				if l + 1 < hn and heap_p[l + 1] < heap_p[l]:
					m = l + 1
				if heap_p[m] >= last_p:
					break
				heap_p[k] = heap_p[m]
				heap_v[k] = heap_v[m]
				k = m
			heap_p[k] = last_p
			heap_v[k] = last_v
		if d > dist[i]:
			continue
		var x := i % w
		var y := i / w
		var e := enter[i]
		for di in 8:
			var dx := DX[di]
			var dy := DY[di]
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if blocked[ni] != 0:
				continue
			var nd := d + e
			if dx != 0 and dy != 0:
				# 斜走时两侧正交格都必须是空地，防止从两栋建筑缝隙里挤过去
				var s1 := y * w + nx
				var s2 := ny * w + x
				if blocked[s1] != 0 or occ[s1] != 0 or blocked[s2] != 0 or occ[s2] != 0:
					continue
				nd = d + e * DIAG
			# dist 是 float32，nd 是 double：不留容差会因舍入反复"改进"同一格
			if nd < dist[ni] - 0.0001:
				dist[ni] = nd
				var k := hn
				hn += 1
				if hn > heap_p.size():
					heap_p.resize(heap_p.size() * 2)
					heap_v.resize(heap_v.size() * 2)
				while k > 0:
					var p := (k - 1) >> 1
					if heap_p[p] <= nd:
						break
					heap_p[k] = heap_p[p]
					heap_v[k] = heap_v[p]
					k = p
				heap_p[k] = nd
				heap_v[k] = ni


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
		return _grid.move_cost(c)
	return _grid.move_cost(c) + (structure_cost if _grid.occupant_at(c) != 0 else 0.0)


## 斜走时两侧正交格都必须是空地，防止从两栋建筑缝隙里挤过去。
func _diagonal_ok(c: Vector2i, dir: Vector2i) -> bool:
	for side in [c + Vector2i(dir.x, 0), c + Vector2i(0, dir.y)]:
		if not _grid.in_bounds(side) or _grid.is_terrain_blocked(side) or _grid.occupant_at(side) != 0:
			return false
	return true
