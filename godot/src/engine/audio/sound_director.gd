class_name SoundDirector
extends RefCounted
## 把模拟事件翻译成声音：武器定义的 sound / impact_sound，实体定义的 death_sound。
## 引擎不关心具体声音是什么，只读定义里的 id 字符串。

var _player: SoundPlayer
var _world: SimWorld


func _init(world: SimWorld, player: SoundPlayer) -> void:
	_world = world
	_player = player
	world.events.subscribe(&"weapon_fired", _on_fired)
	world.events.subscribe(&"projectile_hit", _on_hit)
	world.events.subscribe(&"entity_died", _on_died)


func _on_fired(p: Dictionary) -> void:
	var w := _world.defs.get_def(&"weapon", StringName(p["weapon"]))
	_player.play(String(w.get("sound", "")))


func _on_hit(p: Dictionary) -> void:
	var w := _world.defs.get_def(&"weapon", StringName(p["weapon"]))
	_player.play(String(w.get("impact_sound", "")))


func _on_died(p: Dictionary) -> void:
	var e: SimEntity = p["entity"]
	if e.kind != &"projectile":
		_player.play(String(e.def.get("death_sound", "")))
