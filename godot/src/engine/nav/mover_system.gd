class_name MoverSystem
extends SimSystem
## 移动：地面单位沿流场前进，空中单位直线飞向目标。
## def.mover = {speed: 格/秒, stop_to_fire: bool}
## 被建筑挡住时记录 state.obstruction，由战斗系统优先攻击它。

var nav: NavService


func _init(nav_service: NavService) -> void:
	nav = nav_service


func update(world: SimWorld, dt: float) -> void:
	for e in world.live:
		if not e.alive or not e.def.has("mover") or e.state.get("build_left", 0.0) > 0.0:
			continue
		var m: Dictionary = e.def["mover"]
		if m.get("stop_to_fire", false) and e.state.get("engaged", false):
			continue
		var speed: float = float(m.get("speed", 1.0)) * float(e.state.get("speed_mult", 1.0))
		if e.layer == &"air":
			_move_air(world, e, speed, dt)
		else:
			_move_ground(world, e, speed, dt)


func _move_air(world: SimWorld, e: SimEntity, speed: float, dt: float) -> void:
	var target := nav.nearest_objective(world, e.team, e.pos)
	if target == null:
		return
	var to := target.pos - e.pos
	if to.length() > 0.5:
		e.facing = to.normalized()
		e.pos += e.facing * minf(speed * dt, to.length())


func _move_ground(world: SimWorld, e: SimEntity, speed: float, dt: float) -> void:
	var field := nav.field_for(world, e.team)
	if not field.has_goals():
		return
	var cell := Vector2i(floori(e.pos.x), floori(e.pos.y))
	if not world.grid.in_bounds(cell) or field.is_goal(cell):
		return
	var next := field.best_neighbor(cell)
	if next == cell:
		return
	var occupant := world.grid.occupant_at(next)
	if occupant != 0 and not field.is_goal(next):
		var blocker := world.get_entity(occupant)
		if blocker != null and blocker.team != e.team:
			e.state["obstruction"] = occupant
			return
	e.state.erase("obstruction")
	if occupant != 0:  # 目标建筑本身
		e.state["obstruction"] = occupant
		return
	var jitter: Vector2 = e.state.get("jitter", Vector2.ZERO)
	if not e.state.has("jitter"):
		jitter = Vector2(world.rng.randf_range_value(-0.3, 0.3), world.rng.randf_range_value(-0.3, 0.3))
		e.state["jitter"] = jitter
	var target_pos := Vector2(next) + Vector2(0.5, 0.5) + jitter
	var to := target_pos - e.pos
	var dist := to.length()
	if dist > 0.001:
		e.facing = to / dist
		e.pos += e.facing * minf(speed * dt, dist)
