class_name SoundPlayer
extends Node
## 音效播放：固定数量的发声通道 + 同一声音的最小间隔（防止几十个单位同时开火时爆音）。
## 另有一个独立的音乐通道。

const VOICES := 24
const MIN_GAP := 0.06

var assets: AssetProvider
var sfx_volume_db := 0.0
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}  # id -> 时间
var _music := AudioStreamPlayer.new()


func setup(provider: AssetProvider) -> void:
	assets = provider
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	add_child(_music)


func play(id: String, volume_offset_db: float = 0.0) -> void:
	if assets == null or id == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -10.0)) < MIN_GAP:
		return
	var stream := assets.get_sound(id)
	if stream == null:
		return
	_last_played[id] = now
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = sfx_volume_db + assets.sound_volume_db(id) + volume_offset_db
	p.play()


func play_music(id: String) -> void:
	var stream := assets.get_sound(id) if assets != null else null
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = assets.sound_volume_db(id) - 6.0
	_music.play()


func stop_music() -> void:
	_music.stop()
