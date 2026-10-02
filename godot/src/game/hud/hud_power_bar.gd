class_name HudPowerBar
extends Control
## 横向电力条，用原版 powerp 的 5 种段（空 / 绿 / 黄 / 红 / 灰）按比例拼出。
## 自左向右：已用电力（够用为绿、不够为红）；其后为富余供电（黄）；其余为空槽。

var pip_textures: Array[Texture2D] = []
var produced := 0.0
var consumed := 0.0
var segment_width := 6.0


func set_power(p: float, c: float) -> void:
	if p != produced or c != consumed:
		produced = p
		consumed = c
		queue_redraw()


func _draw() -> void:
	if pip_textures.size() < 4:
		return
	var n := maxi(int(size.x / segment_width), 1)
	var cap := maxf(maxf(produced, consumed) * 1.15, 100.0)
	var used_n := int(round(consumed / cap * n))
	var made_n := int(round(produced / cap * n))
	var low := consumed > produced
	for i in n:
		var from_bottom := i
		var frame := 0
		if from_bottom < used_n:
			frame = 3 if low else 1
		elif from_bottom < made_n:
			frame = 2
		draw_texture_rect(pip_textures[frame], Rect2(i * segment_width, 0, segment_width - 1.0, size.y), false)
