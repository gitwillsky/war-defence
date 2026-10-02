class_name WorldView
extends Node2D
## 世界表现：地形、实体视图、特效。订阅模拟事件，只读模拟状态，从不修改它。
## 特效的"长什么样"由武器定义里的 visual 字段给出（beam/tracer/arc/…），引擎不理解具体游戏含义。

var world: SimWorld
var assets: AssetProvider
var _entities := Node2D.new()
var _fx := Node2D.new()
var _views: Dictionary = {}  # entity id -> EntityView
var _terrain: Array[SpriteSet] = []  # [0] 主地面，其余为点缀变体
const VARIANT_PERCENT := 5


func setup(sim: SimWorld, asset_provider: AssetProvider) -> void:
	world = sim
	assets = asset_provider
	var base := assets.get_sprite("terrain.ground")
	if base != null:
		_terrain.append(base)
		var i := 1
		while assets.has_sprite("terrain.ground_%d" % i):
			_terrain.append(assets.get_sprite("terrain.ground_%d" % i))
			i += 1
	_entities.y_sort_enabled = true
	y_sort_enabled = true
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
	queue_redraw()


func _process(delta: float) -> void:
	for view: EntityView in _views.values():
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
		_entities.add_child(node)


func _draw() -> void:
	if _terrain.is_empty():
		return
	for y in world.grid.height:
		for x in world.grid.width:
			var hash_value := absi((x * 73856093) ^ (y * 19349663)) % 100
			var set := _terrain[0]
			if _terrain.size() > 1 and hash_value < VARIANT_PERCENT:
				set = _terrain[1 + hash_value % (_terrain.size() - 1)]
			var c := IsoProjection.to_screen(Vector2(x + 0.5, y + 0.5))
			draw_texture_rect_region(set.texture, Rect2(c - set.anchor, Vector2(set.frame_size)), set.frame_rect(&"idle", 0, 0.0))


func _add_view(e: SimEntity) -> void:
	var v := EntityView.new()
	_entities.add_child(v)
	v.setup(e, assets)
	_views[e.id] = v


func _on_spawned(p: Dictionary) -> void:
	_add_view(p["entity"])


func _on_removed(p: Dictionary) -> void:
	var e: SimEntity = p["entity"]
	var v: EntityView = _views.get(e.id)
	if v != null:
		v.queue_free()
		_views.erase(e.id)


func _spawn_line_fx(kind: FxNode.Kind, from_grid: Vector2, to_grid: Vector2, ttl: float, color: Color, lift: float) -> void:
	var fx := FxNode.new()
	fx.kind = kind
	fx.ttl = ttl
	fx.color = color
	fx.from_pt = IsoProjection.to_screen(from_grid) + Vector2(0, -lift)
	fx.to_pt = IsoProjection.to_screen(to_grid) + Vector2(0, -lift * 0.5)
	_fx.add_child(fx)


func _spawn_sprite_fx(sprite_id: String, at_grid: Vector2, scale_mult: float = 1.0, lift: float = 0.0) -> void:
	var sprite := assets.get_sprite(sprite_id)
	if sprite == null:
		return
	var fx := FxNode.new()
	fx.kind = FxNode.Kind.SPRITE
	fx.sprite = sprite
	fx.scale_mult = scale_mult
	fx.to_pt = IsoProjection.to_screen(at_grid) + Vector2(0, -lift)
	_fx.add_child(fx)


func _on_fired(p: Dictionary) -> void:
	var src: SimEntity = p["source"]
	var lift := 22.0 if src.layer == &"structure" else 12.0
	match String(p["visual"]):
		"beam":
			_spawn_line_fx(FxNode.Kind.BEAM, p["from"], p["to"], 0.35, Color(0.4, 0.9, 1.0), lift + 14.0)
		"tracer":
			_spawn_line_fx(FxNode.Kind.TRACER, p["from"], p["to"], 0.12, Color(1.0, 0.9, 0.4), lift)


func _on_hit(p: Dictionary) -> void:
	if p["splash"] > 0.0:
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
