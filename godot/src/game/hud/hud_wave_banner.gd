class_name HudWaveBanner
extends Control
## 顶部居中的波次横幅：当前波数、各波进度点、来袭倒计时（随时间收缩的进度条）、场上敌军数。
## 只负责绘制，数值由 GameHud 每帧推入。

const GOLD := HudStyle.GOLD
const CUT := 12.0

var wave := 0            # 已开始的波数
var total := 1
var countdown := 0.0
var enemies := 0
var _cd_max := 1.0
var _last_wave := -1
var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(600, 84)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(wave_index: int, total_waves: int, seconds_left: float, enemy_count: int) -> void:
	wave = wave_index
	total = maxi(total_waves, 1)
	countdown = seconds_left
	enemies = enemy_count
	if wave_index != _last_wave or seconds_left > _cd_max:
		_last_wave = wave_index
		_cd_max = maxf(seconds_left, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)


func _draw() -> void:
	var w := size.x
	var h := size.y
	HudStyle.draw_plate(self, size, CUT)
	var font := get_theme_default_font()
	var finished := wave >= total
	_text(font, Vector2(22, 38), "第 %d 波" % mini(wave + 1, total) if not finished else "最后一波", 30, GOLD)
	_text(font, Vector2(22, 60), "共 %d 波" % total, 15, Color(0.7, 0.74, 0.8))
	_draw_pips(Vector2(150, 30))
	var cx := w - 250.0
	if finished:
		_text(font, Vector2(cx, 38), "消灭残敌", 26, Color(1.0, 0.55, 0.45))
	else:
		_text(font, Vector2(cx, 24), "下一波", 14, Color(0.7, 0.74, 0.8))
		_text(font, Vector2(cx, 54), "%d:%02d" % [int(ceilf(countdown)) / 60, int(ceilf(countdown)) % 60], 32, Color.WHITE)
		var bar := Rect2(cx, 64, 108, 6)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(countdown / _cd_max, 0.0, 1.0), bar.size.y)), Color(0.35, 0.8, 1.0))
	var ex := w - 112.0
	draw_line(Vector2(ex - 14, 14), Vector2(ex - 14, h - 14), Color(0.8, 0.64, 0.22, 0.5), 1.0)
	var danger := Color(1.0, 0.35, 0.3) if enemies > 0 else Color(0.55, 0.6, 0.65)
	draw_colored_polygon(PackedVector2Array([Vector2(ex, 36), Vector2(ex + 8, 28), Vector2(ex + 16, 36), Vector2(ex + 8, 44)]), danger)
	_text(font, Vector2(ex + 26, 44), "%d" % enemies, 28, danger)
	_text(font, Vector2(ex, 66), "场上敌军", 14, Color(0.7, 0.74, 0.8))


func _draw_pips(origin: Vector2) -> void:
	var avail := size.x - 150.0 - 270.0
	var gap := 4.0
	var pw := clampf((avail - gap * (total - 1)) / total, 6.0, 22.0)
	for i in total:
		var r := Rect2(origin + Vector2(i * (pw + gap), 0), Vector2(pw, 14))
		var col := Color(0.16, 0.2, 0.26)
		if i < wave - 1 or (i == wave - 1 and enemies == 0):
			col = Color(0.3, 0.75, 0.95)
		elif i == wave - 1:
			col = GOLD.lerp(Color(1.0, 0.5, 0.2), 0.5 + 0.5 * sin(_pulse))
		draw_rect(r, col)
		draw_rect(r, Color(0, 0, 0, 0.55), false, 1.0)


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
