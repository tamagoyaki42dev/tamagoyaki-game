## バトル画面 — アイソメトリックレイアウト + アニメーションキュー
extends Node

const TILE_W  := 240.0
const TILE_H  := 120.0
const PANEL_X := 1500.0
const SP_W    := 70.0
const SP_H    := 95.0
const EN_W    := 220.0
const EN_H    := 260.0
const VP_W    := 180
const VP_H    := 240

var SW: float
var SH: float
var _origin: Vector2

var _root: Control
var _font: Font = null

# フィールド UI
var _turn_lbl: Label
var _phase_lbl: Label
var _action_panel: Control
var _rotate_btn: Button
var _stay_btn: Button

# 右パネル
var _log_lbl: RichTextLabel
var _party_bars: Dictionary = {}   # BattleUnit → {hp_bar, bar_w}

# バトル
var _manager: BattleManager
var _anim_queue: Array = []

# ユニットノード (iso フィールド)
var _unit_nodes: Dictionary = {}

# 敵行動
var _enemy_data: EnemyData = null
var _enemy_action_slot: int = 0

func _ready() -> void:
	var jp_path := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"
	var en_path := "res://assets/fonts/Cinzel-Regular.ttf"
	if ResourceLoader.exists(jp_path):
		var jp := load(jp_path) as FontFile
		if ResourceLoader.exists(en_path):
			jp.set_fallbacks([load(en_path)])
		_font = jp
	var vp := get_viewport().get_visible_rect().size
	SW = vp.x
	SH = vp.y
	_origin = Vector2(SW * 0.22, SH * 0.50)
	_build_ui()
	_start_battle()

# ── 座標 ─────────────────────────────────────────────────────

func _iso(col: float, row: float) -> Vector2:
	return _origin + Vector2((col - row) * TILE_W * 0.5, (col + row) * TILE_H * 0.5)

func _iso_enemy(col: int, row: int) -> Vector2:
	return Vector2(SW * 0.52 + col * 90.0, SH * 0.27 + (col + row) * 55.0)

func _hp_color(r: float) -> Color:
	if r > 0.6: return Color(0.15, 0.78, 0.28)
	if r > 0.3: return Color(0.88, 0.68, 0.08)
	return Color(0.88, 0.18, 0.18)

# ── UI構築 ──────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ArenaBg.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(PANEL_X - 10, SH)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_crect(_root, Vector2.ZERO, Vector2(SW, SH), Color(0, 0, 0, 0.35))

	var grid := _IsoGrid.new()
	grid.origin = _origin
	grid.tile_w = TILE_W
	grid.tile_h = TILE_H
	_root.add_child(grid)

	_crect(_root, Vector2(PANEL_X - 8, 0), Vector2(2, SH), Color(0.25, 0.55, 1.0, 0.5))

	# ターン表示（左上）
	_turn_lbl = _lbl(_root, "Turn  0", Vector2(20, 18), 22, Color(0.88, 0.78, 0.30))

	# フェーズラベル（ボタン上・中央）
	_phase_lbl = Label.new()
	_phase_lbl.text = ""
	_phase_lbl.position = Vector2(1100.0, 645.0)
	_phase_lbl.size = Vector2(180.0, 55.0)
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_lbl.add_theme_font_size_override("font_size", 24)
	_phase_lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.30))
	if _font:
		_phase_lbl.add_theme_font_override("font", _font)
	_phase_lbl.z_index = 10
	_root.add_child(_phase_lbl)

	_build_action_buttons()
	_build_right_panel()

func _build_action_buttons() -> void:
	var btn_y   := 710.0
	var cx      := 1190.0
	var rot_w   := 230.0
	var stay_w  := 200.0
	var gap     := 28.0
	var total_w := rot_w + gap + stay_w
	var rot_x   := cx - total_w * 0.5
	var stay_x  := rot_x + rot_w + gap
	var btn_h   := 74.0

	var rot_sty_normal := StyleBoxFlat.new()
	rot_sty_normal.bg_color = Color(0.55, 0.28, 0.03, 0.85)
	rot_sty_normal.set_corner_radius_all(9)
	var rot_sty_hover := StyleBoxFlat.new()
	rot_sty_hover.bg_color = Color(0.72, 0.40, 0.05, 0.95)
	rot_sty_hover.set_corner_radius_all(9)
	var stay_sty_normal := StyleBoxFlat.new()
	stay_sty_normal.bg_color = Color(0.03, 0.36, 0.40, 0.85)
	stay_sty_normal.set_corner_radius_all(9)
	var stay_sty_hover := StyleBoxFlat.new()
	stay_sty_hover.bg_color = Color(0.04, 0.52, 0.58, 0.95)
	stay_sty_hover.set_corner_radius_all(9)
	var dis_sty := StyleBoxFlat.new()
	dis_sty.bg_color = Color(0.05, 0.05, 0.08, 0.5)
	dis_sty.border_color = Color(0.2, 0.2, 0.25)
	dis_sty.set_border_width_all(1)
	dis_sty.set_corner_radius_all(9)

	_rotate_btn = Button.new()
	_rotate_btn.text = "ローテーション"
	_rotate_btn.position = Vector2(rot_x, btn_y)
	_rotate_btn.size = Vector2(rot_w, btn_h)
	_rotate_btn.add_theme_font_size_override("font_size", 20)
	_rotate_btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.75))
	_rotate_btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.4))
	_rotate_btn.add_theme_stylebox_override("normal",   rot_sty_normal)
	_rotate_btn.add_theme_stylebox_override("hover",    rot_sty_hover)
	_rotate_btn.add_theme_stylebox_override("pressed",  rot_sty_hover)
	_rotate_btn.add_theme_stylebox_override("disabled", dis_sty)
	_rotate_btn.add_theme_stylebox_override("focus",    rot_sty_normal)
	if _font:
		_rotate_btn.add_theme_font_override("font", _font)
	_rotate_btn.disabled = true
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	_rotate_btn.z_index = 10
	_root.add_child(_rotate_btn)

	_stay_btn = Button.new()
	_stay_btn.text = "ステイ"
	_stay_btn.position = Vector2(stay_x, btn_y)
	_stay_btn.size = Vector2(stay_w, btn_h)
	_stay_btn.add_theme_font_size_override("font_size", 20)
	_stay_btn.add_theme_color_override("font_color", Color(0.75, 0.98, 1.0))
	_stay_btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.4))
	_stay_btn.add_theme_stylebox_override("normal",   stay_sty_normal)
	_stay_btn.add_theme_stylebox_override("hover",    stay_sty_hover)
	_stay_btn.add_theme_stylebox_override("pressed",  stay_sty_hover)
	_stay_btn.add_theme_stylebox_override("disabled", dis_sty)
	_stay_btn.add_theme_stylebox_override("focus",    stay_sty_normal)
	if _font:
		_stay_btn.add_theme_font_override("font", _font)
	_stay_btn.disabled = true
	_stay_btn.pressed.connect(_on_stay_pressed)
	_stay_btn.z_index = 10
	_root.add_child(_stay_btn)

func _build_right_panel() -> void:
	var pw    := SW - PANEL_X - 8.0
	var log_y := SH * 0.55 + 16.0

	# 背景
	_crect(_root, Vector2(PANEL_X - 6, 0), Vector2(pw + 14, SH),
		Color(0.03, 0.04, 0.09, 0.92)).z_index = 20
	_crect(_root, Vector2(PANEL_X - 6, 18), Vector2(1, SH - 36),
		Color(0.20, 0.25, 0.42, 0.45)).z_index = 21

	# セパレータ（パーティ／ログ境界）
	_crect(_root, Vector2(PANEL_X, log_y - 8), Vector2(pw, 1),
		Color(0.20, 0.25, 0.42, 0.70)).z_index = 21

	# ログエリア（下半分）
	var log_frame := Panel.new()
	log_frame.position = Vector2(PANEL_X - 2, log_y - 4)
	log_frame.size     = Vector2(pw + 4, SH - log_y)
	var ls := StyleBoxFlat.new()
	ls.bg_color     = Color(0.06, 0.04, 0.03, 0.88)
	ls.border_color = Color(0.68, 0.52, 0.22, 0.85)
	ls.set_border_width_all(2)
	ls.set_corner_radius_all(5)
	log_frame.add_theme_stylebox_override("panel", ls)
	log_frame.z_index = 21
	_root.add_child(log_frame)

	_log_lbl = RichTextLabel.new()
	_log_lbl.position = Vector2(PANEL_X + 6, log_y + 4)
	_log_lbl.size     = Vector2(pw - 12, SH - log_y - 16.0)
	_log_lbl.bbcode_enabled   = true
	_log_lbl.scroll_following = true
	_log_lbl.add_theme_font_size_override("normal_font_size", 15)
	_log_lbl.add_theme_constant_override("line_separation", 3)
	if _font:
		_log_lbl.add_theme_font_override("normal_font", _font)
	_log_lbl.z_index = 22
	_root.add_child(_log_lbl)

func _build_party_panel(units: Array) -> void:
	var n        := units.size()
	var pw       := SW - PANEL_X - 8.0
	var status_h := SH * 0.55
	var entry_h  := status_h / float(n)

	for i in n:
		var unit: BattleUnit = units[i]
		var ey  := 8.0 + i * entry_h
		var ex  := PANEL_X + 4.0
		var hue := float(abs(hash(unit.unit_name)) % 360) / 360.0

		var entry_bg := Panel.new()
		entry_bg.position = Vector2(PANEL_X - 2, ey + 2)
		entry_bg.size     = Vector2(pw + 4, entry_h - 4)
		var es := StyleBoxFlat.new()
		es.bg_color = Color(0.08, 0.10, 0.18, 0.55)
		es.set_corner_radius_all(4)
		entry_bg.add_theme_stylebox_override("panel", es)
		entry_bg.z_index = 21
		_root.add_child(entry_bg)

		var ph  := entry_h - 10.0
		var pw2 : float = minf(ph * 0.90, 55.0)
		var portrait := _crect(_root, Vector2(ex, ey + 4), Vector2(pw2, ph),
			Color.from_hsv(hue, 0.50, 0.38, 0.95))
		portrait.z_index = 22
		_lbl(_root, unit.unit_name.substr(0, 1),
			Vector2(ex + pw2 * 0.26, ey + ph * 0.22), 17, Color.WHITE).z_index = 22

		var tx    := ex + pw2 + 8.0
		var bar_w := pw - pw2 - 28.0
		_lbl(_root, unit.unit_name, Vector2(tx, ey + 5), 18,
			Color(0.86, 0.90, 0.98)).z_index = 22

		var hp_bg := _crect(_root, Vector2(tx, ey + 27), Vector2(bar_w, 9),
			Color(0.09, 0.09, 0.11))
		hp_bg.z_index = 22

		var ratio  := float(unit.hp) / float(unit.hp_max)
		var hp_bar := _crect(_root, Vector2(tx, ey + 27), Vector2(bar_w * ratio, 9),
			_hp_color(ratio))
		hp_bar.z_index = 22
		_party_bars[unit] = {"hp_bar": hp_bar, "bar_w": bar_w}

		_lbl(_root, "HP %d/%d" % [unit.hp, unit.hp_max],
			Vector2(tx, ey + 40), 15, Color(0.58, 0.70, 0.58)).z_index = 22
		_lbl(_root, "ATK %d   SPD %d" % [unit.attack, unit.speed],
			Vector2(tx, ey + 58), 15, Color(0.58, 0.65, 0.80)).z_index = 22

		if i < n - 1:
			_crect(_root, Vector2(PANEL_X, ey + entry_h - 1.0), Vector2(pw, 1),
				Color(0.15, 0.18, 0.30, 0.45)).z_index = 21

func _build_enemy_action_panel() -> void:
	if _enemy_data == null:
		return
	if _action_panel and is_instance_valid(_action_panel):
		_action_panel.queue_free()

	var cycle := _enemy_data.action_cycle
	if cycle.is_empty():
		return

	var px  := 1130.0
	var py  := 175.0
	var pw  := 290.0
	var s_h := 42.0
	var ph  := 46.0 + cycle.size() * s_h + 10.0

	_action_panel = Control.new()
	_action_panel.z_index = 5
	_root.add_child(_action_panel)
	var ap := _action_panel

	var bg_p := Panel.new()
	bg_p.position = Vector2(px, py)
	bg_p.size     = Vector2(pw, ph)
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.09, 0.04, 0.04, 0.92)
	sty.border_color = Color(0.55, 0.18, 0.18, 0.70)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(5)
	bg_p.add_theme_stylebox_override("panel", sty)
	ap.add_child(bg_p)

	_lbl(ap, _enemy_data.get_stat_type_name(),
		Vector2(px + 10, py + 7), 17, Color(0.92, 0.55, 0.55))

	_crect(ap, Vector2(px + 4, py + 30), Vector2(pw - 8, 1),
		Color(0.50, 0.15, 0.15, 0.55))

	var slot := _enemy_action_slot % cycle.size()
	for i in cycle.size():
		var sy      := py + 46.0 + i * s_h
		var is_now  := (i == slot)
		var is_past := (i < slot)

		if is_now:
			_crect(ap, Vector2(px + 2, sy + 2), Vector2(pw - 4, s_h - 4),
				Color(0.52, 0.08, 0.08, 0.60))

		var action_label := EnemyData.get_action_label(cycle[i])
		var label_txt := ("▶ " if is_now else "   ") + "%d.  %s" % [i + 1, action_label]
		var label_clr: Color
		if is_now:
			label_clr = Color(1.0, 0.65, 0.65)
		elif is_past:
			label_clr = Color(0.35, 0.22, 0.22)
		else:
			label_clr = Color(0.68, 0.55, 0.55)
		_lbl(ap, label_txt, Vector2(px + 8, sy + 10),
			18 if is_now else 15, label_clr)

		if is_now:
			_lbl(ap, "次の行動", Vector2(px + pw - 80, sy + 12),
				13, Color(1.0, 0.42, 0.42, 0.88))

# ── スプライト生成 ───────────────────────────────────────────

func _build_player_sprites(units: Array) -> void:
	for i in units.size():
		var unit: BattleUnit = units[i]
		var center := _iso(unit.col + 0.5, unit.row + 0.5)
		var z      := unit.row * 4 + unit.col
		var ratio  := float(unit.hp) / float(unit.hp_max)
		_unit_nodes[unit] = _add_3d_sprite(center, unit.unit_name, ratio, z, 180.0, 0.8)


func _add_3d_sprite(center: Vector2, unit_name: String, hp_ratio: float, z: int,
		y_rot: float = 0.0, display_scale: float = 1.0) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(VP_W, VP_H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.look_at_from_position(Vector3(4, 4, 4), Vector3(0, 0.5, 0), Vector3.UP)
	vp.add_child(cam)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	vp.add_child(env_node)

	var light := DirectionalLight3D.new()
	light.light_energy = 1.5
	light.look_at_from_position(Vector3(3, 6, 3), Vector3(0, 0, 0), Vector3.UP)
	vp.add_child(light)

	var char_scene = load("res://assets/characters/kenney/character-male-a.glb")
	if char_scene:
		var char_node = char_scene.instantiate()
		char_node.rotation_degrees.y = y_rot
		vp.add_child(char_node)
		var anim := char_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim:
			anim.play("idle")

	# グループノード：centerに置いてこれだけ動かせば全要素が追従する
	var group := Control.new()
	group.position = center
	group.z_index = z
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(group)

	var dw := VP_W * display_scale
	var dh := VP_H * display_scale

	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.size = Vector2(dw, dh)
	tex.position = Vector2(-dw * 0.65, -dh * 0.8)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(tex)

	var tex_bottom := -dh * 0.8 + dh
	var bar_y      := tex_bottom + 2.0
	var hp_bg  := _crect(group, Vector2(-SP_W * 0.5, bar_y), Vector2(SP_W, 5), Color(0.07, 0.07, 0.09))
	var hp_bar := _crect(group, Vector2(-SP_W * 0.5, bar_y), Vector2(SP_W * hp_ratio, 5), _hp_color(hp_ratio))

	return {"body": group, "accent": group, "name_lbl": group,
			"hp_bg": hp_bg, "hp_bar": hp_bar,
			"center": center, "is_3d": true, "bar_w": SP_W}

func _build_enemy_sprites(units: Array) -> void:
	for i in units.size():
		var unit: BattleUnit = units[i]
		var center := _iso_enemy(unit.col, unit.row)
		var z      := 100 + i
		var ratio  := float(unit.hp) / float(unit.hp_max)

		_unit_nodes[unit] = _add_3d_sprite(center, unit.unit_name, ratio, z, 0.0, 1.8)

		var bx := center.x - SP_W * 0.5
		var by := center.y + 57.0
		_lbl(_root, "HP %d/%d" % [unit.hp, unit.hp_max],
			Vector2(bx, by), 16, Color(0.82, 0.48, 0.48)).z_index = z

		if i == 0 and unit.source_data is EnemyData:
			_enemy_data = unit.source_data as EnemyData

# ── ユニット更新 ─────────────────────────────────────────────

func _update_unit(unit: BattleUnit) -> void:
	if not _unit_nodes.has(unit):
		return
	var entry  = _unit_nodes[unit]
	var ratio  := float(unit.hp) / float(unit.hp_max)
	var bw: float = entry.get("bar_w", SP_W)
	var hp_bar: ColorRect = entry["hp_bar"]
	hp_bar.size.x = bw * clampf(ratio, 0.0, 1.0)
	hp_bar.color  = _hp_color(ratio)
	if not unit.is_alive:
		entry["body"].modulate = Color(0.35, 0.35, 0.35, 0.55)

	# 右パネルのHPバーも更新
	if _party_bars.has(unit):
		var pb = _party_bars[unit]
		pb["hp_bar"].size.x = float(pb["bar_w"]) * clampf(ratio, 0.0, 1.0)
		pb["hp_bar"].color  = _hp_color(ratio)

# ── シグナルハンドラ ─────────────────────────────────────────

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	_build_player_sprites(pg.get_all_alive())
	_build_enemy_sprites(eg.get_all_alive())
	_build_party_panel(pg.get_all_alive())
	_build_enemy_action_panel()
	_log("[color=#888888]=== バトル開始 ===[/color]")

func _on_turn_started(n: int, timeline: Array, enemy_action: String) -> void:
	_anim_queue.append({"type": "turn_started", "n": n,
		"timeline": timeline, "enemy_action": enemy_action})

func _on_unit_acted(attacker: BattleUnit, target: BattleUnit, dmg: int, is_crit: bool) -> void:
	_anim_queue.append({"type": "acted", "attacker": attacker,
		"target": target, "dmg": dmg, "is_crit": is_crit})

func _on_unit_died(unit: BattleUnit) -> void:
	_anim_queue.append({"type": "died", "unit": unit})

func _on_unit_healed(unit: BattleUnit, amount: int) -> void:
	_anim_queue.append({"type": "healed", "unit": unit, "amount": amount})

func _on_unit_petrified(unit: BattleUnit) -> void:
	_anim_queue.append({"type": "petrified", "unit": unit})

func _on_unit_stone_cleared(unit: BattleUnit) -> void:
	_anim_queue.append({"type": "stone_cleared", "unit": unit})

func _on_rotated() -> void:
	_anim_queue.append({"type": "rotated"})

func _on_attack_support_used(supporter: BattleUnit, attacker: BattleUnit) -> void:
	_anim_queue.append({"type": "atk_support", "supporter": supporter, "attacker": attacker})

func _on_defense_support_used(supporter: BattleUnit, target: BattleUnit) -> void:
	_anim_queue.append({"type": "def_support", "supporter": supporter, "target": target})

func _on_action_announced(action_name: String) -> void:
	await _drain_queue()
	# 敵行動パネルを次のスロットに進める
	if _enemy_data != null and not _enemy_data.action_cycle.is_empty():
		_enemy_action_slot = (_enemy_action_slot + 1) % _enemy_data.action_cycle.size()
		_build_enemy_action_panel()
	_phase_lbl.text = "Choose..."
	if not _manager.is_over:
		_rotate_btn.disabled = false
		_stay_btn.disabled   = false

func _on_battle_ended(won: bool, _loot: Array) -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	await _drain_queue()
	_phase_lbl.text = "Victory!" if won else "Retreat..."
	_turn_lbl.text  = "勝利！" if won else "撤退..."
	_log("\n[b]%s[/b]" % ("=== 勝利！ ===" if won else "=== 撤退... ==="))
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/formation.tscn")

func _on_rotate_pressed() -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	_phase_lbl.text = "Rotate..."
	_manager.advance_turn(true)

func _on_stay_pressed() -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	_phase_lbl.text = "Stay..."
	_manager.advance_turn(false)

# ── アニメーションキュー ─────────────────────────────────────

func _drain_queue() -> void:
	while not _anim_queue.is_empty():
		var event: Dictionary = _anim_queue.pop_front()
		await _play_event(event)

func _play_event(event: Dictionary) -> void:
	match event["type"]:

		"turn_started":
			_turn_lbl.text  = "Turn  %d" % event["n"]
			_phase_lbl.text = "Battle!"
			var ea: String = event["enemy_action"]
			var order: String = " → ".join((event["timeline"] as Array).map(
				func(u: BattleUnit) -> String: return u.unit_name))
			_log("\n[color=#cccccc][Turn %d][/color]  %s" % [event["n"], order])
			await get_tree().create_timer(0.40).timeout

		"rotated":
			_phase_lbl.text = "Rotate!"
			var tw := create_tween().set_parallel(true)
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			for unit in _unit_nodes.keys():
				var bu := unit as BattleUnit
				if bu.side == BattleUnit.Side.ENEMY:
					continue
				var entry      = _unit_nodes[unit]
				var new_center := _iso(bu.col + 0.5, bu.row + 0.5)
				tw.tween_property(entry["body"], "position", new_center, 0.55)
				entry["body"].z_index = bu.row * 4 + bu.col
				entry["center"]       = new_center
			_log("[color=#445566]  ── ローテーション ──[/color]")
			await tw.finished
			await get_tree().create_timer(0.08).timeout

		"acted":
			await _play_attack_anim(
				event["attacker"], event["target"], event["dmg"], event["is_crit"])

		"healed":
			await _play_heal_anim(event["unit"], event["amount"])

		"petrified":
			_update_unit(event["unit"])
			_spawn_float_lbl_iso(event["unit"], "石化!", Color(0.7, 0.5, 1.0), 18)
			_log("  [color=#aa88ff]%s 石化[/color]" % (event["unit"] as BattleUnit).unit_name)
			await get_tree().create_timer(0.4).timeout

		"stone_cleared":
			_update_unit(event["unit"])
			_spawn_float_lbl_iso(event["unit"], "解除", Color(0.9, 0.8, 1.0), 16)
			_log("  [color=#ccaaff]%s 石化解除[/color]" % (event["unit"] as BattleUnit).unit_name)
			await get_tree().create_timer(0.35).timeout

		"died":
			_update_unit(event["unit"])
			_log("[color=#ff5555]  ✦ %s 戦死[/color]" % (event["unit"] as BattleUnit).unit_name)
			await get_tree().create_timer(0.2).timeout

		"atk_support":
			await _play_atk_support_anim(event["supporter"], event["attacker"])

		"def_support":
			await _play_def_support_anim(event["supporter"], event["target"])

# ── 攻撃アニメーション ───────────────────────────────────────

func _play_attack_anim(attacker: BattleUnit, target: BattleUnit,
		dmg: int, is_crit: bool) -> void:
	var crit_str := " ★" if is_crit else ""
	_log("  %s → [color=#ffcc44]%s[/color]: [b]%d[/b]%s" % [
		attacker.unit_name, target.unit_name, dmg, crit_str])

	if not _unit_nodes.has(attacker) or not _unit_nodes.has(target):
		await get_tree().create_timer(0.1).timeout
		return

	var entry_a = _unit_nodes[attacker]
	var body_a  = entry_a["body"]
	var orig: Vector2 = body_a.position

	var nudge := Vector2(90, -45) if attacker.side == BattleUnit.Side.PLAYER \
		else Vector2(-70, 35)
	var tw := create_tween()
	tw.tween_property(body_a, "position", orig + nudge, 0.13).set_ease(Tween.EASE_OUT)
	tw.tween_property(body_a, "position", orig, 0.22).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.11).timeout

	var entry_t = _unit_nodes[target]
	var hit_col := _hit_color(attacker)
	_flash_body(entry_t, hit_col)
	_spawn_unit_glow(entry_t["center"], hit_col, 95.0, 0.35)
	_spawn_damage_float_iso(entry_t["center"], dmg, is_crit)
	if is_crit:
		_spawn_crit_text_iso(entry_t["center"])

	_update_unit(target)
	await get_tree().create_timer(0.70).timeout

func _hit_color(attacker: BattleUnit) -> Color:
	if attacker.side == BattleUnit.Side.ENEMY:
		return Color(1.0, 0.2, 0.2, 0.65)
	if attacker.is_stone_attack:
		return Color(0.55, 0.3, 0.95, 0.65)
	if attacker.indirect_attack > 0:
		return Color(1.0, 0.9, 0.25, 0.65)
	return Color(1.0, 0.25, 0.15, 0.65)

func _flash_body(entry: Dictionary, color: Color) -> void:
	var body = entry["body"]
	if entry.get("is_3d", false):
		var tw := create_tween()
		tw.tween_property(body, "modulate",
			Color(color.r * 2.2 + 0.4, color.g * 1.4 + 0.2, color.b * 1.4 + 0.2), 0.06)
		tw.tween_property(body, "modulate", Color.WHITE, 0.32)
	else:
		var rect: ColorRect = body
		var orig: Color = rect.color
		var tw := create_tween()
		tw.tween_property(rect, "color", color, 0.06)
		tw.tween_property(rect, "color", orig, 0.28)

func _spawn_damage_float_iso(center: Vector2, dmg: int, is_crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = str(dmg)
	lbl.add_theme_font_size_override("font_size", 52 if is_crit else 34)
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.08) if is_crit else Color(1.0, 0.95, 0.85))
	if _font:
		lbl.add_theme_font_override("font", _font)
	var start := center + Vector2(-14, -30)
	lbl.position = start
	lbl.scale    = Vector2(0.1, 0.1)
	lbl.z_index  = 50
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.35, 1.35), 0.10).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.08)
	tw.tween_property(lbl, "position", start + Vector2(randf_range(-12, 12), -90), 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.35)
	tw.tween_callback(lbl.queue_free)

func _spawn_crit_text_iso(center: Vector2) -> void:
	_spawn_unit_glow(center, Color(1.0, 0.88, 0.0), 120.0, 0.45)

	var lbl := Label.new()
	lbl.text = "Critical!"
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.05))
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.position = center + Vector2(-42, -70)
	lbl.scale    = Vector2(0.3, 0.3)
	lbl.z_index  = 51
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.1, 1.1), 0.10)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.tween_callback(lbl.queue_free)

# ── 補助・回復アニメーション ──────────────────────────────────

func _play_atk_support_anim(supporter: BattleUnit, attacker: BattleUnit) -> void:
	_log("  [color=#ff8833]%s 攻撃補助[/color]" % supporter.unit_name)
	if not _unit_nodes.has(supporter):
		await get_tree().create_timer(0.1).timeout
		return
	_flash_body(_unit_nodes[supporter], Color(1.0, 0.5, 0.1, 0.72))
	_spawn_unit_glow(_unit_nodes[supporter]["center"], Color(1.0, 0.55, 0.1), 105.0, 0.55)
	if _unit_nodes.has(attacker):
		_spawn_float_lbl_iso(attacker, "攻撃補助！", Color(1.0, 0.65, 0.15), 20)
		_spawn_unit_glow(_unit_nodes[attacker]["center"], Color(1.0, 0.75, 0.1), 85.0, 0.50)
	await get_tree().create_timer(0.65).timeout

func _play_def_support_anim(supporter: BattleUnit, target: BattleUnit) -> void:
	_log("  [color=#4488ff]%s 守護 → %s[/color]" % [supporter.unit_name, target.unit_name])
	if not _unit_nodes.has(supporter):
		await get_tree().create_timer(0.1).timeout
		return
	_flash_body(_unit_nodes[supporter], Color(0.2, 0.55, 1.0, 0.72))
	_spawn_unit_glow(_unit_nodes[supporter]["center"], Color(0.2, 0.55, 1.0), 105.0, 0.55)
	if _unit_nodes.has(target):
		_spawn_float_lbl_iso(target, "守護！", Color(0.4, 0.78, 1.0), 20)
		_spawn_unit_glow(_unit_nodes[target]["center"], Color(0.3, 0.65, 1.0), 85.0, 0.50)
	await get_tree().create_timer(0.65).timeout

func _play_heal_anim(unit: BattleUnit, amount: int) -> void:
	if amount <= 0:
		_log("  [color=#44dd88]%s 回復（MAX）[/color]" % unit.unit_name)
	else:
		_log("  [color=#55ff99]%s +%d[/color]" % [unit.unit_name, amount])
	if not _unit_nodes.has(unit):
		await get_tree().create_timer(0.1).timeout
		return
	var center: Vector2 = _unit_nodes[unit]["center"]
	_flash_body(_unit_nodes[unit], Color(0.15, 1.0, 0.45, 0.55))
	_spawn_unit_glow(center, Color(0.2, 1.0, 0.45), 105.0, 0.50)
	var txt := "回復" if amount <= 0 else "+%d" % amount
	_spawn_float_lbl_iso(unit, txt, Color(0.35, 1.0, 0.55), 20)
	_update_unit(unit)
	await get_tree().create_timer(0.45).timeout

# ── ヘルパー ─────────────────────────────────────────────────

func _spawn_float_lbl_iso(unit: BattleUnit, text: String,
		color: Color, size: int = 16) -> void:
	if not _unit_nodes.has(unit):
		return
	var center: Vector2 = _unit_nodes[unit]["center"]
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if _font:
		lbl.add_theme_font_override("font", _font)
	var start := center + Vector2(-20, -20)
	lbl.position = start
	lbl.z_index  = 50
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", start + Vector2(0, -42), 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw.tween_callback(lbl.queue_free)

func _spawn_unit_glow(center: Vector2, glow_color: Color,
		radius: float = 90.0, duration: float = 0.35) -> void:
	var rect := ColorRect.new()
	var w := radius * 2.2
	var h := radius * 1.5
	rect.size = Vector2(w, h)
	rect.position = center - Vector2(w * 0.5, h * 0.55)
	rect.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.45)
	rect.z_index = 48
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)

func _log(text: String) -> void:
	_log_lbl.append_text(text + "\n")

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
	btn.add_theme_color_override("font_color",          Color.WHITE)
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.4))

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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if _font:
		l.add_theme_font_override("font", _font)
	parent.add_child(l)
	return l

# ── バトル開始 ───────────────────────────────────────────────

func _start_battle() -> void:
	_manager = BattleManager.new()
	add_child(_manager)
	_manager.battle_started.connect(_on_battle_started)
	_manager.turn_started.connect(_on_turn_started)
	_manager.action_announced.connect(_on_action_announced)
	_manager.unit_acted.connect(_on_unit_acted)
	_manager.unit_died.connect(_on_unit_died)
	_manager.unit_healed.connect(_on_unit_healed)
	_manager.unit_petrified.connect(_on_unit_petrified)
	_manager.unit_stone_cleared.connect(_on_unit_stone_cleared)
	_manager.rotated.connect(_on_rotated)
	_manager.attack_support_used.connect(_on_attack_support_used)
	_manager.defense_support_used.connect(_on_defense_support_used)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.start_battle(GameState.get_battle_entries(), GameState.get_battle_enemy())

# ── アイソグリッド描画 ────────────────────────────────────────

class _IsoGrid extends Node2D:
	var origin: Vector2
	var tile_w: float
	var tile_h: float

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var col := Color(0.4, 0.65, 1.0, 0.18)
		for c in range(0, 4):
			for r in range(0, 3):
				var tl := _p(c,     r    )
				var tr := _p(c + 1, r    )
				var bl := _p(c,     r + 1)
				var br := _p(c + 1, r + 1)
				draw_line(tl, tr, col, 1.0)
				draw_line(tr, br, col, 1.0)
				draw_line(br, bl, col, 1.0)
				draw_line(bl, tl, col, 1.0)

	func _p(c: int, r: int) -> Vector2:
		return origin + Vector2(
			(c - r) * tile_w * 0.5,
			(c + r) * tile_h * 0.5
		)
