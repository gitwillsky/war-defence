class_name EntityView
extends Node2D
## 一个模拟实体的屏幕表现，全部来自素材包精灵。
## def.view = {sprite, turret: {sprite, offset: [x, y]}, lift: 像素（空中单位）, bar_y: 血条高度,
##   fire: {sprite, below?: 血量比例阈值（默认 0.5）} 受损时在建筑上燃烧的火焰}
## 主精灵的 parts（素材包给出）：bib 底座画在最下，overlays 是常驻循环动画层（on = "fire" 的只在开火时播一次），
## buildup 是建造过程动画，按建造进度取帧。

var entity: SimEntity
var _sprite: SpriteSet
var _turret: SpriteSet
var _turret_offset := Vector2.ZERO
var _lift := 0.0
var _bar_y := -40.0
var _t := 0.0
var _last_pos := Vector2.ZERO
var _moving := false
var _fire: FxNode
var _fire_below := 0.5
var _bib: SpriteSet
var _buildup: SpriteSet
var _overlays: Array[SpriteSet] = []
var _fire_overlays: Array[SpriteSet] = []
var _fired_t := INF  # 距上次开火的时间


func setup(e: SimEntity, assets: AssetProvider) -> void:
	entity = e
	var v: Dictionary = e.def.get("view", {})
	_lift = float(v.get("lift", 0.0))
	if v.has("sprite"):
		_sprite = assets.get_sprite(v["sprite"])
	var t: Dictionary = v.get("turret", {})
	if t.has("sprite"):
		_turret = assets.get_sprite(t["sprite"])
		var off: Array = t.get("offset", [0, 0])
		_turret_offset = Vector2(float(off[0]), float(off[1]))
	_bar_y = float(v.get("bar_y", -(_sprite.anchor.y * 0.75) if _sprite != null else -30.0)) - _lift
	if _sprite != null:
		_load_parts(assets)
	if v.has("fire") and _sprite != null:
		var f: Dictionary = v["fire"]
		var fs := assets.get_sprite(f.get("sprite", ""))
		if fs != null:
			_fire_below = float(f.get("below", 0.5))
			_fire = FxNode.new()
			_fire.kind = FxNode.Kind.SPRITE
			_fire.sprite = fs
			_fire.loop = true
			_fire.scale_mult = 0.7 + 0.25 * maxf(e.size.x, e.size.y)
			_fire.to_pt = Vector2(0, -_sprite.anchor.y * 0.3 - _lift)
			_fire.visible = false
			add_child(_fire)
	_last_pos = e.pos
	refresh(0.0)


func _load_parts(assets: AssetProvider) -> void:
	var parts := _sprite.parts
	_bib = assets.get_sprite(parts.get("bib", ""))
	_buildup = assets.get_sprite(parts.get("buildup", ""))
	for o: Dictionary in parts.get("overlays", []):
		var set := assets.get_sprite(o.get("sprite", ""))
		if set == null:
			continue
		if o.get("on", "") == "fire":
			_fire_overlays.append(set)
		else:
			_overlays.append(set)


## 表现层收到本实体开火时调用（播开火动画层）。
func notify_fired() -> void:
	_fired_t = 0.0


func refresh(delta: float) -> void:
	_t += delta
	_fired_t += delta
	position = IsoProjection.to_screen(entity.pos)
	_moving = entity.pos.distance_squared_to(_last_pos) > 0.000001
	_last_pos = entity.pos
	z_index = 4000 if entity.layer == &"air" else 0
	if _fire != null:
		_fire.visible = entity.hp_ratio() < _fire_below
	queue_redraw()


func _draw() -> void:
	if entity == null:
		return
	var under_construction: bool = entity.state.get("build_left", 0.0) > 0.0
	# 有建造动画就播动画；没有的才用半透明表示"建造中"
	modulate.a = 0.55 if under_construction and _buildup == null else 1.0
	if under_construction and _buildup != null:
		_draw_buildup()
	elif _sprite != null:
		_draw_sprite()
	_draw_bars(under_construction)


func _draw_sprite() -> void:
	var facing := IsoProjection.facing_index(entity.facing, _sprite.facings)
	var anim: StringName = &"move" if _moving else &"idle"
	if entity.layer == &"structure" and entity.hp_ratio() < 0.5 and _sprite.has_anim(&"damaged"):
		anim = &"damaged"
	var rect := _sprite.frame_rect(anim, facing, _t)
	var origin := -_sprite.anchor - Vector2(0, _lift)
	if _bib != null:
		_draw_part(_bib, _bib.frame_rect(anim, 0, 0.0))
	if _lift > 0.0:
		draw_texture_rect_region(_sprite.texture, Rect2(-_sprite.anchor, Vector2(_sprite.frame_size)), rect, Color(0, 0, 0, 0.3))
	draw_texture_rect_region(_sprite.texture, Rect2(origin, Vector2(_sprite.frame_size)), rect)
	for o in _overlays:
		_draw_part(o, o.frame_rect(anim, 0, _t))
	for o in _fire_overlays:
		if _fired_t < o.anim_length(anim):
			_draw_part(o, o.frame_rect(anim, 0, _fired_t))
	if _turret != null:
		var tf := IsoProjection.facing_index(entity.facing, _turret.facings)
		var trect := _turret.frame_rect(&"idle", tf, 0.0)
		draw_texture_rect_region(_turret.texture, Rect2(-_turret.anchor + _turret_offset, Vector2(_turret.frame_size)), trect)


func _draw_part(set: SpriteSet, rect: Rect2) -> void:
	draw_texture_rect_region(set.texture, Rect2(-set.anchor - Vector2(0, _lift), Vector2(set.frame_size)), rect)


func _draw_buildup() -> void:
	var total: float = maxf(float(entity.def.get("build_time", 1.0)), 0.001)
	var done := clampf(1.0 - float(entity.state["build_left"]) / total, 0.0, 1.0)
	var n := _buildup.anim_frames(&"build")
	_draw_part(_buildup, _buildup.frame_rect_at(&"build", int(done * n)))


func _draw_bars(under_construction: bool) -> void:
	var ratio := entity.hp_ratio()
	var w := 28.0 + 10.0 * (maxf(entity.size.x, entity.size.y) - 1.0 if entity.layer == &"structure" else 0.0)
	if under_construction:
		var total: float = maxf(float(entity.def.get("build_time", 1.0)), 0.001)
		var done := 1.0 - float(entity.state["build_left"]) / total
		draw_rect(Rect2(-w * 0.5, _bar_y, w, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, _bar_y, w * clampf(done, 0.0, 1.0), 4), Color(0.3, 0.7, 1.0))
		return
	if ratio >= 0.999:
		return
	draw_rect(Rect2(-w * 0.5, _bar_y, w, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w * 0.5, _bar_y, w * ratio, 4), Color(0.2, 0.9, 0.3).lerp(Color(0.95, 0.2, 0.1), 1.0 - ratio))
