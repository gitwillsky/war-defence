class_name WeaponSystem
extends SimSystem
## 索敌 + 开火。def.weapon 指向 weapon 定义：
##   damage, range(格), cooldown(秒), warhead, targets:["ground","air","structure"],
##   projectile: {type: instant|bullet|artillery, speed, splash}, visual: 表现提示(引擎不解释)
## 优先攻击挡路的建筑(obstruction)，其次按 def.threat 高者优先，再按距离。

const RETARGET_INTERVAL := 0.3


func update(world: SimWorld, dt: float) -> void:
	for e in world.live:
		if not e.alive or not e.def.has("weapon") or e.state.get("build_left", 0.0) > 0.0:
			continue
		var weapon := world.defs.get_def(&"weapon", StringName(e.def["weapon"]))
		e.state["cooldown"] = maxf(0.0, e.state.get("cooldown", 0.0) - dt)
		var target := _valid_target(world, e, weapon)
		if target == null:
			e.state["retarget"] = e.state.get("retarget", 0.0) - dt
			if e.state["retarget"] <= 0.0 or e.state.has("obstruction"):
				e.state["retarget"] = RETARGET_INTERVAL
				target = _acquire(world, e, weapon)
				e.state["target_id"] = target.id if target != null else 0
		e.state["engaged"] = target != null
		var efficiency: float = e.state.get("efficiency", 1.0)
		if target != null and e.state["cooldown"] <= 0.0 and efficiency > 0.01:
			_fire(world, e, target, weapon)
			e.state["cooldown"] = float(weapon.get("cooldown", 1.0)) / efficiency
			e.facing = (target.pos - e.pos).normalized()


func _valid_target(world: SimWorld, e: SimEntity, weapon: Dictionary) -> SimEntity:
	var t := world.get_entity(int(e.state.get("target_id", 0)))
	if t == null or not t.alive or not _in_range(e, t, weapon, 1.15):
		return null
	return t


func _in_range(e: SimEntity, t: SimEntity, weapon: Dictionary, slack: float = 1.0) -> bool:
	return e.pos.distance_to(t.pos) - _radius(t) <= float(weapon.get("range", 1.0)) * slack + _radius(e) * 0.5


func _radius(e: SimEntity) -> float:
	return maxf(e.size.x, e.size.y) * 0.5 if e.layer == &"structure" else 0.3


func _acquire(world: SimWorld, e: SimEntity, weapon: Dictionary) -> SimEntity:
	var obstruction := world.get_entity(int(e.state.get("obstruction", 0)))
	if obstruction != null and obstruction.alive and _in_range(e, obstruction, weapon):
		return obstruction
	var allowed: Array = weapon.get("targets", ["ground", "structure"])
	var reach := float(weapon.get("range", 1.0)) + 3.0
	var best: SimEntity = null
	var best_score := -INF
	for c in world.query_radius(e.pos, reach):
		if c.team == e.team or c.kind == &"projectile" or not allowed.has(String(c.layer)):
			continue
		if not _in_range(e, c, weapon):
			continue
		var score := float(c.def.get("threat", 0.0)) * 10.0 - e.pos.distance_to(c.pos)
		if score > best_score:
			best_score = score
			best = c
	return best


func _fire(world: SimWorld, e: SimEntity, target: SimEntity, weapon: Dictionary) -> void:
	var proj: Dictionary = weapon.get("projectile", {"type": "instant"})
	var warhead := StringName(weapon.get("warhead", ""))
	var damage := float(weapon.get("damage", 1.0))
	world.events.emit(&"weapon_fired", {
		"source": e, "target": target, "weapon": StringName(e.def["weapon"]),
		"visual": weapon.get("visual", ""), "from": e.pos, "to": target.pos,
	})
	if proj.get("type", "instant") == "instant":
		var splash := float(proj.get("splash", 0.0))
		if splash > 0.0:
			Damage.splash(world, target.pos, splash, damage, warhead, e.team)
		else:
			Damage.apply(world, target, damage, warhead, e.team)
		return
	var p := world.spawn(&"projectile", &"", e.team, e.pos)
	p.layer = &"projectile"
	p.state = {
		"target_id": target.id, "dest": target.pos, "damage": damage, "warhead": warhead,
		"speed": float(proj.get("speed", 8.0)), "splash": float(proj.get("splash", 0.0)),
		"homing": proj.get("type", "") == "bullet", "visual": weapon.get("visual", ""),
		"start": e.pos, "weapon": StringName(e.def["weapon"]),
	}
