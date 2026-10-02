class_name Damage
extends RefCounted
## 伤害结算：基础伤害 × 弹头对护甲的倍率。弹头定义：{"verses": {"<护甲>": 倍率}}。

static func apply(world: SimWorld, victim: SimEntity, base: float, warhead_id: StringName, source_team: int) -> void:
	if not victim.alive or victim.team == source_team:
		return
	var warhead := world.defs.get_def(&"warhead", warhead_id)
	var verses: Dictionary = warhead.get("verses", {})
	var amount := base * float(verses.get(String(victim.armor), 1.0))
	victim.hp -= amount
	world.events.emit(&"entity_damaged", {"entity": victim, "amount": amount})
	if victim.hp <= 0.0:
		victim.hp = 0.0
		world.events.emit(&"entity_died", {"entity": victim, "killer_team": source_team})
		world.remove(victim.id)


## 范围伤害：边缘衰减到 falloff（0..1）。
static func splash(world: SimWorld, center: Vector2, radius: float, base: float, warhead_id: StringName, source_team: int, falloff: float = 0.4) -> void:
	for e in world.query_radius(center, radius):
		if e.kind == &"projectile":
			continue
		var t := clampf(e.pos.distance_to(center) / maxf(radius, 0.001), 0.0, 1.0)
		apply(world, e, base * lerpf(1.0, falloff, t), warhead_id, source_team)
