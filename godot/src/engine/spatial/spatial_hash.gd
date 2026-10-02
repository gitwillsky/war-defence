class_name SpatialHash
extends RefCounted
## 空间哈希：按桶存实体，做半径查询，避免 O(n*m) 的全表扫描。每 tick 重建。

const BUCKET := 4.0

var _buckets: Dictionary = {}  # Vector2i -> Array


func clear() -> void:
	_buckets.clear()


func insert(item: Object, pos: Vector2) -> void:
	var key := _key(pos)
	if not _buckets.has(key):
		_buckets[key] = []
	_buckets[key].append(item)


## 返回 pos 周围 radius 范围内的桶中所有对象（粗筛，调用方再做精确距离判断）。
func query(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var lo := _key(pos - Vector2(radius, radius))
	var hi := _key(pos + Vector2(radius, radius))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var b: Variant = _buckets.get(Vector2i(x, y))
			if b != null:
				out.append_array(b)
	return out


func _key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / BUCKET), floori(pos.y / BUCKET))
