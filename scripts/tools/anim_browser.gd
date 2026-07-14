extends Node3D
## KayKitアニメ・ビューア（開発ツール）
## 持っている全KayKitアニメ（8カテゴリ・計139クリップ）を1画面で再生し、
## キャラも切り替えて見られる。scenes/anim_browser.tscn から単独起動する。
##
## 合流レシピは battle_scene.gd の _build_kaykit_anim_player と同じ（各GLBの
## AnimationPlayer から1本目のライブラリを add_animation_library で合流）を
## 8カテゴリ全部に拡張したもの。

const CHAR_DIR := "res://assets/kaykit/characters/"
const ANIM_DIR := "res://assets/kaykit/animations/"

const CHARACTERS: Array[String] = [
	"Mannequin_Medium", "Barbarian", "Knight", "Mage",
	"Ranger", "Rogue", "Rogue_Hooded",
]
const ANIM_CATS: Array[String] = [
	"General", "CombatMelee", "CombatRanged", "MovementBasic",
	"MovementAdvanced", "Simulation", "Special", "Tools",
]

@export var cam_position: Vector3 = Vector3(2.2, 1.9, 4.4)
@export var cam_look_at: Vector3 = Vector3(0.0, 1.15, 0.0)
@export var cam_fov: float = 42.0
@export var char_scale: float = 1.0
@export var default_clip: String = "General/Idle_A"
@export var rotate_speed: float = 0.01

var _char_root: Node3D
var _anim: AnimationPlayer
var _current_clip: String = ""
var _current_char_idx: int = 0
var _speed: float = 1.0
var _loop: bool = true
var _dragging: bool = false

# UI
var _item_list: ItemList
var _char_opt: OptionButton
var _name_lbl: Label
var _speed_lbl: Label

func _ready() -> void:
	_build_world()
	_build_ui()
	_load_character(0)
	_populate_clip_list()
	if _clip_exists(default_clip):
		_play_clip(default_clip)

# ── 3Dワールド ─────────────────────────────────────────────
func _build_world() -> void:
	var cam := Camera3D.new()
	cam.position = cam_position
	cam.look_at_from_position(cam_position, cam_look_at, Vector3.UP)
	cam.fov = cam_fov
	add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.3
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.4
	add_child(fill)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.37, 0.45)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)

	# 床グリッド
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.20)
	ground.material_override = mat
	add_child(ground)

# ── キャラ読み込み ─────────────────────────────────────────
func _load_character(idx: int) -> void:
	_current_char_idx = idx
	if _char_root and is_instance_valid(_char_root):
		_char_root.queue_free()
	var path := CHAR_DIR + CHARACTERS[idx] + ".glb"
	var scn: PackedScene = load(path)
	if not scn:
		push_warning("キャラGLB読み込み失敗: %s" % path)
		return
	_char_root = scn.instantiate() as Node3D
	_char_root.scale = Vector3.ONE * char_scale
	add_child(_char_root)
	_anim = build_merged_anim(_char_root)
	# ループ設定を全クリップに適用
	_apply_loop_mode()
	_anim.speed_scale = _speed
	# 切替前のクリップを維持
	if _current_clip != "" and _clip_exists(_current_clip):
		_anim.play(_current_clip)

## 8カテゴリGLBを合流した AnimationPlayer を char_root の子として構築する。
## （battle_scene._build_kaykit_anim_player を8カテゴリに拡張した版）
static func build_merged_anim(char_root: Node3D) -> AnimationPlayer:
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	char_root.add_child(anim)
	anim.root_node = anim.get_path_to(char_root)
	for cat: String in ANIM_CATS:
		var glb_path := ANIM_DIR + "Rig_Medium_" + cat + ".glb"
		var src_scene: PackedScene = load(glb_path)
		if not src_scene:
			continue
		var src: Node = src_scene.instantiate()
		var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src_ap:
			var libs: PackedStringArray = src_ap.get_animation_library_list()
			if not libs.is_empty():
				anim.add_animation_library(cat, src_ap.get_animation_library(libs[0]))
		src.queue_free()
	return anim

## 合流後の全クリップ名（"Cat/Name"）から T-Pose と 0秒ポーズを除いた一覧。
static func list_playable_clips(anim: AnimationPlayer) -> PackedStringArray:
	var out: PackedStringArray = []
	for cat: String in ANIM_CATS:
		if not anim.has_animation_library(cat):
			continue
		var lib := anim.get_animation_library(cat)
		var names := lib.get_animation_list()
		names.sort()
		for n: String in names:
			if n == "T-Pose":
				continue
			out.append(cat + "/" + n)
	return out

func _apply_loop_mode() -> void:
	if not _anim:
		return
	var mode := Animation.LOOP_LINEAR if _loop else Animation.LOOP_NONE
	for full: String in _anim.get_animation_list():
		var a := _anim.get_animation(full)
		if a and a.length > 0.0:
			a.loop_mode = mode

func _clip_exists(full: String) -> bool:
	return _anim != null and _anim.has_animation(full)

func _play_clip(full: String) -> void:
	if not _clip_exists(full):
		return
	_current_clip = full
	_anim.play(full)
	var length := _anim.get_animation(full).length
	_name_lbl.text = "%s    [%.2fs]" % [full, length]

# ── UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# 左パネル
	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 380.0
	layer.add_child(left)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	left.add_child(vb)

	var title := Label.new()
	title.text = "KayKit アニメビューア"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	_char_opt = OptionButton.new()
	for c: String in CHARACTERS:
		_char_opt.add_item(c)
	_char_opt.selected = 0
	_char_opt.item_selected.connect(_on_char_selected)
	vb.add_child(_char_opt)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.custom_minimum_size = Vector2(360, 820)
	_item_list.item_selected.connect(_on_clip_selected)
	vb.add_child(_item_list)

	# 下バー
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 400.0
	bottom.offset_top = -90.0
	layer.add_child(bottom)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	bottom.add_child(hb)

	_name_lbl = Label.new()
	_name_lbl.text = "—"
	_name_lbl.custom_minimum_size = Vector2(560, 0)
	_name_lbl.add_theme_font_size_override("font_size", 20)
	hb.add_child(_name_lbl)

	var loop_cb := CheckBox.new()
	loop_cb.text = "ループ"
	loop_cb.button_pressed = _loop
	loop_cb.toggled.connect(_on_loop_toggled)
	hb.add_child(loop_cb)

	_speed_lbl = Label.new()
	_speed_lbl.text = "速度 1.0x"
	hb.add_child(_speed_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.1
	slider.max_value = 2.0
	slider.step = 0.1
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(280, 0)
	slider.value_changed.connect(_on_speed_changed)
	hb.add_child(slider)

	var hint := Label.new()
	hint.text = "左ドラッグでキャラ回転 / ESCで終了"
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))
	hb.add_child(hint)

func _populate_clip_list() -> void:
	_item_list.clear()
	for cat: String in ANIM_CATS:
		if not _anim or not _anim.has_animation_library(cat):
			continue
		var lib := _anim.get_animation_library(cat)
		var names := lib.get_animation_list()
		names.sort()
		# カテゴリ見出し
		var head := _item_list.add_item("──  %s  ──" % cat)
		_item_list.set_item_selectable(head, false)
		_item_list.set_item_custom_fg_color(head, Color(0.95, 0.78, 0.35))
		for n: String in names:
			if n == "T-Pose":
				continue
			var i := _item_list.add_item("   " + n)
			_item_list.set_item_metadata(i, cat + "/" + n)

# ── ハンドラ ───────────────────────────────────────────────
func _on_char_selected(idx: int) -> void:
	_load_character(idx)

func _on_clip_selected(idx: int) -> void:
	var meta = _item_list.get_item_metadata(idx)
	if meta is String and meta != "":
		_play_clip(meta)

func _on_loop_toggled(on: bool) -> void:
	_loop = on
	_apply_loop_mode()
	if _current_clip != "":
		_anim.play(_current_clip)

func _on_speed_changed(v: float) -> void:
	_speed = v
	_speed_lbl.text = "速度 %.1fx" % v
	if _anim:
		_anim.speed_scale = v

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging and _char_root:
		_char_root.rotate_y(-event.relative.x * rotate_speed)
