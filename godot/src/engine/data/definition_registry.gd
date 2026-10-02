class_name DefinitionRegistry
extends RefCounted
## 定义注册表：从 JSON 加载 kind -> id -> 定义(Dictionary)。
## JSON 文件格式：{"kind": "<种类>", "defs": {"<id>": {...}, ...}}
## 引擎不知道具体有哪些种类，由游戏层的数据决定。

var _defs: Dictionary = {}  # StringName kind -> Dictionary(id -> Dictionary)


func load_directory(dir_path: String) -> int:
	var count := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("DefinitionRegistry: 无法打开目录 %s" % dir_path)
		return 0
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			count += load_file(dir_path.path_join(file_name))
	return count


func load_file(path: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("kind") or not parsed.has("defs"):
		push_error("DefinitionRegistry: 格式错误 %s" % path)
		return 0
	var kind := StringName(parsed["kind"])
	if not _defs.has(kind):
		_defs[kind] = {}
	var added := 0
	for id: String in parsed["defs"]:
		_defs[kind][StringName(id)] = parsed["defs"][id]
		added += 1
	return added


func has_def(kind: StringName, id: StringName) -> bool:
	return _defs.has(kind) and _defs[kind].has(id)


func get_def(kind: StringName, id: StringName) -> Dictionary:
	if not has_def(kind, id):
		push_error("DefinitionRegistry: 缺少定义 %s/%s" % [kind, id])
		return {}
	return _defs[kind][id]


func ids(kind: StringName) -> Array:
	return _defs[kind].keys() if _defs.has(kind) else []
