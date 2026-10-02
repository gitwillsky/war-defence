class_name SpriteSet
extends RefCounted
## 一组精灵帧：网格图集 + 方向 + 动画。帧编号规则见 docs/design/asset-pipeline.md §9.1。

var texture: Texture2D
var frame_size := Vector2i(64, 64)
var columns := 1
var anchor := Vector2.ZERO  # 帧内"逻辑地面中心点"的像素坐标
var facings := 1
var anims: Dictionary = {}  # 名 -> {start, count, fps, loop}


func has_anim(anim: StringName) -> bool:
	return anims.has(String(anim))


## 指定动画/朝向/播放时间对应的图集区域。动画不存在时降级到 idle，再降级到第 0 帧。
func frame_rect(anim: StringName, facing: int, t: float) -> Rect2:
	var a: Dictionary = anims.get(String(anim), anims.get("idle", {"start": 0, "count": 1, "fps": 1, "loop": true}))
	var count: int = maxi(int(a.get("count", 1)), 1)
	var k := int(t * float(a.get("fps", 1))) % count if a.get("loop", true) else mini(int(t * float(a.get("fps", 1))), count - 1)
	var index: int = int(a.get("start", 0)) + (posmod(facing, facings) * count if facings > 1 else 0) + k
	var col := index % columns
	var row := index / columns
	return Rect2(Vector2(col * frame_size.x, row * frame_size.y), Vector2(frame_size))


func anim_length(anim: StringName) -> float:
	var a: Dictionary = anims.get(String(anim), {})
	return float(a.get("count", 1)) / maxf(float(a.get("fps", 1)), 0.001)


## 按图集里的绝对帧号取区域（界面素材等不走动画的用法）。
func frame_region(index: int) -> Rect2:
	var i := clampi(index, 0, maxi(frame_count() - 1, 0))
	return Rect2(Vector2((i % columns) * frame_size.x, (i / columns) * frame_size.y), Vector2(frame_size))


func frame_count() -> int:
	return maxi(columns * (int(texture.get_height()) / frame_size.y), 1) if texture != null else 1
