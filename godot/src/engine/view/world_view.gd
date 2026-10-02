class_name WorldView
extends Node2D
## 世界表现：地形、实体视图、特效。订阅模拟事件，只读模拟状态，从不修改它。
## 特效的"长什么样"由武器定义里的 visual 字段给出（beam/tracer/arc/…），引擎不理解具体游戏含义。

var world: SimWorld
var assets: AssetProvider
var _entities := Node2D.new()
var _fx := Node2D.new()
var _views: Dictionary = {}  # entity id -> EntityView
var _terrain_view := TerrainView.new()


## 地形图（含类别表）；在 setup 前设置。
func set_terrain(map: TerrainMap, kind_defs: Dictionary, pad: int = 0) -> void:
	_terrain_view.pad = pad
	_terrain_view.setup(map, kind_defs, assets)


func setup(sim: SimWorld, asset_provider: AssetProvider) -> void:
	world = sim
	assets = asset_provider
	_terrain_view.assets = asset_provider
	_entities.y_sort_enabled = true
	y_sort_enabled = true
	add_child(_terrain_view)
	add_child(_entities)
	add_child(_fx)
	_fx.z_index = 4096
	world.events.subscribe(&"entity_spawned", _on_spawned)
	world.events.subscribe(&"entity_removed", _on_removed)
	world.events.subscribe(&"weapon_fired", _on_fired)
	world.events.subscribe(&"projectile_hit", _on_hit)
	world.events.subscribe(&"entity_died", _on_died)
	world.events.subscribe(&"strike", _on_strike)
	for e in world.entities.values():
		_add_view(e)


func _process(delta: float) -> void:
	for view in _views.values():
		if view is ProjectileView and not view.configured:
			_configure_projectile(view)
		view.refresh(delta)


func map_bounds() -> Rect2:
	var pts := [Vector2(0, 0), Vector2(world.grid.width, 0), Vector2(world.grid.width, world.grid.height), Vector2(0, world.grid.height)]
	var r := Rect2(IsoProjection.to_screen(pts[0]), Vector2.ZERO)
	for p: Vector2 in pts:
		r = r.expand(IsoProjection.to_screen(p))
	return r


## 静态地表物件（树等）：[{sprite: 素材 id, cell: Vector2i}]。只是表现；是否挡路由模拟层的格子决定。
func add_props(props: Array) -> void:
	for p: Dictionary in props:
		var set := assets.get_sprite(p["sprite"])
		if set == null:
			continue
		var node := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = set.texture
		tex.region = set.frame_rect(&"idle", 0, 0.0)
		node.texture = tex
		node.centered = false
		node.offset = -set.anchor
		var c: Vector2i = p["cell"]
		node.position = IsoProjection.to_screen(Vector2(c.x + 0.5, c.y + 0.5))
		node.flip_h = p.get("flip", false)
		node.scale = Vector2.ONE * float(p.get("scale", 1.0))
		_entities.add_child(node)


func _add_view(e: SimEntity) -> void:
	if e.kind == &"projectile":
		# spawn 事件发出时弹丸的 state（武器、目标）还没写入，等第一次刷新再配置
		var pv := ProjectileView.new()
		_entities.add_child(pv)
		pv.position = IsoProjection.to_screen(e.pos)
		pv.entity = e
		_views[e.id] = pv
		return
	var v := EntityView.new()
	_entities.add_child(v)
	v.setup(e, assets)
	_views[e.id] = v


func _configure_projectile(pv: ProjectileView) -> void:
	var e := pv.entity
	var target := world.get_entity(int(e.state.get("target_id", 0)))
	pv.setup(e, _weapon_fx(StringName(e.state.get("weapon", ""))), assets, 14.0, _body_height(target) if target != null else 8.0, _spawn_trail)


func _weapon_fx(weapon_id: StringName) -> Dictionary:
	if weapon_id == &"" or not world.defs.has_def(&"weapon", weapon_id):
		return {}
	return world.defs.get_def(&"weapon", weapon_id).get("fx", {})


## 枪口 / 弹着点的离地高度（像素）：建筑炮塔高，步兵低，空中单位带自身升空量。
func _muzzle_height(e: SimEntity) -> float:
	var v: Dictionary = e.def.get("view", {})
	if v.has("muzzle_height"):
		return float(v["muzzle_height"])
	return 26.0 if e.layer == &"structure" else 14.0 + float(v.get("lift", 0.0))


func _body_height(e: SimEntity) -> float:
	var v: Dictionary = e.def.get("view", {})
	return 14.0 if e.layer == &"structure" else 8.0 + float(v.get("lift", 0.0))


func _on_spawned(p: Dictionary) -> void:
	_add_view(p["entity"])


func _on_removed(p: Dictionary) -> void:
	var e: SimEntity = p["entity"]
	var v: Node = _views.get(e.id)
	if v != null:
		v.queue_free()
		_views.erase(e.id)


func _spawn_trail(sprite_id: String, at_screen: Vector2, scale_mult: float) -> void:
	_spawn_sprite_screen(sprite_id, at_screen, scale_mult, 0.0)


func _spawn_line_fx(kind: FxNode.Kind, from_pt: Vector2, to_pt: Vector2, ttl: float, color: Color, width: float = 8.0) -> void:
	var fx := FxNode.new()
	fx.kind = kind
	fx.ttl = ttl
	fx.color = color
	fx.width = width
	fx.from_pt = from_pt
	fx.to_pt = to_pt
	_fx.add_child(fx)


func _spawn_sprite_screen(sprite_id: String, at_screen: Vector2, scale_mult: float = 1.0, delay: float = 0.0) -> void:
	var sprite := assets.get_sprite(sprite_id)
	if sprite == null:
		return
	var fx := FxNode.new()
	fx.kind = FxNode.Kind.SPRITE
	fx.sprite = sprite
	fx.scale_mult = scale_mult
	fx.to_pt = at_screen
	fx.delay = delay
	_fx.add_child(fx)


func _spawn_sprite_fx(sprite_id: String, at_grid: Vector2, scale_mult: float = 1.0, lift: float = 0.0) -> void:
	_spawn_sprite_screen(sprite_id, IsoProjection.to_screen(at_grid) + Vector2(0, -lift), scale_mult)


static func _color_of(arr: Array, fallback: Color) -> Color:
	return Color(float(arr[0]), float(arr[1]), float(arr[2])) if arr.size() >= 3 else fallback


## 开火：枪口焰/发射烟、光束、曳光弹；瞬发武器的弹着特效按弹道时间延后出现。
func _on_fired(p: Dictionary) -> void:
	var src: SimEntity = p["source"]
	var tgt: SimEntity = p["target"]
	var fx := _weapon_fx(p["weapon"])
	var sv: Node = _views.get(src.id)
	if sv is EntityView:
		sv.notify_fired()
	# 炮管有长度：起点沿瞄准方向（地面上）前移到炮口，而不是从车身中心射出
	var aim: Vector2 = (p["to"] - p["from"]).normalized()
	var from_s := IsoProjection.to_screen(p["from"] + aim * float(fx.get("muzzle_forward", 0.0))) + Vector2(0, -_muzzle_height(src))
	var to_s := IsoProjection.to_screen(p["to"]) + Vector2(0, -_body_height(tgt))
	var dir := (to_s - from_s).normalized()
	if fx.has("muzzle"):
		_spawn_sprite_screen(String(fx["muzzle"]), from_s + dir * float(fx.get("muzzle_offset", 12.0)), float(fx.get("muzzle_scale", 1.0)))
	if fx.has("launch"):
		_spawn_sprite_screen(String(fx["launch"]), IsoProjection.to_screen(p["from"]) + Vector2(0, -4), float(fx.get("launch_scale", 0.8)))
	var travel := 0.0
	if fx.has("beam"):
		var b: Dictionary = fx["beam"]
		_spawn_line_fx(FxNode.Kind.BEAM, from_s, to_s, float(b.get("ttl", 0.35)), _color_of(b.get("color", []), Color(0.4, 0.9, 1.0)), float(b.get("width", 8.0)))
	elif fx.has("tracer") and p.get("instant", false):
		var t: Dictionary = fx["tracer"]
		travel = clampf(from_s.distance_to(to_s) / 1500.0, 0.05, 0.25)
		_spawn_line_fx(FxNode.Kind.TRACER, from_s, to_s, travel, _color_of(t.get("color", []), Color(1.0, 0.9, 0.4)))
	if p.get("instant", false) and fx.has("impact"):
		_spawn_sprite_screen(String(fx["impact"]), to_s, float(fx.get("impact_scale", 1.0)), travel)


func _on_hit(p: Dictionary) -> void:
	var fx := _weapon_fx(p.get("weapon", &""))
	if fx.has("impact"):
		_spawn_sprite_fx(String(fx["impact"]), p["pos"], float(fx.get("impact_scale", 1.0)), 6.0)
	elif p["splash"] > 0.0:
		_spawn_sprite_fx("fx.explosion_large", p["pos"], 0.7)
	else:
		_spawn_sprite_fx("fx.explosion_small", p["pos"], 0.8)


func _on_died(p: Dictionary) -> void:
	var e: SimEntity = p["entity"]
	if e.kind == &"projectile":
		return
	if e.layer == &"structure":
		_spawn_sprite_fx("fx.explosion_large", e.pos, 0.6 + 0.35 * maxf(e.size.x, e.size.y))
	else:
		_spawn_sprite_fx("fx.explosion_small", e.pos, 1.0)


func _on_strike(p: Dictionary) -> void:
	_spawn_sprite_fx("fx.lightning_strike", p["pos"], 1.0, 0.0)
