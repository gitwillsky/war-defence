class_name ProjectileSystem
extends SimSystem
## 弹丸飞行与命中。bullet 追踪目标；artillery 飞向开火时锁定的位置。

func update(world: SimWorld, dt: float) -> void:
	for p in world.live:
		if not p.alive or p.kind != &"projectile":
			continue
		var s := p.state
		if s["homing"]:
			var t := world.get_entity(int(s["target_id"]))
			if t != null and t.alive:
				s["dest"] = t.pos
		var to: Vector2 = s["dest"] - p.pos
		var step: float = s["speed"] * dt
		if to.length() <= step:
			_impact(world, p)
		else:
			p.facing = to.normalized()
			p.pos += p.facing * step


func _impact(world: SimWorld, p: SimEntity) -> void:
	var s := p.state
	var warhead: StringName = s["warhead"]
	if s["splash"] > 0.0:
		Damage.splash(world, s["dest"], s["splash"], s["damage"], warhead, p.team)
	else:
		var t := world.get_entity(int(s["target_id"]))
		if t != null and t.alive:
			Damage.apply(world, t, s["damage"], warhead, p.team)
	world.events.emit(&"projectile_hit", {"pos": s["dest"], "splash": s["splash"], "weapon": s["weapon"], "visual": s["visual"]})
	world.remove(p.id)
