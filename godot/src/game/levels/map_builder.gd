class_name MapBuilder
extends RefCounted
## 按关卡 terrain 配置生成地形：依次把图层（山体、河流、道路…）涂进 TerrainMap，后涂的覆盖先涂的；
## 再按山体/森林配置生成地表物件（岩壁、树）。同一份配置 + 种子得到同一张图。
##
## layer = {kind, shape: ring|outside|polyline|blob, ...}
##   ring:     radius, width, wobble [[频率, 振幅], ...]    以地图中心为圆心的环（河、环路）
##   outside:  radius, wobble, border                       半径以外全部（外围山脉）+ 贴边 border 格
##   polyline: points [[x,y],...], width                    折线（道路）
##   blob:     center [x,y], radius, wobble                 团块

var _w: int
var _h: int
var _center: Vector2
var _phases: Array[float] = []


## 返回地表物件列表 [{sprite, cell, flip?, scale?}]。
static func build(config: Dictionary, terrain: TerrainMap, kind_defs: Dictionary, seed_value: int) -> Array[Dictionary]:
	var b := MapBuilder.new()
	return b._run(config, terrain, kind_defs, seed_value)


func _run(config: Dictionary, terrain: TerrainMap, kind_defs: Dictionary, seed_value: int) -> Array[Dictionary]:
	_w = terrain.width
	_h = terrain.height
	_center = Vector2(_w, _h) * 0.5
	var rng := SimRng.new(seed_value * 17 + 3)
	for i in 16:
		_phases.append(rng.randf_range_value(0.0, TAU))
	var layers: Array = config.get("layers", [])
	for li in layers.size():
		var layer: Dictionary = layers[li]
		for y in _h:
			for x in _w:
				if _covers(layer, Vector2(x + 0.5, y + 0.5), li):
					terrain.set_kind(Vector2i(x, y), StringName(layer["kind"]))
	var props: Array[Dictionary] = []
	_place_rocks(config, terrain, rng, props)
	_place_pad(config, rng, props)
	for f: Dictionary in config.get("forests", []):
		_scatter(f, terrain, kind_defs, rng, props)
	return props


## 山体：边缘一圈立起岩壁，内部只零星放碎石（整片岩壁会堆成锯齿，也没必要）。
func _place_rocks(config: Dictionary, terrain: TerrainMap, rng: SimRng, props: Array[Dictionary]) -> void:
	var walls: Array = config.get("rocks", [])
	var bumps: Array = config.get("bumps", [])
	if walls.is_empty():
		return
	for y in _h:
		for x in _w:
			var c := Vector2i(x, y)
			if terrain.kind_at(c) != &"mountain":
				continue
			if _is_rim(terrain, c):
				props.append({"sprite": walls[rng.randi_range_value(0, walls.size() - 1)], "cell": c, "flip": rng.randi_range_value(0, 1) == 1})
			elif not bumps.is_empty() and rng.randf_range_value(0.0, 1.0) < 0.5:
				props.append({"sprite": bumps[rng.randi_range_value(0, bumps.size() - 1)], "cell": c, "flip": rng.randi_range_value(0, 1) == 1})


## 地图外的装饰带：延伸成山地，镜头平移到边缘时不会露出虚空。只有表现，没有逻辑格子。
func _place_pad(config: Dictionary, rng: SimRng, props: Array[Dictionary]) -> void:
	var pad := int(config.get("pad", 0))
	var walls: Array = config.get("rocks", [])
	var bumps: Array = config.get("bumps", [])
	if pad <= 0 or walls.is_empty():
		return
	for y in range(-pad, _h + pad):
		for x in range(-pad, _w + pad):
			if x >= 0 and y >= 0 and x < _w and y < _h:
				continue
			var depth := mini(mini(x + pad, _w + pad - 1 - x), mini(y + pad, _h + pad - 1 - y))
			var sprite := ""
			if depth < 2:
				sprite = walls[rng.randi_range_value(0, walls.size() - 1)]
			elif not bumps.is_empty() and rng.randf_range_value(0.0, 1.0) < 0.2:
				sprite = bumps[rng.randi_range_value(0, bumps.size() - 1)]
			if sprite != "":
				props.append({"sprite": sprite, "cell": Vector2i(x, y), "flip": rng.randi_range_value(0, 1) == 1})


func _is_rim(terrain: TerrainMap, c: Vector2i) -> bool:
	for dir in FlowField.DIRS:
		var n := c + dir
		if terrain.in_bounds(n) and terrain.kind_at(n) != &"mountain":
			return true
	return false


func _wobble(layer: Dictionary, theta: float, li: int) -> float:
	var r := 0.0
	var k := 0
	for w: Array in layer.get("wobble", []):
		r += float(w[1]) * sin(float(w[0]) * theta + _phases[(li * 3 + k) % _phases.size()])
		k += 1
	return r


func _covers(layer: Dictionary, p: Vector2, li: int) -> bool:
	match String(layer["shape"]):
		"ring":
			var d := p.distance_to(_center)
			var r := float(layer["radius"]) + _wobble(layer, (p - _center).angle(), li)
			return absf(d - r) <= float(layer["width"]) * 0.5
		"outside":
			var edge := minf(minf(p.x, p.y), minf(_w - p.x, _h - p.y))
			if edge <= float(layer.get("border", 0)):
				return true
			return p.distance_to(_center) >= float(layer["radius"]) + _wobble(layer, (p - _center).angle(), li)
		"polyline":
			var pts: Array = layer["points"]
			var half := float(layer["width"]) * 0.5
			for i in pts.size() - 1:
				var a := Vector2(float(pts[i][0]), float(pts[i][1]))
				var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= half:
					return true
			return false
		"blob":
			var c := Vector2(float(layer["center"][0]), float(layer["center"][1]))
			return p.distance_to(c) <= float(layer["radius"]) + _wobble(layer, (p - c).angle(), li)
	return false


## 在 forest 区域内按密度放树。避开：非平地、路面及其紧邻格、水边、基地保留区。树挡路。
func _scatter(f: Dictionary, terrain: TerrainMap, kind_defs: Dictionary, rng: SimRng, props: Array[Dictionary]) -> void:
	var sprites: Array = f.get("sprites", [])
	var keep := float(f.get("keep_clear", 0.0))
	var li := 12
	for y in _h:
		for x in _w:
			var c := Vector2i(x, y)
			var p := Vector2(x + 0.5, y + 0.5)
			if terrain.kind_at(c) != &"ground" or not _covers(f, p, li) or p.distance_to(_center) < keep:
				continue
			if rng.randf_range_value(0.0, 1.0) > float(f.get("density", 0.4)) or _near_other(terrain, kind_defs, c):
				continue
			terrain.set_kind(c, &"forest")
			props.append({"sprite": sprites[rng.randi_range_value(0, sprites.size() - 1)], "cell": c, "flip": rng.randi_range_value(0, 1) == 1})


func _near_other(terrain: TerrainMap, kind_defs: Dictionary, c: Vector2i) -> bool:
	for dir in FlowField.DIRS:
		var n := c + dir
		if terrain.in_bounds(n):
			var k := terrain.kind_at(n)
			if k == &"road" or kind_defs.get(k, {}).get("liquid", false):
				return true
	return false
