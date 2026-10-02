class_name FxNode
extends Node2D
## 一次性（或循环）特效：光束、曳光弹，以及来自素材包的精灵动画（爆炸、枪口焰、烟、火…）。
## delay：延迟多久才开始出现（用于让命中特效等到弹道飞完）。叠加发光的精灵由素材包的 blend 字段决定。

enum Kind { BEAM, TRACER, SPRITE }

static var _additive: CanvasItemMaterial

var kind: Kind = Kind.SPRITE
var ttl := 0.4
var delay := 0.0
var loop := false
var _life := 0.0
var from_pt := Vector2.ZERO
var to_pt := Vector2.ZERO
var color := Color(0.4, 0.9, 1.0)
var width := 8.0
var sprite: SpriteSet
var scale_mult := 1.0


func _ready() -> void:
	if sprite != null and sprite.additive:
		if _additive == null:
			_additive = CanvasItemMaterial.new()
			_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _additive


func _process(delta: float) -> void:
	_life += delta
	if kind == Kind.SPRITE and sprite != null:
		ttl = sprite.anim_length(&"play")
	if loop:
		if _life >= delay + ttl:
			_life -= ttl
	elif _life >= delay + ttl:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _life - delay
	if t < 0.0:
		return
	var k := clampf(t / maxf(ttl, 0.001), 0.0, 1.0)
	match kind:
		Kind.BEAM:
			var a := 1.0 - k
			var c := color
			draw_line(from_pt, to_pt, Color(c.r, c.g, c.b, 0.16 * a), width * 2.4)
			draw_line(from_pt, to_pt, Color(c.r, c.g, c.b, 0.5 * a), width * (1.1 - 0.4 * k))
			draw_line(from_pt, to_pt, Color(1, 1, 1, a), maxf(2.0, width * 0.3))
			draw_circle(to_pt, width * (1.0 + 0.6 * k) * a, Color(c.r, c.g, c.b, 0.45 * a))
			draw_circle(to_pt, width * 0.4 * a, Color(1, 1, 1, 0.9 * a))
			draw_circle(from_pt, width * 0.55 * a, Color(1, 1, 1, 0.6 * a))
		Kind.TRACER:
			var head := from_pt.lerp(to_pt, k)
			var tail := from_pt.lerp(to_pt, maxf(k - 0.3, 0.0))
			draw_line(tail, head, Color(color.r, color.g, color.b, 0.5), 3.5)
			draw_line(tail.lerp(head, 0.4), head, Color(1, 1, 1, 0.95), 1.6)
		Kind.SPRITE:
			if sprite == null:
				return
			var rect := sprite.frame_rect(&"play", 0, t)
			var size := Vector2(sprite.frame_size) * scale_mult
			draw_texture_rect_region(sprite.texture, Rect2(to_pt - sprite.anchor * scale_mult, size), rect)
