class_name TerrainView
extends Node2D
## 地表绘制：每格按类别取贴图；非液体格紧邻液体时换成岸线图块（按 8 邻格水陆组合查素材包给的拼接表）。
## kind_defs: 类别 -> {sprite, liquid?, edge?: 岸线素材 id, no_edge?: 不画岸线}

var terrain: TerrainMap
var kind_defs: Dictionary = {}
var assets: AssetProvider
var pad := 0  # 地图外还要画多少格地面（纯装饰）


func setup(map: TerrainMap, defs: Dictionary, asset_provider: AssetProvider) -> void:
	terrain = map
	kind_defs = defs
	assets = asset_provider
	queue_redraw()


func _draw() -> void:
	if terrain == null:
		return
	var ground := assets.get_sprite("terrain.ground")
	for y in range(-pad, terrain.height + pad):
		for x in range(-pad, terrain.width + pad):
			var c := Vector2i(x, y)
			if not terrain.in_bounds(c):
				var at := IsoProjection.to_screen(Vector2(x + 0.5, y + 0.5))
				draw_texture_rect_region(ground.texture, Rect2(at - ground.anchor, Vector2(ground.frame_size)), ground.frame_region(0))
				continue
			var d: Dictionary = kind_defs.get(terrain.kind_at(c), {})
			var set := _pick_set(c, d)
			if set == null:
				continue
			var h := absi((x * 73856093) ^ (y * 19349663))
			var frame := _shore_frame(c, set) if set.extra.has("table") else h % maxi(int(set.anims["idle"]["count"]), 1)
			if frame < 0:
				set = assets.get_sprite("terrain.ground")
				frame = 0
			var at := IsoProjection.to_screen(Vector2(x + 0.5, y + 0.5))
			draw_texture_rect_region(set.texture, Rect2(at - set.anchor, Vector2(set.frame_size)), set.frame_region(frame))


func _pick_set(c: Vector2i, d: Dictionary) -> SpriteSet:
	if not d.get("liquid", false) and not d.get("no_edge", false):
		var edge := _edge_sprite_near(c)
		if edge != "":
			return assets.get_sprite(edge)
	return assets.get_sprite(String(d.get("sprite", "")))


## 周围 8 格里有带 edge 的液体类别，就返回它的岸线素材 id。
func _edge_sprite_near(c: Vector2i) -> String:
	for dir in FlowField.DIRS:
		var n := c + dir
		if terrain.in_bounds(n):
			var nd: Dictionary = kind_defs.get(terrain.kind_at(n), {})
			if nd.get("liquid", false) and nd.has("edge"):
				return String(nd["edge"])
	return ""


func _shore_frame(c: Vector2i, set: SpriteSet) -> int:
	var offsets: Array = set.extra["neighbors"]
	var mask := 0
	for i in offsets.size():
		var o: Array = offsets[i]
		var n := c + Vector2i(int(o[0]), int(o[1]))
		if terrain.in_bounds(n) and kind_defs.get(terrain.kind_at(n), {}).get("liquid", false):
			mask |= 1 << i
	return int(set.extra["table"][mask])
