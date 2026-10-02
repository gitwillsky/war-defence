class_name IsoProjection
extends RefCounted
## 逻辑网格坐标 <-> 屏幕坐标（2:1 等距菱形，红警 2 的 60x30 地形格）。
## 约定：格 (i, j) 覆盖网格坐标 [i, i+1) x [j, j+1)，格中心为 (i+0.5, j+0.5)。

const TILE_W := 60.0
const TILE_H := 30.0


static func to_screen(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)


static func to_grid(s: Vector2) -> Vector2:
	var a := s.x / (TILE_W * 0.5)
	var b := s.y / (TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## 世界朝向编号：0 = 屏幕正上方（网格 (-1,-1) 方向），顺时针；facings 为方向数。
## 与素材管线渲染精灵时的朝向约定一致（docs/design/asset-pipeline.md §9.1）。
static func facing_index(grid_dir: Vector2, facings: int) -> int:
	if grid_dir.length_squared() < 0.000001:
		return 0
	var north := Vector2(-1, -1).normalized()
	var east := Vector2(1, -1).normalized()
	var angle := atan2(grid_dir.dot(east), grid_dir.dot(north))
	return posmod(roundi(angle / (TAU / facings)), facings)
