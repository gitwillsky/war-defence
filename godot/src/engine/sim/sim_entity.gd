class_name SimEntity
extends RefCounted
## 模拟实体：身份 + 空间 + 生命 + 所属定义。行为由各 System 根据 def 中的组件字段驱动。

var id: int = 0
var kind: StringName = &""      # 由游戏数据决定，如 structure / unit / projectile
var def_id: StringName = &""
var def: Dictionary = {}
var team: int = 0
var pos: Vector2 = Vector2.ZERO  # 网格坐标（浮点）
var cell: Vector2i = Vector2i.ZERO  # 占地左上格（占地实体使用）
var size: Vector2i = Vector2i.ONE
var hp: float = 1.0
var max_hp: float = 1.0
var armor: StringName = &"none"
var layer: StringName = &"ground"  # ground / air / structure
var facing: Vector2 = Vector2(0, 1)  # 网格坐标系中的朝向
var alive: bool = true
var state: Dictionary = {}  # 各 System 的私有运行时状态


func hp_ratio() -> float:
	return hp / maxf(max_hp, 0.001)


func center() -> Vector2:
	return pos


## 占地实体用：占地矩形（网格坐标）。
func footprint_center() -> Vector2:
	return Vector2(cell) + Vector2(size) * 0.5
