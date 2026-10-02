class_name EventBus
extends RefCounted
## 轻量事件总线：主题 -> 回调列表。模块之间通过它解耦。

var _subs: Dictionary = {}  # StringName -> Array[Callable]


func subscribe(topic: StringName, callback: Callable) -> void:
	if not _subs.has(topic):
		_subs[topic] = []
	_subs[topic].append(callback)


func unsubscribe(topic: StringName, callback: Callable) -> void:
	if _subs.has(topic):
		_subs[topic].erase(callback)


func emit(topic: StringName, payload: Dictionary = {}) -> void:
	var list: Array = _subs.get(topic, [])
	for cb: Callable in list.duplicate():
		if cb.is_valid():
			cb.call(payload)
