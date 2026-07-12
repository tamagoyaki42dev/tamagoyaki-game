extends Node3D
## プロポーション変形（チビ化スカッシュ）プレビュー（開発ツール・本番コード非依存）
## scenes/proportion_preview.tscn から単独起動する。
## 左＝素のキャラ（比較用）、右＝スライダーで「全体スケール」「頭部追加倍率」を
## 調整できるキャラ。数値が決まったら battle_scene.gd 側に手動で反映する想定
## （このツール自体はプレビュー専用で戦闘の見た目には一切影響しない）。

const CHAR_PATH := "res://assets/kaykit/characters/Ranger.glb"  # 兜/フードなし＝頭の変化が直接見える

@export var cam_position: Vector3 = Vector3(0.0, 2.0, 6.5)
@export var cam_look_at: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var cam_fov: float = 45.0
@export var char_spacing: float = 1.3
@export var rotate_speed: float = 0.01

var _left_root: Node3D   # 素の比較用
var _right_root: Node3D  # 調整対象
var _right_skeleton: Skeleton3D
var _right_head_bone: int = -1
var _body_scale: float = 0.8
var _head_boost: float = 1.7
var _dragging: bool = false

var _body_lbl: Label
var _head_lbl: Label

func _ready() -> void:
	_build_world()
	_left_root = _spawn_character(Vector3(-char_spacing, 0.0, 0.0))
	_right_root = _spawn_character(Vector3(char_spacing, 0.0, 0.0))
	_right_skeleton = _right_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _right_skeleton:
		_right_head_bone = _find_bone_ci(_right_skeleton, "head")
		if _right_head_bone < 0:
			push_warning("headボーンが見つかりません。骨名一覧: %s" %
				[_bone_names(_right_skeleton)])
	_build_ui()
	_apply_squash()

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

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.20)
	ground.material_override = mat
	add_child(ground)

func _spawn_character(pos: Vector3) -> Node3D:
	var scn: PackedScene = load(CHAR_PATH)
	if not scn:
		push_warning("キャラGLB読み込み失敗: %s" % CHAR_PATH)
		return null
	var root := scn.instantiate() as Node3D
	root.position = pos
	add_child(root)
	# 静止ポーズのまま表示する（要検証で判明・2026-07-11：idleアニメを再生し続けると
	# AnimationPlayerが毎フレームSkeleton3Dのボーンポーズを上書きし、set_bone_pose_scale
	# による頭部拡大が2フレーム目で消えてしまう。このツールの目的はプロポーション比較
	# であって動きの確認ではないため、アニメーションは付けず素のインポート姿勢で止める）
	return root

static func _find_bone_ci(skeleton: Skeleton3D, needle: String) -> int:
	var lower := needle.to_lower()
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).to_lower() == lower:
			return i
	for i in skeleton.get_bone_count():
		if lower in skeleton.get_bone_name(i).to_lower():
			return i
	return -1

static func _bone_names(skeleton: Skeleton3D) -> String:
	var names: Array = []
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
	return ", ".join(names)

# ── 変形適用 ───────────────────────────────────────────────
func _apply_squash() -> void:
	if _right_root:
		_right_root.scale = Vector3.ONE * _body_scale
	if _right_skeleton and _right_head_bone >= 0:
		_right_skeleton.set_bone_pose_scale(_right_head_bone, Vector3.ONE * _head_boost)
	if _body_lbl:
		_body_lbl.text = "全体スケール %.2f" % _body_scale
	if _head_lbl:
		_head_lbl.text = "頭部追加倍率 %.2f" % _head_boost

# ── UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -110.0
	layer.add_child(bottom)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	bottom.add_child(vb)

	var title := Label.new()
	title.text = "プロポーション変形プレビュー（左＝原寸比較 / 右＝調整対象）　ESCで終了"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 16)
	vb.add_child(body_row)
	_body_lbl = Label.new()
	_body_lbl.custom_minimum_size = Vector2(220, 0)
	body_row.add_child(_body_lbl)
	var body_slider := HSlider.new()
	body_slider.min_value = 0.5
	body_slider.max_value = 1.0
	body_slider.step = 0.01
	body_slider.value = _body_scale
	body_slider.custom_minimum_size = Vector2(360, 0)
	body_slider.value_changed.connect(func(v: float) -> void:
		_body_scale = v
		_apply_squash())
	body_row.add_child(body_slider)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 16)
	vb.add_child(head_row)
	_head_lbl = Label.new()
	_head_lbl.custom_minimum_size = Vector2(220, 0)
	head_row.add_child(_head_lbl)
	var head_slider := HSlider.new()
	head_slider.min_value = 1.0
	head_slider.max_value = 3.0
	head_slider.step = 0.01
	head_slider.value = _head_boost
	head_slider.custom_minimum_size = Vector2(360, 0)
	head_slider.value_changed.connect(func(v: float) -> void:
		_head_boost = v
		_apply_squash())
	head_row.add_child(head_slider)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		if _left_root:
			_left_root.rotate_y(-event.relative.x * rotate_speed)
		if _right_root:
			_right_root.rotate_y(-event.relative.x * rotate_speed)
