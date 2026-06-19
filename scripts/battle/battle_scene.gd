class_name BattleScene
extends Node

const CHAR_PATH := "res://assets/characters/kenney/character-male-a.glb"

const HP_YELLOW_THRESHOLD := 0.5
const HP_RED_THRESHOLD    := 0.25
const HP_COLOR_GREEN  := Color(0.15, 0.80, 0.30, 1.0)
const HP_COLOR_YELLOW := Color(0.90, 0.78, 0.05, 1.0)
const HP_COLOR_RED    := Color(0.85, 0.18, 0.10, 1.0)

# カメラ
@export var camera_target: Vector3     = Vector3(3.0, 0.0, 2.0)
@export var camera_distance: float     = 15.0
@export var camera_ortho_size: float   = 14.0
@export var char_y_offset: float       = 0.0

# HP表示バー（キャラ下）
@export var hp_bar_y_offset: float     = -0.15
@export var hp_bar_width: float        = 0.8
@export var hp_bar_height: float       = 0.06

# ダメージ数字
@export var dmg_font_size: int         = 48
@export var dmg_pixel_size: float      = 0.012
@export var dmg_rise: float            = 1.2
@export var dmg_duration: float        = 0.9

# 攻撃アニメ
@export var atk_wind_up_dist: float    = 0.05   # m 予備後退
@export var atk_lunge_dist: float      = 0.3    # m 前進
@export var atk_wind_up_time: float    = 0.08   # s
@export var atk_lunge_time: float      = 0.12   # s
@export var atk_return_time: float     = 0.18   # s

# 被弾
@export var hit_flash_duration: float  = 0.08   # s 赤flash
@export var hit_shake_amount: float    = 0.05   # m 揺れ幅
@export var hit_knockback_dist: float  = 0.12   # m ノックバック

# 撃破
@export var death_duration: float      = 0.4    # s
@export var death_tilt_deg: float      = 45.0   # °

# ローテーション
@export var rotate_duration: float     = 0.55   # s

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
var _unit_nodes: Dictionary = {}  # BattleUnit → Node3D
var _hp_bars: Dictionary = {}     # BattleUnit → ShaderMaterial (fg)

func _ready() -> void:
	_flash_shader = Shader.new()
	_flash_shader.code = _FLASH_CODE
	_hp_bar_shader = Shader.new()
	_hp_bar_shader.code = _HP_BAR_CODE
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

func _start_battle() -> void:
	_manager = BattleManager.new()
	add_child(_manager)
	_manager.battle_started.connect(_on_battle_started)
	_manager.unit_acted.connect(_on_unit_acted)
	_manager.unit_healed.connect(_on_unit_healed)
	_manager.unit_died.connect(_on_unit_died)
	_manager.rotated.connect(_on_rotated)
	_manager.battle_ended.connect(_on_battle_ended)
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

func _do_flash(ch: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		var mat: ShaderMaterial = mesh.material_overlay as ShaderMaterial
		if not mat:
			continue
		mat.set_shader_parameter("flash_amount", 1.0)
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
			1.0, 0.0, hit_flash_duration)

func _spawn_damage_label(pos: Vector3, text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = dmg_font_size
	lbl.pixel_size = dmg_pixel_size
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = color
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + Vector3(randf_range(-0.2, 0.2), 1.5, 0.0)
	lbl.scale = Vector3.ZERO
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

func _spawn_char(marker: Marker3D, y_rot: float) -> Node3D:
	var res: PackedScene = load(CHAR_PATH)
	if not res:
		return null
	var ch: Node3D = res.instantiate()
	ch.rotation_degrees.y = y_rot
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
			var ch := _spawn_char(m, 180.0)
			_unit_nodes[unit] = ch
			_spawn_hp_bar(ch, unit)
	for unit: BattleUnit in eg.get_all_alive():
		var m: Marker3D = _get_enemy_marker(0)
		if m:
			var ch := _spawn_char(m, 0.0)
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
		_spawn_damage_label(ch_t.global_position, dmg_text, dmg_color)
		_update_hp_bar(target)
		_do_flash(ch_t)
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
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	if ch:
		var text := "+%d" % amount if amount > 0 else "MAX"
		_spawn_damage_label(ch.global_position, text, Color(0.3, 1.0, 0.55))
	_update_hp_bar(unit)

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
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for entry: Dictionary in moves:
		tw.tween_property(entry["ch"], "position", entry["to"], rotate_duration)

func _on_battle_ended(_won: bool, _loot: Array) -> void:
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/formation.tscn")
