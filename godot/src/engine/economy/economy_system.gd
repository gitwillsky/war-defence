class_name EconomySystem
extends SimSystem
## 电力与收入。
##   def.power  = {produce, consume}   建造完成后才计入
##   def.income = {per_second, needs_power}
## 耗电者的 state.efficiency 设为供电比，战斗等系统据此降效。

var economy: EconomyState


func _init(state: EconomyState) -> void:
	economy = state


func update(world: SimWorld, dt: float) -> void:
	var produced: Dictionary = {}
	var consumed: Dictionary = {}
	for e in world.live:
		if e.layer != &"structure" or e.state.get("build_left", 0.0) > 0.0:
			continue
		var p: Dictionary = e.def.get("power", {})
		produced[e.team] = produced.get(e.team, 0.0) + float(p.get("produce", 0.0))
		consumed[e.team] = consumed.get(e.team, 0.0) + float(p.get("consume", 0.0))
	economy.power_produced = produced
	economy.power_consumed = consumed
	for e in world.live:
		if e.layer != &"structure" or e.state.get("build_left", 0.0) > 0.0:
			continue
		var ratio := economy.power_ratio(e.team)
		if float(e.def.get("power", {}).get("consume", 0.0)) > 0.0:
			e.state["efficiency"] = ratio
		var income: Dictionary = e.def.get("income", {})
		if not income.is_empty():
			var mult := ratio if income.get("needs_power", false) else 1.0
			economy.add_credits(e.team, float(income.get("per_second", 0.0)) * mult * dt)
