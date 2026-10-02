class_name SimWorld
extends RefCounted
## 模拟世界：实体、网格、系统、命令队列。固定步长推进，不依赖任何 Node。

signal entity_spawned(entity: SimEntity)

const STEP := 1.0 / 30.0

var defs: DefinitionRegistry
var events := EventBus.new()
var rng := SimRng.new(1)
var grid: Grid
var spatial := SpatialHash.new()
var entities: Dictionary = {}  # int -> SimEntity
var live: Array[SimEntity] = []  # 本 tick 开始时的存活实体快照
var tick: int = 0
var time: float = 0.0
var systems: Array[SimSystem] = []

var _next_id := 1
var _pending_remove: Array[int] = []
var _commands: Array[Dictionary] = []
var _handlers: Dictionary = {}  # StringName -> Callable
var _services: Dictionary = {}


func _init(registry: DefinitionRegistry, w: int, h: int, seed_value: int = 1) -> void:
	defs = registry
	grid = Grid.new(w, h)
	rng = SimRng.new(seed_value)


func add_system(system: SimSystem) -> void:
	systems.append(system)


func set_service(name: StringName, service: Object) -> void:
	_services[name] = service


func get_service(name: StringName) -> Object:
	return _services.get(name)


func register_command(type: StringName, handler: Callable) -> void:
	_handlers[type] = handler


func submit(command: Dictionary) -> void:
	_commands.append(command)


## 创建实体并登记。占地实体（size 大于 1x1 或 occupies=true）会写入网格。
func spawn(kind: StringName, def_id: StringName, team: int, pos: Vector2) -> SimEntity:
	var e := SimEntity.new()
	e.id = _next_id
	_next_id += 1
	e.kind = kind
	e.def_id = def_id
	e.def = defs.get_def(kind, def_id) if defs.has_def(kind, def_id) else {}
	e.team = team
	e.pos = pos
	e.max_hp = float(e.def.get("hp", 1.0))
	e.hp = e.max_hp
	e.armor = StringName(e.def.get("armor", "none"))
	e.layer = StringName(e.def.get("layer", "ground"))
	var sz: Array = e.def.get("size", [1, 1])
	e.size = Vector2i(int(sz[0]), int(sz[1]))
	entities[e.id] = e
	entity_spawned.emit(e)
	events.emit(&"entity_spawned", {"entity": e})
	return e


func spawn_structure(kind: StringName, def_id: StringName, team: int, cell: Vector2i) -> SimEntity:
	var e := spawn(kind, def_id, team, Vector2(cell))
	e.cell = cell
	e.pos = e.footprint_center()
	e.layer = &"structure"
	grid.set_rect_occupant(cell, e.size, e.id)
	events.emit(&"grid_changed")
	return e


func remove(id: int) -> void:
	if entities.has(id) and not _pending_remove.has(id):
		_pending_remove.append(id)
		entities[id].alive = false


func get_entity(id: int) -> SimEntity:
	return entities.get(id)


## 圆形范围内的存活实体（精确距离，按 pos 计）。
func query_radius(pos: Vector2, radius: float) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var r2 := radius * radius
	for item: SimEntity in spatial.query(pos, radius):
		if item.alive and item.pos.distance_squared_to(pos) <= r2:
			out.append(item)
	return out


func step(dt: float = STEP) -> void:
	_rebuild_snapshot()
	_run_commands()
	for system in systems:
		system.update(self, dt)
	_flush_removed()
	tick += 1
	time += dt


func _rebuild_snapshot() -> void:
	live.clear()
	spatial.clear()
	for e: SimEntity in entities.values():
		if e.alive:
			live.append(e)
			spatial.insert(e, e.pos)


func _run_commands() -> void:
	var batch := _commands
	_commands = []
	for cmd in batch:
		var handler: Callable = _handlers.get(StringName(cmd.get("type", "")), Callable())
		if handler.is_valid():
			handler.call(self, cmd)


func _flush_removed() -> void:
	if _pending_remove.is_empty():
		return
	var grid_dirty := false
	for id in _pending_remove:
		var e: SimEntity = entities.get(id)
		if e == null:
			continue
		if e.layer == &"structure":
			grid.set_rect_occupant(e.cell, e.size, 0)
			grid_dirty = true
		entities.erase(id)
		events.emit(&"entity_removed", {"entity": e})
	_pending_remove.clear()
	if grid_dirty:
		events.emit(&"grid_changed")
