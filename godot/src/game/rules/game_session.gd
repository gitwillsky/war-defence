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
var props: Array[Dictionary] = []  # 地表物件 [{sprite, cell, flip?}]，其格子在地形图里已标为阻挡类别
var terrain: TerrainMap
var map_pad := 0  # 地图外装饰带宽度（格）
var terrain_kinds: Dictionary = {}  # 地形类别 -> 定义


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
	_build_terrain(registry)
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


## 按关卡 terrain 配置生成地形（山、河、路、林），逻辑属性写进网格，物件交给表现层。
func _build_terrain(registry: DefinitionRegistry) -> void:
	for id: StringName in registry.ids(&"terrain"):
		terrain_kinds[id] = registry.get_def(&"terrain", id)
	map_pad = int((level.get("terrain", {}) as Dictionary).get("pad", 0))
	terrain = TerrainMap.new(world.grid.width, world.grid.height, &"ground")
	props = MapBuilder.build(level.get("terrain", {}), terrain, terrain_kinds, int(level.get("seed", 1)))
	terrain.apply_to_grid(world.grid, terrain_kinds)
