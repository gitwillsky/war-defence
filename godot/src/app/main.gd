extends Node
## 启动与装配：加载数据与素材包 -> 创建一局 -> 视图/相机/HUD -> 固定步长推进模拟。

const PACK_ID := "ra2-ta4"
const LEVEL_ID := &"snow_01"

var _registry := DefinitionRegistry.new()
var _assets := AssetProvider.new()
var _session: GameSession
var _view: WorldView
var _camera: IsoCamera
var _placement: PlacementController
var _hud: GameHud
var _sound := SoundPlayer.new()
var _directors: Array = []
var _siren_cooldown := 0.0
var _root: Node
var _acc := 0.0
var _speed := 1.0
var _paused := false
var _pending_def: StringName = &""


func _ready() -> void:
	_install_cjk_font()
	_registry.load_directory("res://content/defs")
	_registry.load_file("res://content/levels/snow_01.json")
	if not _assets.load_pack(PACK_ID):
		var l := Label.new()
		l.text = "未找到素材包 godot/packs/%s\n请先运行 make import-assets" % PACK_ID
		add_child(l)
		return
	_sound.setup(_assets)
	add_child(_sound)
	_sound.play_music("music.power")
	_start_session()


## 界面文字是中文：优先用系统里的 CJK 字体（引擎不内置字体文件）。
func _install_cjk_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Hiragino Sans GB", "Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei"])
	ThemeDB.get_default_theme().default_font = font


func _start_session() -> void:
	if _root != null:
		_root.queue_free()
	_root = Node.new()
	add_child(_root)
	_acc = 0.0
	_paused = false
	_speed = 1.0
	_pending_def = &""
	_session = GameSession.new(_registry, LEVEL_ID)
	_view = WorldView.new()
	_root.add_child(_view)
	_view.setup(_session.world, _assets)
	_view.add_props(_session.props)
	_directors = [SoundDirector.new(_session.world, _sound)]
	_siren_cooldown = 0.0
	_placement = PlacementController.new()
	_placement.world = _session.world
	_view.add_child(_placement)
	_camera = IsoCamera.new()
	_camera.bounds = _view.map_bounds().grow(120.0)
	_camera.position = IsoProjection.to_screen(_session.base_center())
	_view.add_child(_camera)
	_camera.make_current()
	_hud = GameHud.new()
	_root.add_child(_hud)
	_hud.setup(_session, _assets, _sound)
	_hud.minimap.camera = _camera
	_connect_signals()


func _connect_signals() -> void:
	_hud.build_selected.connect(_on_build_selected)
	_hud.sell_toggled.connect(_on_sell_toggled)
	_hud.next_wave_pressed.connect(func() -> void: _session.world.submit({"type": "call_next_wave"}))
	_hud.pause_toggled.connect(func() -> void: _paused = not _paused)
	_hud.speed_changed.connect(func(m: float) -> void: _speed = m)
	_hud.superweapon_pressed.connect(func() -> void:
		_placement.begin_target(_session.storm.radius)
		_hud.show_hint("选择风暴落点（右键取消）"))
	_hud.restart_pressed.connect(_start_session)
	_placement.place_requested.connect(_on_place_requested)
	_placement.sell_requested.connect(func(id: int) -> void:
		_session.world.submit({"type": "sell_structure", "team": Team.PLAYER, "entity_id": id}))
	_placement.target_requested.connect(func(pos: Vector2) -> void:
		_session.world.submit({"type": "fire_superweapon", "team": Team.PLAYER, "pos": pos})
		_placement.end())
	_placement.cancelled.connect(func() -> void:
		_pending_def = &""
		_hud.set_sell_active(false))
	_session.world.events.subscribe(&"structure_placed", func(p: Dictionary) -> void:
		if p["entity"].team == Team.PLAYER:
			_sound.play("sfx.ui.place"))
	_session.world.events.subscribe(&"structure_sold", func(p: Dictionary) -> void:
		if p["entity"].team == Team.PLAYER:
			_sound.play("sfx.ui.sell"))
	_session.world.events.subscribe(&"entity_damaged", func(p: Dictionary) -> void:
		var e: SimEntity = p["entity"]
		if e.team == Team.PLAYER and e.layer == &"structure" and _siren_cooldown <= 0.0:
			_siren_cooldown = 20.0
			_sound.play("sfx.ui.base_attack")
			_hud.show_hint("基地遭到攻击！", 3.0))
	_session.world.events.subscribe(&"place_rejected", func(p: Dictionary) -> void: _hud.show_hint(p["reason"]))
	_session.world.events.subscribe(&"structure_completed", func(p: Dictionary) -> void:
		if p["entity"].team == Team.PLAYER:
			_hud.show_hint("%s 建造完成" % p["entity"].def.get("name", "")))
	_session.world.events.subscribe(&"wave_started", func(p: Dictionary) -> void:
		_hud.show_hint("第 %d 波来袭！" % p["index"], 4.0))
	_session.rules.game_over.connect(func(won: bool) -> void: _hud.show_game_over(won, _session.rules.kills))


func _on_build_selected(def_id: StringName) -> void:
	var reason := _session.build.afford_reason(_session.world, Team.PLAYER, def_id)
	if reason != "":
		_hud.show_hint(reason)
		return
	_sound.play("sfx.ui.build_start")
	_pending_def = def_id
	var d := _registry.get_def(&"structure", def_id)
	var sz: Array = d.get("size", [1, 1])
	_placement.begin_place(Vector2i(int(sz[0]), int(sz[1])), func(cell: Vector2i, _size: Vector2i) -> bool:
		return _session.build.can_place(_session.world, Team.PLAYER, _pending_def, cell) == "")
	_hud.show_hint("点击放置 %s（右键取消）" % d.get("name", ""), 6.0)


func _on_place_requested(cell: Vector2i) -> void:
	_session.world.submit({"type": "place_structure", "team": Team.PLAYER, "def_id": String(_pending_def), "cell": cell})
	if not Input.is_key_pressed(KEY_SHIFT):
		_placement.end()


func _on_sell_toggled() -> void:
	if _placement.mode == PlacementController.Mode.SELL:
		_placement.end()
		_hud.set_sell_active(false)
	else:
		_placement.begin_sell()
		_hud.set_sell_active(true)
		_hud.show_hint("点击要出售的建筑（右键取消）", 6.0)


func _process(delta: float) -> void:
	if _session == null:
		return
	if not _paused and not _session.rules.finished:
		_acc += minf(delta, 0.25) * _speed
		while _acc >= SimWorld.STEP:
			_session.world.step()
			_acc -= SimWorld.STEP
	_siren_cooldown -= delta
	_hud.refresh(delta)
