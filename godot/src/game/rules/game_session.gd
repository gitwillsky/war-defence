class_name GameSession
extends RefCounted
## 一局游戏：装配模拟世界、系统与初始布局。表现与输入不在此处。

var world: SimWorld
var economy := EconomyState.new()
var build: BuildSystem
var waves: WaveDirector
var rules: RulesSystem
var storm := LightningStorm.new()
var level: Dictionary
var superweapon_unlock_wave := 5
var props: Array[Dictionary] = []  # 地表物件 [{sprite, cell}]，同时在网格里标为不可通行


func _init(registry: DefinitionRegistry, level_id: StringName) -> void:
	level = registry.get_def(&"level", level_id)
	var map_size: Array = level.get("map", [40, 40])
	world = SimWorld.new(registry, int(map_size[0]), int(map_size[1]), int(level.get("seed", 1)))
	economy.add_credits(Team.PLAYER, float(level.get("start_credits", 5000)))
	var nav := NavService.new()
	nav.attach(world)
	build = BuildSystem.new(economy)
	build.attach(world)
	waves = WaveDirector.new(level)
	waves.attach(world)
	rules = RulesSystem.new(economy, waves)
	rules.attach(world)
	storm.attach(world)
	var sw: Dictionary = level.get("superweapon", {})
	storm.charge_time = float(sw.get("charge", 120.0))
	superweapon_unlock_wave = int(sw.get("unlock_wave", 5))
	world.events.subscribe(&"wave_started", _on_wave_started)
	# 顺序：建造 -> 经济 -> 波次 -> 超武 -> 战斗 -> 移动 -> 弹丸 -> 规则
	world.add_system(build)
	world.add_system(EconomySystem.new(economy))
	world.add_system(waves)
	world.add_system(storm)
	world.add_system(WeaponSystem.new())
	world.add_system(MoverSystem.new(nav))
	world.add_system(ProjectileSystem.new())
	world.add_system(rules)
	_scatter_props(level.get("decor", {}))
	for item: Dictionary in level.get("initial", []):
		var c: Array = item["cell"]
		world.spawn_structure(&"structure", StringName(item["def"]), Team.PLAYER, Vector2i(int(c[0]), int(c[1])))


func base_center() -> Vector2:
	return Vector2(world.grid.width, world.grid.height) * 0.5


## 建造栏条目：定义里 buildable != false 的建筑。
func buildable_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in world.defs.ids(&"structure"):
		if world.defs.get_def(&"structure", id).get("buildable", true):
			out.append(id)
	return out


func _on_wave_started(p: Dictionary) -> void:
	if int(p["index"]) >= superweapon_unlock_wave:
		storm.unlock()


## 按关卡种子在基地以外随机放置树木：挡路，让敌军要绕行，也让地面不单调。
func _scatter_props(decor: Dictionary) -> void:
	var sprites: Array = decor.get("sprites", [])
	if sprites.is_empty():
		return
	var center := base_center()
	var margin := int(decor.get("edge_margin", 3))
	var clear := float(decor.get("clear_radius", 9.0))
	var rng := SimRng.new(int(level.get("seed", 1)) * 31 + 5)
	var placed := 0
	var attempts := 0
	while placed < int(decor.get("count", 0)) and attempts < 2000:
		attempts += 1
		var cell := Vector2i(rng.randi_range_value(margin, world.grid.width - 1 - margin), rng.randi_range_value(margin, world.grid.height - 1 - margin))
		if Vector2(cell).distance_to(center) < clear or world.grid.is_terrain_blocked(cell):
			continue
		world.grid.set_terrain_blocked(cell, true)
		props.append({"sprite": sprites[rng.randi_range_value(0, sprites.size() - 1)], "cell": cell})
		placed += 1
