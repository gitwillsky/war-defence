class_name FxNode
extends Node2D
## 一次性特效：光束 / 曳光（线条）与精灵动画（爆炸等，来自素材包）。

enum Kind { BEAM, TRACER, SPRITE }

var kind: Kind = Kind.SPRITE
var ttl := 0.4
var _life := 0.0
var from_pt := Vector2.ZERO
var to_pt := Vector2.ZERO
var color := Color(0.4, 0.9, 1.0)
var sprite: SpriteSet
var scale_mult := 1.0


func _process(delta: float) -> void:
	_life += delta
	if kind == Kind.SPRITE and sprite != null:
		ttl = sprite.anim_length(&"play")
	if _life >= ttl:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_life / maxf(ttl, 0.001), 0.0, 1.0)
	match kind:
		Kind.BEAM:
			var c := color
			c.a = 1.0 - k
			draw_line(from_pt, to_pt, c, 7.0 * (1.0 - k) + 1.0)
			draw_line(from_pt, to_pt, Color(1, 1, 1, 1.0 - k), 2.0)
		Kind.TRACER:
			var c2 := color
			c2.a = 1.0 - k
			draw_line(from_pt, from_pt.lerp(to_pt, 0.6), c2, 2.0)
		Kind.SPRITE:
			if sprite == null:
				return
			var rect := sprite.frame_rect(&"play", 0, _life)
			var size := Vector2(sprite.frame_size) * scale_mult
			draw_texture_rect_region(sprite.texture, Rect2(to_pt - sprite.anchor * scale_mult, size), rect)
