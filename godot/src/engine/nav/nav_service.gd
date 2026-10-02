class_name NavService
extends RefCounted
## 导航服务：为每个"目标所属阵营"缓存一张流场；网格变化时失效。
## 两阵营模型：opponent_of 指明每个阵营的敌对阵营，其"目标建筑"是该阵营单位的前进目标。

var structure_cost: float = 25.0
var opponent_of: Dictionary = {0: 1, 1: 0}  # team -> 敌对 team
var objective_key: String = "objective"  # 定义中标记目标建筑的字段

var _fields: Dictionary = {}  # 目标阵营 -> FlowField


func attach(world: SimWorld) -> void:
	world.set_service(&"nav", self)
	world.events.subscribe(&"grid_changed", func(_p: Dictionary) -> void: _fields.clear())


## 阵营 team 的单位应前往的流场（目标 = 敌对阵营的目标建筑）。
func field_for(world: SimWorld, team: int) -> FlowField:
	var target_team: int = opponent_of.get(team, -1)
	if _fields.has(target_team):
		return _fields[target_team]
	var goals: Array[Vector2i] = []
	for e in world.live:
		if e.team == target_team and e.layer == &"structure" and e.def.get(objective_key, false):
			for y in range(e.cell.y, e.cell.y + e.size.y):
				for x in range(e.cell.x, e.cell.x + e.size.x):
					goals.append(Vector2i(x, y))
	var field := FlowField.new()
	field.compute(world.grid, goals, structure_cost)
	_fields[target_team] = field
	return field


## 空中单位直线飞向的目标：最近的敌方目标建筑；没有则返回 null。
func nearest_objective(world: SimWorld, team: int, from: Vector2) -> SimEntity:
	var target_team: int = opponent_of.get(team, -1)
	var best: SimEntity = null
	var best_d := INF
	for e in world.live:
		if e.team == target_team and e.layer == &"structure" and e.def.get(objective_key, false):
			var d := from.distance_squared_to(e.pos)
			if d < best_d:
				best_d = d
				best = e
	return best
