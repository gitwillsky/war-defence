class_name ProjectileView
extends Node2D
## 飞行中弹丸的屏幕表现：地面投影 + 抬高的弹体（素材包精灵，或发光弹头），抛射弹沿弧线飞行，可拖尾。
## fx 来自武器定义的 fx 字段：{projectile: 素材 id?, scale, arc: 像素, color, trail: 素材 id, trail_interval, trail_scale}

var entity: SimEntity
var fx: Dictionary = {}
var _sprite: SpriteSet
var _start_h := 14.0
var _end_h := 8.0
var _trail_cb: Callable
var _trail_left := 0.0
var _height := 0.0
var configured := false
var _barrel := Vector2.ZERO


func setup(e: SimEntity, weapon_fx: Dictionary, assets: AssetProvider, start_height: float, end_height: float, trail_callback: Callable) -> void:
	entity = e
	configured = true
	fx = weapon_fx
	_start_h = start_height
	_end_h = end_height
	_trail_cb = trail_callback
	if fx.has("projectile"):
		_sprite = assets.get_sprite(fx["projectile"])
	refresh(0.0)


func refresh(delta: float) -> void:
	position = IsoProjection.to_screen(entity.pos)
	var s := entity.state
	var dest: Vector2 = s.get("dest", entity.pos)
	var start: Vector2 = s.get("start", entity.pos)
	var total := maxf(start.distance_to(dest), 0.001)
	var progress := clampf(1.0 - entity.pos.distance_to(dest) / total, 0.0, 1.0)
	var arc := float(fx.get("arc", 0.0)) * clampf(total / 10.0, 0.4, 1.4)
	_height = lerpf(_start_h, _end_h, progress) + arc * sin(progress * PI)
	if fx.has("trail") and delta > 0.0:
		_trail_left -= delta
		if _trail_left <= 0.0:
			_trail_left = float(fx.get("trail_interval", 0.05))
			_trail_cb.call(String(fx["trail"]), position + Vector2(0, -_height) + _barrel, float(fx.get("trail_scale", 0.7)))
	# 弹丸在模拟里从实体中心出发；视觉上先把起点前移到炮口，随飞行逐渐归零
	_barrel = IsoProjection.to_screen(start + (dest - start).normalized() * float(fx.get("muzzle_forward", 0.0))) - IsoProjection.to_screen(start)
	_barrel *= 1.0 - clampf(progress * 4.0, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var p := Vector2(0, -_height) + _barrel
	if _sprite != null:
		var sc := float(fx.get("scale", 1.0))
		var rect := _sprite.frame_rect(&"idle", IsoProjection.facing_index(entity.facing, _sprite.facings), 0.0)
		draw_texture_rect_region(_sprite.texture, Rect2(p - _sprite.anchor * sc, Vector2(_sprite.frame_size) * sc), rect)
		return
	var dest: Vector2 = entity.state.get("dest", entity.pos)
	var dir := (IsoProjection.to_screen(dest) - IsoProjection.to_screen(entity.pos)).normalized()
	var arr: Array = fx.get("color", [1.0, 0.85, 0.35])
	var col := Color(float(arr[0]), float(arr[1]), float(arr[2]))
	var r := float(fx.get("size", 3.0))
	draw_line(p - dir * r * 3.0, p, Color(col.r, col.g, col.b, 0.45), r * 1.4)
	draw_circle(p, r, col)
	draw_circle(p, r * 0.5, Color.WHITE)
