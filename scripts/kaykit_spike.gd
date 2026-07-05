## KayKit 乗り換えスパイク（使い捨て・検証専用）
## 検証すること：本体GLB（Mage）に、別GLB（Rig_Medium 共通スケルトン用の
## アニメライブラリ）を合流させて Godot 4.6 で再生できるか。
## 起動：godot --path . res://scenes/kaykit_spike.tscn
##   引数 "screenshot_mode" を渡すと N フレーム後に res://tools/screenshot.png を保存して終了。
##   通常起動なら 1/2/3 キーで idle / attack / death を切替。
extends Node3D

const MAGE_PATH   := "res://assets/kaykit/characters/Mage.glb"
const ANIM_GENERAL := "res://assets/kaykit/animations/Rig_Medium_General.glb"
const ANIM_MELEE   := "res://assets/kaykit/animations/Rig_Medium_CombatMelee.glb"

const CLIP_IDLE   := "general/Idle_A"
const CLIP_ATTACK := "melee/Melee_1H_Attack_Chop"
const CLIP_DEATH  := "general/Death_A"

var _anim: AnimationPlayer = null
var _status: Label = null
var _screenshot_mode: bool = false
var _frames: int = 0

func _ready() -> void:
	_screenshot_mode = "screenshot_mode" in OS.get_cmdline_args()
	_setup_environment()

	var mage: Node3D = _instantiate(MAGE_PATH)
	if mage == null:
		_log_line("[FATAL] Mage をロード/インスタンス化できず")
		return
	add_child(mage)
	_dump_tree(mage, "Mage")

	var skel: Skeleton3D = mage.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		_log_line("[FATAL] Mage に Skeleton3D が無い")
		return
	_log_line("[OK] Mage Skeleton3D bones=%d  path_from_mage=%s" % [
		skel.get_bone_count(), str(mage.get_path_to(skel))])

	# 本体用に新しい AnimationPlayer を作る。アニメのトラックは本体GLBのルート基準
	# （"Rig_Medium/Skeleton3D:bone"）で焼かれているので root_node は Mage ルートに向ける。
	_anim = AnimationPlayer.new()
	mage.add_child(_anim)
	_anim.root_node = _anim.get_path_to(mage)

	_merge_library(ANIM_GENERAL, "general")
	_merge_library(ANIM_MELEE, "melee")

	_log_line("[INFO] merged anims: %s" % str(_anim.get_animation_list()))

	# 再生検証
	if _anim.has_animation(CLIP_ATTACK):
		var a: Animation = _anim.get_animation(CLIP_ATTACK)
		_log_line("[OK] %s length=%.2fs tracks=%d" % [CLIP_ATTACK, a.length, a.get_track_count()])
	else:
		_log_line("[FAIL] %s が見つからない" % CLIP_ATTACK)

	_build_hud()
	_play(CLIP_ATTACK if _screenshot_mode else CLIP_IDLE)

	# スクショモードは攻撃モーションの途中でポーズを止めて撮る（rest から動いた証拠）
	if _screenshot_mode and _anim.has_animation(CLIP_ATTACK):
		_anim.seek(0.35, true)
		_anim.pause()

func _instantiate(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		_log_line("[FATAL] not found: %s" % path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D

func _merge_library(anim_glb_path: String, lib_name: String) -> void:
	var src: Node3D = _instantiate(anim_glb_path)
	if src == null:
		_log_line("[FAIL] anim GLB load失敗: %s" % anim_glb_path)
		return
	var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src_ap == null:
		_log_line("[FAIL] %s に AnimationPlayer が無い" % anim_glb_path)
		return
	# glb のアニメは通常ライブラリ "" に入る
	var libs: PackedStringArray = src_ap.get_animation_library_list()
	if libs.is_empty():
		_log_line("[FAIL] %s にライブラリが無い" % anim_glb_path)
		return
	var lib: AnimationLibrary = src_ap.get_animation_library(libs[0])
	_anim.add_animation_library(lib_name, lib)
	_log_line("[OK] lib '%s' <- %s  clips=%d" % [lib_name, anim_glb_path.get_file(), lib.get_animation_list().size()])

func _play(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		_log_line("[WARN] play不可: %s" % clip)
		return
	var a: Animation = _anim.get_animation(clip)
	if clip == CLIP_IDLE:
		a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(clip)
	if _status:
		_status.text = "playing: %s   ([1]idle [2]attack [3]death)" % clip

# ── 見た目のお膳立て ───────────────────────────────
func _setup_environment() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	cam.look_at_from_position(Vector3(3.0, 2.6, 3.0), Vector3(0.0, 1.1, 0.0), Vector3.UP)
	add_child(cam)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	add_child(env_node)

	var light := DirectionalLight3D.new()
	light.light_energy = 1.6
	light.look_at_from_position(Vector3(3.0, 6.0, 3.0), Vector3.ZERO, Vector3.UP)
	add_child(light)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(24, 20)
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	layer.add_child(_status)

func _dump_tree(node: Node, tag: String) -> void:
	_log_line("── %s tree ──" % tag)
	_dump_recursive(node, 0)

func _dump_recursive(node: Node, depth: int) -> void:
	_log_line("%s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])
	for c in node.get_children():
		_dump_recursive(c, depth + 1)

func _log_line(s: String) -> void:
	print("[SPIKE] ", s)

func _process(_delta: float) -> void:
	if not _screenshot_mode:
		return
	_frames += 1
	if _frames == 60:
		var img := get_viewport().get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://tools/kaykit_spike.png")
		img.save_png(out)
		_log_line("screenshot saved: %s" % out)
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_1: _play(CLIP_IDLE)
			KEY_2: _play(CLIP_ATTACK)
			KEY_3: _play(CLIP_DEATH)
			KEY_ESCAPE: get_tree().quit()
