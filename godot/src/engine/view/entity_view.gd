class_name EntityView
extends Node2D
## 一个模拟实体的屏幕表现，全部来自素材包精灵。
## def.view = {sprite, turret: {sprite, offset: [x, y]}, lift: 像素（空中单位）, bar_y: 血条高度}

var entity: SimEntity
var _sprite: SpriteSet
var _turret: SpriteSet
var _turret_offset := Vector2.ZERO
var _lift := 0.0
var _bar_y := -40.0
var _t := 0.0
var _last_pos := Vector2.ZERO
var _moving := false


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
	_last_pos = e.pos
	refresh(0.0)


func refresh(delta: float) -> void:
	_t += delta
	position = IsoProjection.to_screen(entity.pos)
	_moving = entity.pos.distance_squared_to(_last_pos) > 0.000001
	_last_pos = entity.pos
	z_index = 4000 if entity.layer == &"air" else 0
	queue_redraw()


func _draw() -> void:
	if entity == null:
		return
	if entity.kind == &"projectile":
		_draw_projectile()
		return
	var under_construction: bool = entity.state.get("build_left", 0.0) > 0.0
	modulate.a = 0.55 if under_construction else 1.0
	if _sprite != null:
		_draw_sprite()
	_draw_bars(under_construction)


func _draw_sprite() -> void:
	var facing := IsoProjection.facing_index(entity.facing, _sprite.facings)
	var anim: StringName = &"move" if _moving else &"idle"
	if entity.layer == &"structure" and entity.hp_ratio() < 0.5 and _sprite.has_anim(&"damaged"):
		anim = &"damaged"
	var rect := _sprite.frame_rect(anim, facing, _t)
	var origin := -_sprite.anchor - Vector2(0, _lift)
	if _lift > 0.0:
		draw_texture_rect_region(_sprite.texture, Rect2(-_sprite.anchor, Vector2(_sprite.frame_size)), rect, Color(0, 0, 0, 0.3))
	draw_texture_rect_region(_sprite.texture, Rect2(origin, Vector2(_sprite.frame_size)), rect)
	if _turret != null:
		var tf := IsoProjection.facing_index(entity.facing, _turret.facings)
		var trect := _turret.frame_rect(&"idle", tf, 0.0)
		draw_texture_rect_region(_turret.texture, Rect2(-_turret.anchor + _turret_offset, Vector2(_turret.frame_size)), trect)


func _draw_projectile() -> void:
	var s := entity.state
	var h := 0.0
	var dir := Vector2.ZERO
	var dest: Vector2 = s.get("dest", entity.pos)
	if s.get("visual", "") == "arc":
		var total: float = maxf((dest - s.get("start", entity.pos)).length(), 0.001)
		var progress := 1.0 - (dest - entity.pos).length() / total
		h = sin(clampf(progress, 0.0, 1.0) * PI) * 46.0
	if (dest - entity.pos).length_squared() > 0.0001:
		dir = (IsoProjection.to_screen(dest) - IsoProjection.to_screen(entity.pos)).normalized() * 7.0
	var base := Vector2(0, -h - 8)
	draw_line(base - dir, base, Color(1.0, 0.85, 0.3, 0.9), 3.0)
	draw_line(base - dir * 0.4, base, Color.WHITE, 1.5)


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
