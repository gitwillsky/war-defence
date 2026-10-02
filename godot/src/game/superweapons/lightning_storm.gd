class_name LightningStorm
extends SimSystem
## 超时空风暴式超级武器：蓄能完成后玩家指定落点，持续数秒随机落雷。
##   命令 fire_superweapon {team, pos}
## 落雷：伤害对圈内所有敌方实体；事件 strike {pos} 供表现层播放特效。

signal ready_changed(ready: bool)

var charge_time := 120.0
var unlocked := false
var charge := 0.0
var radius := 4.0
var duration := 6.0
var strike_interval := 0.35
var strike_damage := 400.0
var strike_radius := 1.6
var _storms: Array[Dictionary] = []  # {pos, left, next}


func attach(world: SimWorld) -> void:
	world.register_command(&"fire_superweapon", _on_fire)


func is_ready() -> bool:
	return unlocked and charge >= charge_time


func unlock() -> void:
	unlocked = true


func update(world: SimWorld, dt: float) -> void:
	if unlocked and charge < charge_time:
		charge += dt
		if charge >= charge_time:
			ready_changed.emit(true)
	for s in _storms:
		s["left"] -= dt
		s["next"] -= dt
		if s["next"] <= 0.0:
			s["next"] = strike_interval
			var offset := Vector2.from_angle(world.rng.randf_range_value(0.0, TAU)) * radius * sqrt(world.rng.randf_value())
			var at: Vector2 = s["pos"] + offset
			world.events.emit(&"strike", {"pos": at})
			Damage.splash(world, at, strike_radius, strike_damage, &"lightning", Team.PLAYER, 0.3)
	_storms = _storms.filter(func(s: Dictionary) -> bool: return s["left"] > 0.0)


func _on_fire(_world: SimWorld, cmd: Dictionary) -> void:
	if not is_ready():
		return
	charge = 0.0
	ready_changed.emit(false)
	_storms.append({"pos": cmd["pos"], "left": duration, "next": 0.0})
