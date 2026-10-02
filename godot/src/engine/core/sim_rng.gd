class_name SimRng
extends RefCounted
## 种子化随机数：模拟层唯一的随机来源，保证相同输入得到相同结果。

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func randf_value() -> float:
	return _rng.randf()


func randf_range_value(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range_value(from: int, to: int) -> int:
	return _rng.randi_range(from, to)
