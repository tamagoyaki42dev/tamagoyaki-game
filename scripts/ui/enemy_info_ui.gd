## 敵情報画面 — scenes/enemy_info.tscn にアタッチ
extends Node

const HEADER_H  := 70.0
const DIVIDER_X := 870.0  # 左(プレビュー)と右(テキスト)の仕切り位置
const FONT_PATH := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"

var SW: float
var SH: float
var _root: Control
var _font: Font

func _ready() -> void:
	GameState.ensure_init()
	_font = load(FONT_PATH) as Font
	var vp := get_viewport().get_visible_rect().size
	SW = vp.x
	SH = vp.y
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_crect(_root, Vector2.ZERO, Vector2(SW, SH), Color(0.05, 0.06, 0.10))

	_build_header()
	_crect(_root, Vector2(0.0, HEADER_H), Vector2(SW, 1.0), Color(0.25, 0.35, 0.55, 0.6))

	_build_preview()
	_crect(_root, Vector2(DIVIDER_X, HEADER_H), Vector2(1.0, SH - HEADER_H),
		Color(0.25, 0.35, 0.55, 0.4))

	_build_stats()
	_build_formation_button()

func _build_header() -> void:
	var battle_num := GameState.battle_index + 1
	_lbl(_root, "第%d戦 / 全3戦" % battle_num, Vector2(40.0, 20.0), 24)

func _build_formation_button() -> void:
	var btn := Button.new()
	btn.text = "編成画面へ →"
	btn.position = Vector2(SW - 220.0, SH - 70.0)
	btn.size = Vector2(190.0, 42.0)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/formation.tscn"))
	_style_button(btn, Color(1.0, 0.55, 0.10))
	_root.add_child(btn)

func _build_preview() -> void:
	var svp_w := int(DIVIDER_X)
	var svp_h := int(SH - HEADER_H)

	var container := SubViewportContainer.new()
	container.position = Vector2(0.0, HEADER_H)
	container.size = Vector2(svp_w, svp_h)
	_root.add_child(container)

	var svp := SubViewport.new()
	svp.size = Vector2i(svp_w, svp_h)
	container.add_child(svp)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.75)
	env.ambient_light_energy = 0.5
	env_node.environment = env
	svp.add_child(env_node)

	var light := DirectionalLight3D.new()
	light.look_at_from_position(Vector3(3.0, 5.0, 4.0), Vector3.ZERO, Vector3.UP)
	light.light_energy = 1.3
	svp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.5
	cam.look_at_from_position(Vector3(0.0, 1.2, 5.0), Vector3(0.0, 0.8, 0.0), Vector3.UP)
	svp.add_child(cam)

	var ed := _get_enemy_data()
	if ed and not ed.model_path.is_empty() and ResourceLoader.exists(ed.model_path):
		var res := load(ed.model_path) as PackedScene
		if res:
			var model: Node3D = res.instantiate()
			model.scale = Vector3.ONE * ed.model_scale
			svp.add_child(model)
			var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if anim and anim.has_animation(ed.idle_anim):
				anim.get_animation(ed.idle_anim).loop_mode = Animation.LOOP_LINEAR
				anim.play(ed.idle_anim)

func _build_stats() -> void:
	var ed := _get_enemy_data()
	if not ed:
		return

	var lx := DIVIDER_X + 50.0
	var vx := DIVIDER_X + 300.0
	var y  := HEADER_H + 50.0

	_lbl(_root, ed.enemy_name, Vector2(lx, y), 36)
	y += 60.0

	_crect(_root, Vector2(lx, y), Vector2(SW - lx - 40.0, 1.0), Color(0.25, 0.35, 0.55))
	y += 16.0

	_lbl(_root, "── ステータス", Vector2(lx, y), 18, Color(0.50, 0.60, 0.80))
	y += 32.0

	var stats: Array = [
		["HP",      str(ed.hp_max)],
		["ATK",     str(ed.attack)],
		["SPD",     str(ed.speed)],
		["自己回復", str(ed.self_regen)],
	]
	for row: Array in stats:
		_lbl(_root, row[0], Vector2(lx, y), 22, Color(0.60, 0.65, 0.75))
		_lbl(_root, row[1], Vector2(vx, y), 22, Color(0.98, 0.92, 0.75))
		y += 38.0

	y += 12.0
	_crect(_root, Vector2(lx, y), Vector2(SW - lx - 40.0, 1.0), Color(0.25, 0.35, 0.55))
	y += 16.0

	_lbl(_root, "── 行動パターン", Vector2(lx, y), 18, Color(0.50, 0.60, 0.80))
	y += 32.0
	_lbl(_root, EnemyData.format_action_cycle(ed.action_cycle), Vector2(lx, y), 22)
	y += 56.0

	_crect(_root, Vector2(lx, y), Vector2(SW - lx - 40.0, 1.0), Color(0.25, 0.35, 0.55))
	y += 16.0

	_lbl(_root, "── 思考タイプ", Vector2(lx, y), 18, Color(0.50, 0.60, 0.80))
	y += 32.0
	_lbl(_root, ed.format_thought_type(), Vector2(lx, y), 22)

func _get_enemy_data() -> EnemyData:
	var enemies := GameState.get_battle_enemy()
	if enemies.is_empty():
		return null
	return enemies[0] as EnemyData

# ── ヘルパー ────────────────────────────────────────────────

func _crect(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	parent.add_child(r)
	return r

func _lbl(parent: Node, text: String, pos: Vector2, font_size: int = 16,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _make_stylebox(bg: Color, border: Color, radius: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

func _style_button(btn: Button, border_col: Color) -> void:
	var dark_bg := Color(border_col.r * 0.10, border_col.g * 0.10, border_col.b * 0.10, 0.88)
	var mid_bg  := Color(border_col.r * 0.22, border_col.g * 0.22, border_col.b * 0.22, 0.92)
	btn.add_theme_stylebox_override("normal",   _make_stylebox(dark_bg, border_col, 6, 2))
	btn.add_theme_stylebox_override("hover",    _make_stylebox(mid_bg, border_col.lightened(0.3), 6, 2))
	btn.add_theme_stylebox_override("pressed",  _make_stylebox(mid_bg, border_col.lightened(0.5), 6, 2))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.05, 0.05, 0.08, 0.5), Color(0.2, 0.2, 0.25), 6, 1))
	btn.add_theme_stylebox_override("focus",    _make_stylebox(mid_bg, border_col.lightened(0.3), 6, 2))
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_color_override("font_color",          Color.WHITE)
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.40))
