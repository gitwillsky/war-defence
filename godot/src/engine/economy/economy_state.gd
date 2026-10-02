class_name EconomyState
extends RefCounted
## 各阵营的资金与电力。由 EconomySystem 每 tick 刷新电力。

var credits: Dictionary = {}  # team -> float
var power_produced: Dictionary = {}
var power_consumed: Dictionary = {}


func get_credits(team: int) -> float:
	return credits.get(team, 0.0)


func add_credits(team: int, amount: float) -> void:
	credits[team] = get_credits(team) + amount


func can_afford(team: int, cost: float) -> bool:
	return get_credits(team) >= cost


func spend(team: int, cost: float) -> bool:
	if not can_afford(team, cost):
		return false
	credits[team] = get_credits(team) - cost
	return true


## 供电比：供给/需求，封顶 1；无需求时为 1。
func power_ratio(team: int) -> float:
	var need: float = power_consumed.get(team, 0.0)
	if need <= 0.0:
		return 1.0
	return clampf(power_produced.get(team, 0.0) / need, 0.0, 1.0)
