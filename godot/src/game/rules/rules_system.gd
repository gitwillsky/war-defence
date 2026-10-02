class_name RulesSystem
extends SimSystem
## 对局规则：击杀赏金、胜负判定。
##   赏金 = 被击杀者造价 × bounty_ratio，发给击杀方
##   失败：玩家没有任何带 objective 标记的建筑
##   胜利：所有波次已刷出，且场上没有敌方单位

signal game_over(won: bool)

var economy: EconomyState
var waves: WaveDirector
var bounty_ratio := 0.1
var finished := false
var kills := 0


func _init(state: EconomyState, director: WaveDirector) -> void:
	economy = state
	waves = director


func attach(world: SimWorld) -> void:
	world.events.subscribe(&"entity_died", _on_died)


func update(world: SimWorld, _dt: float) -> void:
	if finished:
		return
	var has_objective := false
	var enemies := 0
	for e in world.live:
		if not e.alive:
			continue
		if e.team == Team.PLAYER and e.layer == &"structure" and e.def.get("objective", false):
			has_objective = true
		elif e.team == Team.ENEMY and e.kind == &"unit":
			enemies += 1
	if not has_objective:
		_finish(false)
	elif waves.all_spawned() and enemies == 0:
		_finish(true)


func _finish(won: bool) -> void:
	finished = true
	game_over.emit(won)


func _on_died(p: Dictionary) -> void:
	var e: SimEntity = p["entity"]
	if e.team == Team.ENEMY and e.kind == &"unit":
		economy.add_credits(Team.PLAYER, float(e.def.get("cost", 0)) * bounty_ratio)
		kills += 1
