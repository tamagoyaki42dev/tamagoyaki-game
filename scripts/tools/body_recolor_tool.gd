extends Node3D
## 体リカラー・ツール（dev_tooling_design.md A1）。
## KayKit体を1体まるごとロードし、検出した色バンドをColorPickerで塗り替えて
## BodyRecolor(.tres) へ書き出す／読み込む。素体GLBは共有し、色差分だけをデータで持つ。
## 実ゲーム(battle_scene)が食う番号と一致させるため、モデルは実ゲームと同じく丸ごとロードする。
## scenes/body_recolor_tool.tscn から単独起動（F6）。全調整は画面UIで完結（エディタ不要）。

const Customizer := preload("res://scripts/tools/char_customizer.gd")
const AnimBrowser := preload("res://scripts/tools/anim_browser.gd")

const CHAR_DIR := "res://assets/kaykit/characters/"
const RECOLOR_DIR := "res://assets/kaykit/characters/recolors/"
# リカラー対象のKayKit体（実ゲーム _JOB_CHAR_PATHS のKayKitモデル。骨/マネキンは除外）
const MODELS: PackedStringArray = [
	"Rogue.glb", "Rogue_Hooded.glb", "Knight.glb", "Barbarian.glb",
	"Mage.glb", "Ranger.glb", "Witch_final_reference.glb",
]
const PREVIEW_CLIPS: PackedStringArray = [
	"General/Idle_A", "General/Idle_B", "MovementBasic/Walking_A",
	"CombatMelee/Melee_1H_Attack_Chop", "General/Hit_B",
]

# ── 画面スライダー／チェックで動かす調整値（初期値はここ・操作は画面で完結）──
@export var cam_dist: float = 5.4       # カメラ距離（基準方向ベクトルの倍率）
@export var cam_look_y: float = 1.15    # 注視点の高さ
@export var cam_fov: float = 42.0       # 画角
@export var key_energy: float = 1.3     # キーライト強度
@export var fill_energy: float = 0.4    # フィルライト強度
@export var char_scale: float = 1.0     # キャラ拡大
@export var char_y: float = 0.0         # 高さオフセット（手動・自動接地OFF時に効く）
@export var auto_ground: bool = true    # 毎フレーム足元をy=0へ（自作書き出しの沈み対策）
@export var spin: bool = false          # 自動回転
@export var show_ground: bool = true    # 地面表示
@export var spin_speed: float = 0.6     # 自動回転の角速度(rad/s)
@export var rotate_speed: float = 0.01  # 左ドラッグ回転の感度

const _CAM_BASE_DIR := Vector3(2.2, 1.9, 4.4)

var _cam: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _ground: MeshInstance3D
var _char_root: Node3D
var _anim: AnimationPlayer
var _current_clip: String = "General/Idle_A"
var _all_clips: PackedStringArray = PREVIEW_CLIPS  # モデルロード後に全クリップへ差し替え
var _model_idx: int = 0
var _dragging := false

# slot -> MeshInstance3D / 検出バンド Array / 上書き {band_idx:Color}
var _slot_mesh: Dictionary = {}
var _slot_order: Array[String] = []
var _bands: Dictionary = {}
var _band_tint: Dictionary = {}

var _band_container: VBoxContainer
var _name_edit: LineEdit
var _load_opt: OptionButton
var _anim_opt: OptionButton
var _y_slider: HSlider
var _status_lbl: Label
var _drift_lbl: Label

func _ready() -> void:
	_build_world()
	_build_ui()
	_apply_camera(0.0)
	_apply_lights(0.0)
	_load_model(MODELS[_model_idx])

func _process(delta: float) -> void:
	if spin and _char_root and is_instance_valid(_char_root):
		_char_root.rotate_y(spin_speed * delta)
	# 自動接地：毎フレーム、アニメ/物理適用後の実姿勢で足元(min_y)をy=0へ寄せる。
	# Witch等の自作書き出しは共有アニメ再生時に骨が沈むため、ライブ変形を測って補正する。
	if auto_ground and _char_root and is_instance_valid(_char_root) and _anim:
		var m := _measure_min_y()
		if is_finite(m) and absf(m) > 0.001:
			char_y -= m
			_char_root.position.y = char_y
			if _y_slider:
				_y_slider.set_value_no_signal(char_y)

# ── モデルのロード＋バンド検出 ─────────────────────────────
func _load_model(file: String) -> void:
	if _char_root and is_instance_valid(_char_root):
		_char_root.queue_free()
	_slot_mesh.clear()
	_slot_order.clear()
	_bands.clear()
	_band_tint.clear()
	var scn: PackedScene = load(CHAR_DIR + file)
	if not scn:
		_set_status("読み込み失敗: " + file)
		return
	_char_root = scn.instantiate() as Node3D
	_char_root.scale = Vector3.ONE * char_scale
	_char_root.position.y = char_y
	add_child(_char_root)
	_anim = AnimBrowser.build_merged_anim(_char_root)
	for full: String in _anim.get_animation_list():
		var a := _anim.get_animation(full)
		if a and a.length > 0.0:
			a.loop_mode = Animation.LOOP_LINEAR
	_populate_anim_dropdown()
	if _anim.has_animation(_current_clip):
		_anim.play(_current_clip)
	_scan_slots()
	_refresh_band_ui()
	_refresh_load_list()
	_set_status("ロード: %s（スロット %d）" % [file, _slot_order.size()])

## モデルの合流アニメから再生可能な全クリップをドロップダウンへ載せ直す。
func _populate_anim_dropdown() -> void:
	_all_clips = AnimBrowser.list_playable_clips(_anim)
	if _all_clips.is_empty():
		_all_clips = PREVIEW_CLIPS
	if not _all_clips.has(_current_clip):
		_current_clip = _all_clips[0] if _all_clips.has("General/Idle_A") == false else "General/Idle_A"
		if not _all_clips.has(_current_clip):
			_current_clip = _all_clips[0]
	if not _anim_opt:
		return
	_anim_opt.clear()
	for c: String in _all_clips:
		_anim_opt.add_item(c)
	_anim_opt.selected = _all_clips.find(_current_clip)

## モデル配下の全MeshInstance3Dを走査し、スロット名→メッシュ／検出バンドを作る。
func _scan_slots() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_char_root, meshes)
	for mi: MeshInstance3D in meshes:
		var slot: String = Customizer._slot_of(mi.name)
		slot = Customizer.SLOT_ALIAS.get(slot, slot)
		if _slot_mesh.has(slot):
			continue  # 同名スロットの重複は先勝ち（単体キャラでは稀）
		var bands: Array = Customizer.detect_uv_color_bands(mi)
		if bands.is_empty():
			continue  # テクスチャ無しメッシュはスウォッチを出さない
		_slot_mesh[slot] = mi
		_slot_order.append(slot)
		_bands[slot] = bands
		_band_tint[slot] = {}

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect_meshes(c, out)

# ── 3Dワールド ─────────────────────────────────────────────
func _build_world() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-50, -35, 0)
	add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-20, 140, 0)
	add_child(_fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.37, 0.45)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	_ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.20)
	_ground.material_override = mat
	add_child(_ground)

func _apply_camera(_v: float) -> void:
	if not _cam:
		return
	_cam.look_at_from_position(_CAM_BASE_DIR.normalized() * cam_dist,
		Vector3(0.0, cam_look_y, 0.0), Vector3.UP)
	_cam.fov = cam_fov

func _apply_lights(_v: float) -> void:
	if _key:
		_key.light_energy = key_energy
	if _fill:
		_fill.light_energy = fill_energy

func _apply_scale(_v: float) -> void:
	if _char_root and is_instance_valid(_char_root):
		_char_root.scale = Vector3.ONE * char_scale

func _apply_ground(_v: bool) -> void:
	if _ground:
		_ground.visible = show_ground

func _apply_y(_v: float) -> void:
	if _char_root and is_instance_valid(_char_root):
		_char_root.position.y = char_y

## 現在の（アニメ適用済み）姿勢で全メッシュのワールドAABB最小yを返す。足元の高さ＝接地基準。
func _measure_min_y() -> float:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_char_root, meshes)
	var min_y := INF
	for mi: MeshInstance3D in meshes:
		if not mi.mesh:
			continue
		var aabb := mi.get_aabb()
		var gt := mi.global_transform
		for i in 8:
			var corner := gt * (aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0))
			min_y = minf(min_y, corner.y)
	return min_y

# ── UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 470.0
	layer.add_child(left)
	var sc := ScrollContainer.new()
	left.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(450, 0)
	sc.add_child(vb)

	var title := Label.new()
	title.text = "体リカラー"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var model_names: PackedStringArray = []
	for m: String in MODELS:
		model_names.append(m.get_basename())
	DevControls.add_dropdown(vb, "モデル", model_names, _model_idx, _on_model_selected)
	# アニメは仮の初期リストで生成し、モデルロード後に全クリップへ差し替える
	_anim_opt = DevControls.add_dropdown(vb, "アニメ", PREVIEW_CLIPS, PREVIEW_CLIPS.find(_current_clip), _on_anim_selected)

	DevControls.add_header(vb, "色バンド（押して変更・陰影は保持）")
	_band_container = VBoxContainer.new()
	_band_container.add_theme_constant_override("separation", 4)
	vb.add_child(_band_container)

	DevControls.add_header(vb, "表示調整")
	DevControls.add_slider(vb, "カメラ距離", self, "cam_dist", 3.0, 9.0, 0.1, _apply_camera)
	DevControls.add_slider(vb, "注視の高さ", self, "cam_look_y", 0.0, 2.5, 0.05, _apply_camera)
	DevControls.add_slider(vb, "画角(FOV)", self, "cam_fov", 20.0, 70.0, 1.0, _apply_camera)
	DevControls.add_slider(vb, "キーライト", self, "key_energy", 0.0, 3.0, 0.05, _apply_lights)
	DevControls.add_slider(vb, "フィルライト", self, "fill_energy", 0.0, 2.0, 0.05, _apply_lights)
	DevControls.add_slider(vb, "キャラ拡大", self, "char_scale", 0.5, 2.0, 0.05, _apply_scale)
	_y_slider = DevControls.add_slider(vb, "高さ(手動)", self, "char_y", -2.0, 2.0, 0.05, _apply_y)
	DevControls.add_checkbox(vb, "自動接地(沈み補正)", self, "auto_ground")
	DevControls.add_checkbox(vb, "自動回転", self, "spin")
	DevControls.add_checkbox(vb, "地面を表示", self, "show_ground", _apply_ground)

	DevControls.add_header(vb, "保存 / 読み込み")
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "ファイル名（例 rogue_recolor）"
	save_row.add_child(_name_edit)
	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_save_pressed)
	save_row.add_child(save_btn)
	vb.add_child(save_row)

	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 8)
	var load_lb := Label.new()
	load_lb.text = "読み込み"
	load_lb.custom_minimum_size = Vector2(70, 0)
	load_row.add_child(load_lb)
	_load_opt = OptionButton.new()
	_load_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_opt.item_selected.connect(_on_load_selected)
	load_row.add_child(_load_opt)
	vb.add_child(load_row)

	_drift_lbl = Label.new()
	_drift_lbl.add_theme_color_override("font_color", Color(0.95, 0.6, 0.3))
	_drift_lbl.add_theme_font_size_override("font_size", 12)
	_drift_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_drift_lbl)

	# 下バー：ステータス
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 490.0
	bottom.offset_top = -44.0
	layer.add_child(bottom)
	_status_lbl = Label.new()
	_status_lbl.text = "左ドラッグでキャラ回転 / ESCで終了"
	_status_lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.82))
	bottom.add_child(_status_lbl)

## スロットの検出バンドが変わるたび、スウォッチUIを作り直す。
func _refresh_band_ui() -> void:
	if not _band_container:
		return
	for c in _band_container.get_children():
		c.queue_free()
	for slot: String in _slot_order:
		var bands: Array = _bands.get(slot, [])
		if bands.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var lb := Label.new()
		lb.text = slot
		lb.custom_minimum_size = Vector2(120, 0)
		row.add_child(lb)
		var overrides: Dictionary = _band_tint.get(slot, {})
		for i in bands.size():
			var band: Dictionary = bands[i]
			var btn := ColorPickerButton.new()
			btn.custom_minimum_size = Vector2(34, 24)
			btn.color = overrides[i] if overrides.has(i) else (band["color"] as Color)
			btn.color_changed.connect(_on_band_changed.bind(slot, i))
			row.add_child(btn)
		_band_container.add_child(row)

# ── ハンドラ ───────────────────────────────────────────────
func _on_model_selected(idx: int) -> void:
	_model_idx = idx
	_load_model(MODELS[idx])

func _on_anim_selected(idx: int) -> void:
	if idx < 0 or idx >= _all_clips.size():
		return
	_current_clip = _all_clips[idx]
	if _anim and _anim.has_animation(_current_clip):
		_anim.play(_current_clip)

func _on_band_changed(color: Color, slot: String, band_idx: int) -> void:
	(_band_tint[slot] as Dictionary)[band_idx] = color
	var mi: MeshInstance3D = _slot_mesh.get(slot)
	if mi:
		Customizer.recolor_part(mi, _bands[slot], _band_tint[slot])

func _on_save_pressed() -> void:
	var base := _name_edit.text.strip_edges()
	if base.is_empty():
		base = MODELS[_model_idx].get_basename().to_lower() + "_recolor"
	base = base.trim_suffix(".tres")
	# 上書きが空のスロットは保存対象から外す
	var tint: Dictionary = {}
	for slot: String in _band_tint:
		if not (_band_tint[slot] as Dictionary).is_empty():
			tint[slot] = _band_tint[slot]
	if tint.is_empty():
		_set_status("色を変更してから保存してください")
		return
	var res := BodyRecolor.from_tool_state(CHAR_DIR + MODELS[_model_idx], tint, _bands)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOLOR_DIR))
	var path := RECOLOR_DIR + base + ".tres"
	var err := ResourceSaver.save(res, path)
	if err == OK:
		_set_status("保存: %s" % ProjectSettings.globalize_path(path))
		_refresh_load_list()
	else:
		_set_status("保存失敗(err=%d): %s" % [err, path])

func _refresh_load_list() -> void:
	if not _load_opt:
		return
	_load_opt.clear()
	_load_opt.add_item("（なし）")
	var dir := DirAccess.open(RECOLOR_DIR)
	if dir:
		for f: String in dir.get_files():
			if f.ends_with(".tres"):
				_load_opt.add_item(f)

func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var file := _load_opt.get_item_text(idx)
	var res := load(RECOLOR_DIR + file) as BodyRecolor
	if not res:
		_set_status("読み込み失敗: " + file)
		return
	# いったん全スロットの上書きを消してから適用（他モデル由来のスロットは無視される）
	for slot: String in _slot_order:
		_band_tint[slot] = {}
	for slot: String in res.slots_with_overrides():
		if not _slot_mesh.has(slot):
			continue
		_band_tint[slot] = res.band_tint_for(slot)
		Customizer.recolor_part(_slot_mesh[slot], _bands[slot], _band_tint[slot])
	_refresh_band_ui()
	var warnings := res.drift_warnings(_bands)
	_drift_lbl.text = "" if warnings.is_empty() else "⚠ " + "\n".join(warnings)
	_set_status("適用: %s" % file)

func _set_status(msg: String) -> void:
	if _status_lbl:
		_status_lbl.text = msg

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging and _char_root:
		_char_root.rotate_y(-event.relative.x * rotate_speed)
