class_name SimSystem
extends RefCounted
## 系统基类：每个 tick 被 SimWorld 调用一次。子类覆写 update。

func update(_world: SimWorld, _dt: float) -> void:
	pass
