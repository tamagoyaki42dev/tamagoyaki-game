class_name BattleScene
extends Node

const CHAR_PATH  := "res://assets/characters/kenney/character-male-a.glb"
const NEXT_SCENE := "res://scenes/formation.tscn"

const HP_YELLOW_THRESHOLD := 0.5
const HP_RED_THRESHOLD    := 0.25
const HP_COLOR_GREEN  := Color(0.15, 0.80, 0.30, 1.0)
const HP_COLOR_YELLOW := Color(0.90, 0.78, 0.05, 1.0)
const HP_COLOR_RED    := Color(0.85, 0.18, 0.10, 1.0)

const ROW_NAMES := ["前", "中", "後"]

# カメラ
@export var camera_target: Vector3     = Vector3(3.0, 0.0, 2.0)
@export var camera_distance: float     = 15.0
@export var camera_ortho_size: float   = 14.0
@export var char_y_offset: float       = 0.0
@export var player_char_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var enemy_char_scale: Vector3  = Vector3(1.0, 1.0, 1.0)

# HP表示バー（キャラ下）
@export var hp_bar_y_offset: float     = -0.15
@export var hp_bar_width: float        = 0.8
@export var hp_bar_height: float       = 0.06

# ダメージ数字
@export var dmg_font_size: int         = 48
@export var dmg_pixel_size: float      = 0.012
@export var dmg_rise: float            = 1.2
@export var dmg_duration: float        = 0.9

# クリティカルテキスト
@export var crit_font_size: int        = 48
@export var crit_duration: float       = 0.75
@export var crit_rise: float           = 0.6

# 攻撃補助エフェクト
@export var supp_font_size: int          = 48
@export var supp_duration: float         = 0.8
@export var supp_rise: float             = 0.9
@export var supp_flash_color: Color      = Color(1.0, 0.55, 0.0)
@export var supp_flash_duration: float   = 0.45
@export var supp_label_color: Color      = Color(1.0, 0.65, 0.1)
@export var supp_label_offset: Vector3   = Vector3(0.0, 1.8, 0.0)

# 防御補助エフェクト
@export var def_font_size: int           = 48
@export var def_duration: float          = 0.8
@export var def_rise: float              = 0.9
@export var def_flash_color: Color       = Color(0.2, 0.5, 1.0)
@export var def_flash_duration: float    = 0.45
@export var def_label_color: Color       = Color(0.3, 0.7, 1.0)
@export var def_label_offset: Vector3    = Vector3(0.0, 1.8, 0.0)

# 回復エフェクト
@export var heal_flash_color: Color      = Color(0.2, 1.0, 0.4)
@export var heal_flash_duration: float   = 0.35
@export var heal_label_color: Color      = Color(0.3, 1.0, 0.55)
@export var heal_row_stagger: float      = 0.15  # 列回復の各キャラ間ディレイ（秒）
@export var heal_batch_gap: float        = 0.65  # 列回復ヒーラー間ディレイ（秒）

# 攻撃アニメ
@export var atk_wind_up_dist: float    = 0.05   # m 予備後退
@export var atk_lunge_dist: float      = 0.3    # m 前進
@export var atk_wind_up_time: float    = 0.08   # s
@export var atk_lunge_time: float      = 0.12   # s
@export var atk_return_time: float     = 0.18   # s

# 被弾
@export var hit_flash_duration: float  = 0.08
@export var hit_flash_melee_color: Color  = Color(1.0, 0.15, 0.15)
@export var hit_flash_magic_color: Color  = Color(0.7, 0.15, 1.0)
@export var hit_flash_ranged_color: Color = Color(1.0, 0.85, 0.10)
@export var hit_shake_amount: float    = 0.05   # m 揺れ幅
@export var hit_knockback_dist: float  = 0.12   # m ノックバック

# ヒットストップ
@export_range(0.01, 1.0, 0.01) var hitstop_time_scale: float = 0.05
@export_range(0.02, 0.3,  0.01) var hitstop_duration: float  = 0.08

# カメラシェイク
@export_range(0.0, 0.5, 0.005) var shake_intensity: float      = 0.05
@export_range(0.0, 0.5, 0.005) var shake_crit_intensity: float = 0.12
@export_range(0.05, 1.0, 0.05) var shake_duration: float       = 0.25

# 撃破
@export var death_duration: float      = 0.4    # s
@export var death_tilt_deg: float      = 45.0   # °

# ローテーション
@export var rotate_duration: float      = 0.55   # s
@export var rotate_show_duration: float = 0.35   # s アニメ完了後の見せ時間

# 自己回復
@export var self_heal_show_duration: float = 1.0  # s フラッシュ・数字の見せ時間

# 列回復後の間
@export var post_row_heal_show_duration: float = 0.5  # s 列回復完了→攻撃フェーズまでの間

# 戦闘終了
@export var battle_end_delay: float    = 2.5    # s

# 戦場グリッド表示
@export var grid_cell_size: Vector2      = Vector2(1.85, 1.85)
@export var grid_cell_color: Color       = Color(0.35, 0.55, 1.0, 0.12)
@export var grid_cell_y_offset: float    = 0.0
@export var grid_label_font_size: int    = 48
@export var grid_label_pixel_size: float = 0.015
@export var grid_label_color: Color      = Color(0.85, 0.92, 1.0, 0.9)
@export var grid_label_offset: Vector3   = Vector3(-1.3, 0.8, 0.0)

const _FLASH_CODE := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3  flash_color  : source_color = vec3(1.0, 0.15, 0.15);
void fragment() {
	ALBEDO = flash_color;
	ALPHA  = flash_amount;
}
"""

# UV.x > health_pct の部分を透明にして右から削るHPバーシェーダー
# billboardで常にカメラを向くため親ノードの回転に依存しない
const _HP_BAR_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
uniform float health_pct : hint_range(0.0, 1.0) = 1.0;
uniform vec4  bar_color  : source_color = vec4(0.15, 0.85, 0.3, 1.0);
void vertex() {
	mat4 mv = VIEW_MATRIX * MODEL_MATRIX;
	mv[0] = vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0);
	mv[1] = vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0);
	mv[2] = vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0);
	POSITION = PROJECTION_MATRIX * mv * vec4(VERTEX, 1.0);
}
void fragment() {
	if (UV.x > health_pct) { discard; }
	ALBEDO = bar_color.rgb;
}
"""

var _flash_shader: Shader
var _hp_bar_shader: Shader

@onready var _camera: Camera3D           = $World/Camera3D
@onready var _env_node: WorldEnvironment = $World/WorldEnvironment
@onready var _light: DirectionalLight3D  = $World/DirectionalLight3D
@onready var _player_grid: Node3D        = $World/PlayerGrid
@onready var _enemy_grid: Node3D         = $World/EnemyGrid
@onready var _characters: Node3D         = $World/Characters
@onready var _battle_ui: BattleUI        = $CanvasLayer/BattleUI

var _manager: BattleManager
var _unit_nodes: Dictionary = {}    # BattleUnit → Node3D
var _hp_bars: Dictionary = {}       # BattleUnit → ShaderMaterial (fg)
var _label_font: Font = null
var _row_heal_units: Dictionary = {}     # BattleUnit → bool（列回復アニメ処理中）
var _row_heal_queue: Array = []          # 待機中の列回復バッチ
var _row_heal_animating: bool = false    # _process_row_heal_queue が動いているか
var _shake_active: bool = false          # カメラシェイク二重起動防止

func _ready() -> void:
	_flash_shader = Shader.new()
	_flash_shader.code = _FLASH_CODE
	_hp_bar_shader = Shader.new()
	_hp_bar_shader.code = _HP_BAR_CODE
	const JP := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"
	const EN := "res://assets/fonts/Cinzel-Regular.ttf"
	if ResourceLoader.exists(JP):
		var jf := load(JP) as FontFile
		if jf and ResourceLoader.exists(EN):
			jf.set_fallbacks([load(EN) as Font])
		_label_font = jf
	_setup_world()
	_start_battle()

func _setup_world() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = camera_ortho_size
	var cam_pos := camera_target + Vector3(1.0, 1.0, 1.0).normalized() * camera_distance
	_camera.look_at_from_position(cam_pos, camera_target, Vector3.UP)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.75)
	env.ambient_light_energy = 0.9
	_env_node.environment = env

	_light.look_at_from_position(Vector3(5.0, 8.0, 5.0), Vector3.ZERO, Vector3.UP)
	_setup_grid_overlay()

func _setup_grid_overlay() -> void:
	for row: int in RotationGrid.ROW_COUNT:
		var m0: Marker3D = null
		for col: int in RotationGrid.MAX_PER_ROW:
			var m: Marker3D = _get_player_marker(row, col)
			if m:
				if col == 0:
					m0 = m
				var tile := _make_grid_cell(
					m.position + Vector3(0.0, grid_cell_y_offset, 0.0),
					grid_cell_size, grid_cell_color)
				_player_grid.add_child(tile)
		if m0:
			var lbl := _make_row_label(ROW_NAMES[row],
				m0.position + grid_label_offset,
				grid_label_font_size, grid_label_pixel_size, grid_label_color)
			if _label_font:
				lbl.font = _label_font
			_player_grid.add_child(lbl)

func _start_battle() -> void:
	_manager = BattleManager.new()
	add_child(_manager)
	_manager.battle_started.connect(_on_battle_started)
	_manager.unit_acted.connect(_on_unit_acted)
	_manager.unit_healed.connect(_on_unit_healed)
	_manager.unit_died.connect(_on_unit_died)
	_manager.rotated.connect(_on_rotated)
	_manager.phase_started.connect(_on_phase_started)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.attack_support_used.connect(_on_attack_support_used)
	_manager.defense_support_used.connect(_on_defense_support_used)
	_manager.row_heal_batch.connect(_on_row_heal_batch)
	_battle_ui.setup(_manager)
	_manager.start_battle(GameState.get_battle_entries(), GameState.get_battle_enemy())

# ── ヘルパー ─────────────────────────────────────────────────────

func _get_player_marker(row: int, col: int) -> Marker3D:
	return _player_grid.get_node_or_null("Slot_r%d_c%d" % [row, col]) as Marker3D

func _get_enemy_marker(slot: int) -> Marker3D:
	return _enemy_grid.get_node_or_null("ESlot_%d" % slot) as Marker3D

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, result)

func _setup_flash(ch: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		var mat := ShaderMaterial.new()
		mat.shader = _flash_shader
		mat.set_shader_parameter("flash_amount", 0.0)
		mesh.material_overlay = mat

func _do_flash(ch: Node3D, color: Color = Color(1.0, 0.15, 0.15), duration: float = -1.0) -> void:
	var dur := duration if duration > 0.0 else hit_flash_duration
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		var mat: ShaderMaterial = mesh.material_overlay as ShaderMaterial
		if not mat:
			continue
		mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))
		mat.set_shader_parameter("flash_amount", 1.0)
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
			1.0, 0.0, dur)

func _do_hitstop() -> void:
	Engine.time_scale = hitstop_time_scale
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _do_camera_shake(intensity: float) -> void:
	if _shake_active:
		return
	_shake_active = true
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	var elapsed: float = 0.0
	while elapsed < shake_duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var fade := 1.0 - clampf(elapsed / shake_duration, 0.0, 1.0)
		var s := elapsed * 20.0
		_camera.h_offset = noise.get_noise_1d(s) * intensity * fade
		_camera.v_offset = noise.get_noise_1d(s + 100.0) * intensity * fade
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_shake_active = false

func _do_hit_effects(is_crit: bool) -> void:
	await _do_hitstop()
	_do_camera_shake(shake_crit_intensity if is_crit else shake_intensity)

static func _resolve_hit_flash_color(attacker: BattleUnit,
		melee_color: Color, magic_color: Color, ranged_color: Color) -> Color:
	if attacker.side == BattleUnit.Side.ENEMY:
		return melee_color
	var cd := attacker.source_data as CharacterData
	if not cd:
		return melee_color
	match cd.job:
		CharacterJob.Type.ARCHER, CharacterJob.Type.VALKYRIE:
			return ranged_color
		CharacterJob.Type.MAGE, CharacterJob.Type.WITCH, CharacterJob.Type.ILLUSIONIST, CharacterJob.Type.SHAMAN, CharacterJob.Type.SHRINE_MAIDEN:
			return magic_color
	return melee_color

static func _make_grid_cell(pos: Vector3, size: Vector2, cell_color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cell_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = pos
	return mi

static func _make_label3d(text: String, font_size: int, pixel_size: float,
		label_color: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.pixel_size = pixel_size
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = label_color
	return lbl

static func _make_row_label(text: String, pos: Vector3, font_size: int,
		pixel_size: float, label_color: Color) -> Label3D:
	var lbl := _make_label3d(text, font_size, pixel_size, label_color)
	lbl.outline_size = 4
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	lbl.position = pos
	return lbl

func _spawn_floating_label(pos: Vector3, text: String, color: Color) -> void:
	var lbl := _make_label3d(text, dmg_font_size, dmg_pixel_size, color)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + Vector3(randf_range(-0.2, 0.2), 1.5, 0.0)
	lbl.scale = Vector3.ZERO
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position",
		lbl.position + Vector3(0.0, dmg_rise, 0.0), dmg_duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,
		dmg_duration * 0.55).set_delay(dmg_duration * 0.45)
	await get_tree().create_timer(dmg_duration + 0.1).timeout
	if is_instance_valid(lbl):
		lbl.queue_free()

func _spawn_critical_label(pos: Vector3) -> void:
	var lbl := _make_label3d("Critical!", crit_font_size, dmg_pixel_size, Color(1.0, 0.75, 0.0))
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	lbl.position = pos + Vector3(0.0, 2.2, 0.0)
	lbl.scale = Vector3.ZERO
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3(1.5, 1.5, 1.5), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position",
		lbl.position + Vector3(0.0, crit_rise, 0.0), crit_duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,
		crit_duration * 0.5).set_delay(crit_duration * 0.5)
	await get_tree().create_timer(crit_duration + 0.1).timeout
	if is_instance_valid(lbl):
		lbl.queue_free()

static func _make_support_label(text: String, pos: Vector3, font_size: int,
		pixel_size: float, label_color: Color, offset: Vector3) -> Label3D:
	var lbl := _make_label3d(text, font_size, pixel_size, label_color)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + offset
	lbl.scale = Vector3.ZERO
	return lbl

func _animate_floating_label(lbl: Label3D, rise: float, duration: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position",
		lbl.position + Vector3(0.0, rise, 0.0), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,
		duration * 0.55).set_delay(duration * 0.45)
	await get_tree().create_timer(duration + 0.1).timeout
	if is_instance_valid(lbl):
		lbl.queue_free()

func _spawn_atk_support_label(pos: Vector3) -> void:
	var lbl := BattleScene._make_support_label(
		"ATK Up", pos, supp_font_size, dmg_pixel_size, supp_label_color, supp_label_offset)
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	_animate_floating_label(lbl, supp_rise, supp_duration)

func _spawn_def_support_label(pos: Vector3) -> void:
	var lbl := BattleScene._make_support_label(
		"DEF Up", pos, def_font_size, dmg_pixel_size, def_label_color, def_label_offset)
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	_animate_floating_label(lbl, def_rise, def_duration)

func _make_bg_bar() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(hp_bar_width, hp_bar_height)
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 1
	mi.material_override = mat
	return mi

func _spawn_hp_bar(ch: Node3D, unit: BattleUnit) -> void:
	var bg := _make_bg_bar()
	bg.position.y = hp_bar_y_offset
	ch.add_child(bg)

	var fg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(hp_bar_width, hp_bar_height)
	fg.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _hp_bar_shader
	mat.set_shader_parameter("health_pct", 1.0)
	mat.set_shader_parameter("bar_color", Color(0.15, 0.85, 0.3, 1.0))
	mat.render_priority = 2
	fg.material_override = mat
	fg.position.y = hp_bar_y_offset
	ch.add_child(fg)

	_hp_bars[unit] = mat  # ShaderMaterial を保持してパラメータを更新する

func _update_hp_bar(unit: BattleUnit) -> void:
	var mat: ShaderMaterial = _hp_bars.get(unit) as ShaderMaterial
	if not mat:
		return
	var pct := clampf(float(unit.hp) / float(unit.hp_max), 0.0, 1.0)
	mat.set_shader_parameter("health_pct", pct)
	mat.set_shader_parameter("bar_color", _get_hp_color(pct))

func _get_hp_color(pct: float) -> Color:
	if pct < HP_RED_THRESHOLD:
		return HP_COLOR_RED
	if pct < HP_YELLOW_THRESHOLD:
		return HP_COLOR_YELLOW
	return HP_COLOR_GREEN

func _spawn_char(marker: Marker3D, y_rot: float, scale: Vector3) -> Node3D:
	var res: PackedScene = load(CHAR_PATH)
	if not res:
		return null
	var ch: Node3D = res.instantiate()
	ch.rotation_degrees.y = y_rot
	ch.scale = scale
	ch.position = marker.global_position + Vector3(0.0, char_y_offset, 0.0)
	_characters.add_child(ch)
	var anim: AnimationPlayer = ch.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	_setup_flash(ch)
	return ch

func _spawn_death_particles(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.position = pos
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 1.2
	particles.amount = 24

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0.0, -4.0, 0.0)
	mat.scale_min = 0.06
	mat.scale_max = 0.12

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.5, 0.1, 1.0))
	gradient.add_point(1.0, Color(1.0, 0.15, 0.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = mesh
	particles.process_material = mat

	_characters.add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

# ── Signal handlers ──────────────────────────────────────────────

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	for unit: BattleUnit in pg.get_all_alive():
		var m: Marker3D = _get_player_marker(unit.row, unit.col)
		if m:
			var ch := _spawn_char(m, 180.0, player_char_scale)
			_unit_nodes[unit] = ch
			_spawn_hp_bar(ch, unit)
	for unit: BattleUnit in eg.get_all_alive():
		var m: Marker3D = _get_enemy_marker(0)
		if m:
			var ch := _spawn_char(m, 0.0, enemy_char_scale)
			_unit_nodes[unit] = ch
			_spawn_hp_bar(ch, unit)

func _on_unit_acted(attacker: BattleUnit, target: BattleUnit,
		dmg: int, is_crit: bool) -> void:
	var ch_a: Node3D = _unit_nodes.get(attacker) as Node3D
	var ch_t: Node3D = _unit_nodes.get(target) as Node3D
	var dir: Vector3 = Vector3(1, 0, 0) if attacker.side == BattleUnit.Side.PLAYER \
		else Vector3(-1, 0, 0)

	# 攻撃：予備動作→前進→戻り
	if ch_a:
		var origin := ch_a.position
		var tw := create_tween()
		tw.tween_property(ch_a, "position", origin - dir * atk_wind_up_dist,
			atk_wind_up_time).set_ease(Tween.EASE_OUT)
		tw.tween_property(ch_a, "position", origin + dir * atk_lunge_dist,
			atk_lunge_time).set_ease(Tween.EASE_OUT)
		tw.tween_property(ch_a, "position", origin,
			atk_return_time).set_ease(Tween.EASE_IN)

	# 被弾：ダメージ数字 + flash + 揺れ + ノックバック
	if ch_t:
		var dmg_text := "-%d" % dmg if dmg > 0 else "0"
		var dmg_color := Color(1.0, 0.85, 0.15) if is_crit else Color(1.0, 0.92, 0.85)
		_spawn_floating_label(ch_t.global_position, dmg_text, dmg_color)
		if is_crit:
			_spawn_critical_label(ch_t.global_position)
		_update_hp_bar(target)
		_do_flash(ch_t, _resolve_hit_flash_color(attacker,
			hit_flash_melee_color, hit_flash_magic_color, hit_flash_ranged_color))
		_do_hit_effects(is_crit)
		var t_origin := ch_t.position
		var kb_dir := -dir
		var shake := Vector3(randf_range(-hit_shake_amount, hit_shake_amount),
			0.0, randf_range(-hit_shake_amount, hit_shake_amount))
		var tw_t := create_tween()
		tw_t.tween_property(ch_t, "position",
			t_origin + kb_dir * hit_knockback_dist + shake,
			hit_flash_duration).set_ease(Tween.EASE_OUT)
		tw_t.tween_property(ch_t, "position", t_origin, 0.12).set_ease(Tween.EASE_IN)

func _on_unit_died(unit: BattleUnit) -> void:
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	if not ch:
		return
	_spawn_death_particles(ch.global_position)
	# squash → scale=0 + 傾き
	var tw := create_tween()
	tw.tween_property(ch, "scale", Vector3(1.5, 0.5, 1.5), 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(ch, "scale", Vector3.ZERO, death_duration).set_ease(Tween.EASE_IN)
		tw2.tween_property(ch, "rotation_degrees:z", death_tilt_deg, death_duration))

func _on_unit_healed(unit: BattleUnit, amount: int) -> void:
	_update_hp_bar(unit)
	if _row_heal_units.has(unit):
		return  # 視覚は _on_row_heal_batch が担当
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	if ch:
		var text := "+%d" % amount if amount > 0 else "MAX"
		_spawn_floating_label(ch.global_position, text, heal_label_color)
		_do_flash(ch, heal_flash_color, heal_flash_duration)

func _on_rotated() -> void:
	var moves: Array[Dictionary] = []
	for unit: BattleUnit in _unit_nodes.keys():
		if unit.side == BattleUnit.Side.ENEMY:
			continue
		var ch: Node3D = _unit_nodes[unit] as Node3D
		var m: Marker3D = _get_player_marker(unit.row, unit.col)
		if ch and m:
			moves.append({"ch": ch,
				"to": m.global_position + Vector3(0.0, char_y_offset, 0.0)})
	if moves.is_empty():
		_manager.rotate_anim_done.emit()
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for entry: Dictionary in moves:
		tw.tween_property(entry["ch"], "position", entry["to"], rotate_duration)
	await tw.finished
	await get_tree().create_timer(rotate_show_duration).timeout
	_manager.rotate_anim_done.emit()

func _on_phase_started(phase: StringName) -> void:
	if phase != &"recovery":
		return
	await get_tree().create_timer(self_heal_show_duration).timeout
	_manager.self_heal_anim_done.emit()

func _on_attack_support_used(supporter: BattleUnit, attacker: BattleUnit) -> void:
	var ch_supp: Node3D = _unit_nodes.get(supporter) as Node3D
	var ch_atk: Node3D  = _unit_nodes.get(attacker)  as Node3D
	if ch_supp:
		_do_flash(ch_supp, supp_flash_color, supp_flash_duration)
	if ch_atk:
		_do_flash(ch_atk, supp_flash_color, supp_flash_duration)
		_spawn_atk_support_label(ch_atk.global_position)

func _on_defense_support_used(supporter: BattleUnit, target: BattleUnit) -> void:
	var ch_supp: Node3D = _unit_nodes.get(supporter) as Node3D
	var ch_tgt: Node3D  = _unit_nodes.get(target)    as Node3D
	if ch_supp:
		_do_flash(ch_supp, def_flash_color, def_flash_duration)
	if ch_tgt:
		_do_flash(ch_tgt, def_flash_color, def_flash_duration)
		_spawn_def_support_label(ch_tgt.global_position)

static func _make_heal_label(pos: Vector3, text: String, font_size: int,
		pixel_size: float, label_color: Color) -> Label3D:
	var lbl := _make_label3d(text, font_size, pixel_size, label_color)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + Vector3(0.0, 1.5, 0.0)
	lbl.scale = Vector3.ZERO
	return lbl

func _on_row_heal_batch(entries: Array) -> void:
	for e: Dictionary in entries:
		_row_heal_units[e["unit"]] = true
	_row_heal_queue.append(entries)
	if not _row_heal_animating:
		_process_row_heal_queue()

func _process_row_heal_queue() -> void:
	_row_heal_animating = true
	while not _row_heal_queue.is_empty():
		var entries: Array = _row_heal_queue.pop_front()
		var sorted: Array = entries.duplicate()
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["unit"] as BattleUnit).col > (b["unit"] as BattleUnit).col)
		for e: Dictionary in sorted:
			var unit: BattleUnit = e["unit"] as BattleUnit
			var amount: int = e["amount"] as int
			var ch: Node3D = _unit_nodes.get(unit) as Node3D
			if ch:
				var text := "+%d" % amount if amount > 0 else "MAX"
				_spawn_floating_label(ch.global_position, text, heal_label_color)
				_do_flash(ch, heal_flash_color, heal_flash_duration)
			await get_tree().create_timer(heal_row_stagger).timeout
		if not _row_heal_queue.is_empty():
			await get_tree().create_timer(heal_batch_gap).timeout
	_row_heal_animating = false
	_row_heal_units.clear()
	await get_tree().create_timer(post_row_heal_show_duration).timeout
	_manager.row_heal_anim_done.emit()

func _on_battle_ended(_won: bool, _loot: Array) -> void:
	await get_tree().create_timer(battle_end_delay).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_F12 \
			and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://") + "tools/screenshot.png"
		img.save_png(path)
		print("スクショ保存: %s" % path)
