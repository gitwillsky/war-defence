class_name WaveDirector
extends SimSystem
## 波次导演：按关卡定义的时间表刷出敌人。
## 关卡 waves = [[{unit, count, edge: any|north|south|east|west, gap: 秒}, ...], ...]
## 命令 call_next_wave 可提前开始下一波。

signal wave_started(index: int, total: int)

var level: Dictionary
var spawn_team := Team.ENEMY
var wave_index := 0       # 已开始的波数
var countdown := 0.0      # 距下一波秒数
var _queue: Array[Dictionary] = []  # {time, unit, pos}
var _clock := 0.0


func _init(level_def: Dictionary) -> void:
	level = level_def
	countdown = float(level.get("first_wave_delay", 60.0))


func attach(world: SimWorld) -> void:
	world.register_command(&"call_next_wave", func(w: SimWorld, _c: Dictionary) -> void: _start_wave(w))


func total_waves() -> int:
	return (level.get("waves", []) as Array).size()


func all_spawned() -> bool:
	return wave_index >= total_waves() and _queue.is_empty()


func update(world: SimWorld, dt: float) -> void:
	_clock += dt
	if wave_index < total_waves():
		countdown -= dt
		if countdown <= 0.0:
			_start_wave(world)
	while not _queue.is_empty() and _queue[0]["time"] <= _clock:
		var item: Dictionary = _queue.pop_front()
		var e := world.spawn(&"unit", StringName(item["unit"]), spawn_team, item["pos"])
		e.facing = (Vector2(world.grid.width, world.grid.height) * 0.5 - e.pos).normalized()


func _start_wave(world: SimWorld) -> void:
	if wave_index >= total_waves():
		return
	var groups: Array = level["waves"][wave_index]
	wave_index += 1
	countdown = float(level.get("wave_interval", 45.0))
	for g: Dictionary in groups:
		var edge := _pick_edge(world, String(g.get("edge", "any")))
		var t := _clock
		for i in int(g["count"]):
			_queue.append({"time": t, "unit": g["unit"], "pos": _edge_point(world, edge)})
			t += float(g.get("gap", 1.0))
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	world.events.emit(&"wave_started", {"index": wave_index, "total": total_waves()})
	wave_started.emit(wave_index, total_waves())


func _pick_edge(world: SimWorld, edge: String) -> String:
	if edge != "any":
		return edge
	var names: Array = (level.get("spawns", {}) as Dictionary).keys() if level.has("spawns") else ["north", "south", "east", "west"]
	return names[world.rng.randi_range_value(0, names.size() - 1)]


func _edge_point(world: SimWorld, edge: String) -> Vector2:
	var spawns: Dictionary = level.get("spawns", {})
	if spawns.has(edge):
		var s: Array = spawns[edge]
		return Vector2(float(s[0]), float(s[1])) + Vector2(world.rng.randf_range_value(-0.8, 0.8), world.rng.randf_range_value(-0.8, 0.8))
	var w := float(world.grid.width)
	var h := float(world.grid.height)
	var along := world.rng.randf_range_value(3.0, w - 3.0)
	match edge:
		"north":
			return Vector2(along, 0.5)
		"south":
			return Vector2(along, h - 0.5)
		"east":
			return Vector2(w - 0.5, along)
		_:
			return Vector2(0.5, along)
