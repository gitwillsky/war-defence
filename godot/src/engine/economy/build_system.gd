class_name BuildSystem
extends SimSystem
## 建造与出售（命令驱动）。
##   命令 place_structure {team, def_id, cell: Vector2i}
##   命令 sell_structure  {team, entity_id}
## 结构定义字段：cost, build_time, size, requires:[def_id...]
## 放置规则：占地为空、在地图内、付得起、满足前置、靠近己方已有建筑(build_radius 格内)。

var economy: EconomyState
var structure_kind: StringName = &"structure"
var build_radius: float = 6.0
var sell_refund: float = 0.5


func _init(state: EconomyState) -> void:
	economy = state


func attach(world: SimWorld) -> void:
	world.set_service(&"build", self)
	world.register_command(&"place_structure", _on_place)
	world.register_command(&"sell_structure", _on_sell)


## 返回空串表示可放置，否则是失败原因（供 UI 提示）。
func can_place(world: SimWorld, team: int, def_id: StringName, cell: Vector2i) -> String:
	if not world.defs.has_def(structure_kind, def_id):
		return "未知建筑"
	var d := world.defs.get_def(structure_kind, def_id)
	var sz: Array = d.get("size", [1, 1])
	var size := Vector2i(int(sz[0]), int(sz[1]))
	if not world.grid.rect_is_free(cell, size):
		return "位置被占用"
	if not economy.can_afford(team, float(d.get("cost", 0))):
		return "资金不足"
	for req: String in d.get("requires", []):
		if not _owns_completed(world, team, StringName(req)):
			return "缺少前置建筑"
	if not _near_own_structure(world, team, cell, size):
		return "超出建造范围"
	return ""


## 不看位置，只看"现在能不能点这个建造项"：资金、前置。空串表示可以。
func afford_reason(world: SimWorld, team: int, def_id: StringName) -> String:
	var d := world.defs.get_def(structure_kind, def_id)
	if not economy.can_afford(team, float(d.get("cost", 0))):
		return "资金不足"
	for req: String in d.get("requires", []):
		if not _owns_completed(world, team, StringName(req)):
			return "需要先建造：%s" % world.defs.get_def(structure_kind, StringName(req)).get("name", req)
	return ""


func update(world: SimWorld, dt: float) -> void:
	for e in world.live:
		var left: float = e.state.get("build_left", 0.0)
		if left > 0.0:
			left -= dt
			e.state["build_left"] = maxf(left, 0.0)
			e.hp = minf(e.max_hp, e.hp + e.max_hp * dt / maxf(float(e.def.get("build_time", 1.0)), 0.1))
			if left <= 0.0:
				world.events.emit(&"structure_completed", {"entity": e})


func _on_place(world: SimWorld, cmd: Dictionary) -> void:
	var team: int = cmd["team"]
	var def_id := StringName(cmd["def_id"])
	var cell: Vector2i = cmd["cell"]
	if can_place(world, team, def_id, cell) != "":
		world.events.emit(&"place_rejected", {"reason": can_place(world, team, def_id, cell)})
		return
	var d := world.defs.get_def(structure_kind, def_id)
	economy.spend(team, float(d.get("cost", 0)))
	var e := world.spawn_structure(structure_kind, def_id, team, cell)
	var build_time := float(d.get("build_time", 0.0))
	if build_time > 0.0 and not cmd.get("instant", false):
		e.state["build_left"] = build_time
		e.hp = e.max_hp * 0.1
	world.events.emit(&"structure_placed", {"entity": e})


func _on_sell(world: SimWorld, cmd: Dictionary) -> void:
	var e := world.get_entity(int(cmd["entity_id"]))
	if e == null or e.team != int(cmd["team"]) or e.layer != &"structure" or e.def.get("unsellable", false):
		return
	economy.add_credits(e.team, float(e.def.get("cost", 0)) * sell_refund)
	world.events.emit(&"structure_sold", {"entity": e})
	world.remove(e.id)


func _owns_completed(world: SimWorld, team: int, def_id: StringName) -> bool:
	for e in world.live:
		if e.team == team and e.def_id == def_id and e.state.get("build_left", 0.0) <= 0.0:
			return true
	return false


func _near_own_structure(world: SimWorld, team: int, cell: Vector2i, size: Vector2i) -> bool:
	var center := Vector2(cell) + Vector2(size) * 0.5
	for e in world.live:
		if e.team == team and e.layer == &"structure" and e.pos.distance_to(center) <= build_radius + (e.size.x + size.x) * 0.5:
			return true
	return false
