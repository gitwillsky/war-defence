class_name AssetProvider
extends RefCounted
## 素材提供者：读取素材包(manifest.json)，把 id 解析成 SpriteSet / 音频。
## 引擎其余部分只认 id，不知道素材来自哪里；素材包缺失时返回 null，由调用方降级。

const PACKS_ROOT := "res://packs"

var pack_id := ""
var _sprites: Dictionary = {}  # id -> SpriteSet
var _sounds: Dictionary = {}   # id -> Array[AudioStream]
var _frame_cache: Dictionary = {}
var _sprite_meta: Dictionary = {}
var _sound_meta: Dictionary = {}
var _root := ""


func load_pack(id: String) -> bool:
	_root = PACKS_ROOT.path_join(id)
	var manifest_path := _root.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not (manifest is Dictionary) or int(manifest.get("format_version", 0)) != 1:
		push_error("AssetProvider: manifest 无效或版本不符 %s" % manifest_path)
		return false
	pack_id = id
	_sprite_meta = manifest.get("sprites", {})
	_sound_meta = manifest.get("sounds", {})
	return true


func has_pack() -> bool:
	return pack_id != ""


func get_sprite(id: String) -> SpriteSet:
	if _sprites.has(id):
		return _sprites[id]
	var meta: Variant = _sprite_meta.get(id)
	var result: SpriteSet = null
	if meta is Dictionary:
		result = _build_sprite(meta)
	_sprites[id] = result
	return result


## 精灵第 index 帧，作为 UI 可用的纹理（图标、界面部件）。
func get_frame_texture(id: String, index: int = 0) -> Texture2D:
	var s := get_sprite(id)
	if s == null:
		return null
	var key := "%s#%d" % [id, index]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var tex := AtlasTexture.new()
	tex.atlas = s.texture
	tex.region = s.frame_region(index)
	_frame_cache[key] = tex
	return tex


func has_sprite(id: String) -> bool:
	return _sprite_meta.has(id)


## 随机取一个声音变体；没有该声音返回 null。
func get_sound(id: String) -> AudioStream:
	var variants := get_sound_variants(id)
	return null if variants.is_empty() else variants[randi() % variants.size()]


func get_sound_variants(id: String) -> Array[AudioStream]:
	if _sounds.has(id):
		return _sounds[id]
	var list: Array[AudioStream] = []
	var meta: Variant = _sound_meta.get(id)
	if meta is Dictionary:
		for f: String in meta.get("files", []):
			var stream := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(_root.path_join(f)))
			if stream != null:
				stream.loop = meta.get("music", false)
				list.append(stream)
	_sounds[id] = list
	return list


func sound_volume_db(id: String) -> float:
	var meta: Variant = _sound_meta.get(id)
	return float(meta.get("volume_db", 0.0)) if meta is Dictionary else 0.0


func _build_sprite(meta: Dictionary) -> SpriteSet:
	var path := ProjectSettings.globalize_path(_root.path_join(meta["atlas"]))
	var img := Image.load_from_file(path)
	if img == null:
		push_warning("AssetProvider: 图集读取失败 %s" % path)
		return null
	var s := SpriteSet.new()
	s.texture = ImageTexture.create_from_image(img)
	var fs: Array = meta["frame_size"]
	s.frame_size = Vector2i(int(fs[0]), int(fs[1]))
	s.columns = int(meta.get("columns", 1))
	var an: Array = meta.get("anchor", [fs[0] / 2.0, fs[1] / 2.0])
	s.anchor = Vector2(float(an[0]), float(an[1]))
	s.facings = int(meta.get("facings", 1))
	s.extra = meta.get("autotile", {})
	s.parts = meta.get("parts", {})
	s.additive = meta.get("blend", "") == "add"
	s.anims = meta.get("anims", {"idle": {"start": 0, "count": 1, "fps": 1, "loop": true}})
	return s
