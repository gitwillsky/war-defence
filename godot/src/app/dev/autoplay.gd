extends SceneTree
## 开发用：脚本化机器人自动玩一局并截图/打印结果。
## 用法：godot --path godot -s res://src/app/dev/autoplay.gd [-- shots]  （截图需要窗口渲染，不能 --headless）

const PLAN := [
	["pillbox", Vector2i(16, 16)], ["barracks", Vector2i(23, 22)], ["pillbox", Vector2i(25, 16)],
	["pillbox", Vector2i(16, 25)], ["war_factory", Vector2i(15, 26)], ["pillbox", Vector2i(26, 25)],
	["power_plant", Vector2i(25, 19)], ["grand_cannon", Vector2i(14, 16)], ["prism_tower", Vector2i(20, 15)],
	["prism_tower", Vector2i(20, 26)], ["prism_tower", Vector2i(14, 20)], ["prism_tower", Vector2i(27, 22)],
	["patriot", Vector2i(16, 18)], ["patriot", Vector2i(22, 17)], ["patriot", Vector2i(19, 23)], ["grand_cannon", Vector2i(26, 14)],
	["grand_cannon", Vector2i(13, 24)], ["power_plant", Vector2i(27, 18)], ["grand_cannon", Vector2i(27, 26)],
	["prism_tower", Vector2i(12, 20)], ["prism_tower", Vector2i(29, 21)], ["patriot", Vector2i(21, 28)],
]
var _main: Node
var _t := 0.0
var _next_build := 2.0
var _shots := false
var _shot_i := 0
var _done: Array[String] = []
var _last_log := -1


func _initialize() -> void:
	_shots = OS.get_cmdline_user_args().has("shots")
	_main = load("res://src/app/main.gd").new()
	root.add_child(_main)


func _process(delta: float) -> bool:
	var s: GameSession = _main._session
	if s == null:
		return false
	_main._speed = 6.0
	_t += delta * 6.0
	if _t >= _next_build:
		_next_build = _t + 2.0
		_try_build(s)
	if int(_t) % 30 == 0 and int(_t) != _last_log:
		_last_log = int(_t)
		var en := {}
		for e in s.world.entities.values():
			if e.team == 1 and e.kind == &"unit":
				en[String(e.def_id)] = en.get(String(e.def_id), 0) + 1
		var yard_hp := 0.0
		for e in s.world.entities.values():
			if e.team == 0 and e.def.get("objective", false):
				yard_hp = e.hp
		var sc := {}
		for e in s.world.entities.values():
			if e.team == 0 and e.layer == &"structure":
				sc[String(e.def_id)] = sc.get(String(e.def_id), 0) + 1
		print(sc)
		print("t=%d wave=%d credits=%d structs=%d yard=%d enemies=%s power=%s" % [_t, s.waves.wave_index, s.economy.get_credits(0), _count(s), yard_hp, en, s.economy.power_ratio(0)])
	if _shots and _t > 60.0 * (_shot_i + 1):
		_shot_i += 1
		root.get_viewport().get_texture().get_image().save_png("/tmp/wd_shot_%d.png" % _shot_i)
	if s.rules.finished or _t > 1500.0:
		print("RESULT finished=%s yard=%s t=%.0f wave=%d/%d kills=%d credits=%d structures=%d" % [
			s.rules.finished, _has_yard(s), _t, s.waves.wave_index, s.waves.total_waves(), s.rules.kills, s.economy.get_credits(0), _count(s)])
		if _shots:
			root.get_viewport().get_texture().get_image().save_png("/tmp/wd_shot_end.png")
		quit()
	return false


func _has_yard(s: GameSession) -> bool:
	for e in s.world.entities.values():
		if e.team == 0 and e.def.get("objective", false):
			return true
	return false


func _count(s: GameSession) -> int:
	var n := 0
	for e in s.world.entities.values():
		if e.team == 0 and e.layer == &"structure":
			n += 1
	return n


func _try_build(s: GameSession) -> void:
	if _done.size() >= PLAN.size():
		_spend_extra(s)
		return
	for item in PLAN:
		var key := "%s%s" % [item[0], item[1]]
		if _done.has(key):
			continue
		var cell: Vector2i = item[1]
		var reason := s.build.can_place(s.world, 0, StringName(item[0]), cell)
		if reason == "":
			s.world.submit({"type": "place_structure", "team": 0, "def_id": item[0], "cell": cell})
			_done.append(key)
		elif reason == "位置被占用" or reason == "超出建造范围" or reason == "未知建筑":
			_done.append(key)
		else:
			return


var _extra_i := 0
const EXTRA_TYPES := ["patriot", "prism_tower", "patriot", "grand_cannon", "prism_tower", "power_plant"]


## 计划之外：把钱花在基地外圈的防御上（找一个合法位置就放）。
func _spend_extra(s: GameSession) -> void:
	var def := StringName(EXTRA_TYPES[_extra_i % EXTRA_TYPES.size()])
	var c := s.base_center()
	for ring in range(4, 11):
		for k in 24:
			var a := TAU * (k + 0.5 * (ring % 2)) / 24.0
			var cell := Vector2i(roundi(c.x + cos(a) * ring) - 1, roundi(c.y + sin(a) * ring) - 1)
			if s.build.can_place(s.world, 0, def, cell) == "":
				s.world.submit({"type": "place_structure", "team": 0, "def_id": String(def), "cell": cell})
				_extra_i += 1
				return
	_extra_i += 1
