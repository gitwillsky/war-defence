class_name HudStyle
extends RefCounted
## 界面共用的外观：切角深色面板（金边）与银色金属按钮底板（取自原版选项卡的空白帧）。

const GOLD := Color(1.0, 0.86, 0.35)
const EDGE := Color(0.80, 0.64, 0.22)
const PLATE := Color(0.05, 0.07, 0.10, 0.9)


static func draw_plate(c: CanvasItem, size: Vector2, cut: float = 12.0) -> void:
	var w := size.x
	var h := size.y
	var outline := PackedVector2Array([Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w, h - cut),
		Vector2(w - cut, h), Vector2(cut, h), Vector2(0, h - cut), Vector2(0, cut)])
	c.draw_colored_polygon(outline, PLATE)
	c.draw_colored_polygon(PackedVector2Array([Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(0, cut)]), Color(1, 1, 1, 0.06))
	c.draw_polyline(outline + PackedVector2Array([outline[0]]), EDGE, 2.0, true)
	var inner := PackedVector2Array()
	for p in outline:
		inner.append(p.move_toward(size * 0.5, 4.0))
	c.draw_polyline(inner + PackedVector2Array([inner[0]]), Color(0.45, 0.36, 0.14, 0.7), 1.0, true)


static func style_plate(b: Button, plate: Texture2D, font_size: int = 18) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxTexture.new()
		sb.texture = plate
		sb.texture_margin_left = 6
		sb.texture_margin_right = 6
		sb.texture_margin_top = 6
		sb.texture_margin_bottom = 6
		sb.modulate_color = {"normal": Color.WHITE, "hover": Color(1.15, 1.1, 0.9), "pressed": Color(0.75, 0.75, 0.75), "disabled": Color(0.6, 0.6, 0.62)}[state]
		b.add_theme_stylebox_override(state, sb)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(0.35, 0.05, 0.05))
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.38, 0.4))
