## バトル画面 — アイソメトリックレイアウト + アニメーションキュー
extends Node

# ── アイソメ定数 ──────────────────────────────────────────────
const TILE_W  := 240.0
const TILE_H  := 120.0
const PANEL_X := 1500.0
const SP_W    := 70.0
const SP_H    := 95.0
const EN_W    := 180.0
const EN_H    := 220.0
const VP_W    := 180
const VP_H    := 240

var SW: float
var SH: float
var _origin: Vector2

var _root: Control
var _font: Font = null
var _log_lbl: RichTextLabel
var _rotate_btn: Button
var _stay_btn: Button
var _status_lbl: Label
var _enemy_action_lbl: Label
var _manager: BattleManager
var _anim_queue: Array = []

# BattleUnit → {body, accent, name_lbl, hp_bg?, hp_bar, center, is_3d, bar_w}
var _unit_nodes: Dictionary = {}
var _arena_vp: SubViewport

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
	return Vector2(SW * 0.68 + col * 95.0, SH * 0.18 + (col + row) * 65.0)

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
	_status_lbl = _lbl(_root, "Turn 0", Vector2(20, 18), 22, Color(0.88, 0.78, 0.30))
	_enemy_action_lbl = _lbl(_root, "", Vector2(20, 50), 14, Color(1.0, 0.65, 0.4))
	_build_right_panel()

func _build_right_panel() -> void:
	var pw    := SW - PANEL_X - 8.0
	var btn_y := SH - 90.0
	var bw    := (pw - 20.0) * 0.5

	_crect(_root, Vector2(PANEL_X - 6, 0), Vector2(pw + 14, SH),
		Color(0.03, 0.04, 0.09, 0.92)).z_index = 20

	_lbl(_root, "◆ BATTLE LOG ◆", Vector2(PANEL_X + 12, 8), 12,
		Color(0.4, 0.55, 0.8)).z_index = 21
	_crect(_root, Vector2(PANEL_X + 8, 26), Vector2(pw - 16, 1),
		Color(0.2, 0.3, 0.5)).z_index = 21

	_log_lbl = RichTextLabel.new()
	_log_lbl.position = Vector2(PANEL_X + 8, 30)
	_log_lbl.size = Vector2(pw - 16, btn_y - 40.0)
	_log_lbl.bbcode_enabled = true
	_log_lbl.scroll_following = true
	_log_lbl.add_theme_font_size_override("normal_font_size", 15)
	if _font:
		_log_lbl.add_theme_font_override("normal_font", _font)
	_log_lbl.z_index = 21
	_root.add_child(_log_lbl)

	_rotate_btn = Button.new()
	_rotate_btn.text = "ローテーション"
	_rotate_btn.position = Vector2(PANEL_X + 4, btn_y)
	_rotate_btn.size = Vector2(bw, 60)
	_rotate_btn.disabled = true
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	_style_button(_rotate_btn, Color(1.0, 0.55, 0.1))
	_rotate_btn.z_index = 22
	_root.add_child(_rotate_btn)

	_stay_btn = Button.new()
	_stay_btn.text = "ステイ"
	_stay_btn.position = Vector2(PANEL_X + 4 + bw + 12, btn_y)
	_stay_btn.size = Vector2(bw, 60)
	_stay_btn.disabled = true
	_stay_btn.pressed.connect(_on_stay_pressed)
	_style_button(_stay_btn, Color(0.3, 0.7, 1.0))
	_stay_btn.z_index = 22
	_root.add_child(_stay_btn)

# ── スプライト生成 ───────────────────────────────────────────

func _build_player_sprites(units: Array) -> void:
	for i in units.size():
		var unit: BattleUnit = units[i]
		var center := _iso(unit.col, unit.row)
		var z      := unit.row * 4 + unit.col
		var ratio  := float(unit.hp) / float(unit.hp_max)
		if i == 0:
			_unit_nodes[unit] = _add_3d_sprite(center, unit.unit_name, ratio, z)
		else:
			var hue := float(abs(hash(unit.unit_name)) % 360) / 360.0
			_unit_nodes[unit] = _add_player_sprite(
				center, unit.unit_name, Color.from_hsv(hue, 0.60, 0.65), ratio, z)

func _add_player_sprite(center: Vector2, unit_name: String,
		color: Color, hp_ratio: float, z: int) -> Dictionary:
	var body := _crect(_root,
		center - Vector2(SP_W * 0.5, SP_H * 0.5), Vector2(SP_W, SP_H),
		Color(color.r * 0.32, color.g * 0.32, color.b * 0.32, 0.95))
	body.z_index = z

	var accent := _crect(_root,
		center + Vector2(-SP_W * 0.5, SP_H * 0.5 - 11), Vector2(SP_W, 10),
		Color(color.r, color.g, color.b, 0.75))
	accent.z_index = z

	var name_lbl := _lbl(_root, unit_name,
		center + Vector2(-SP_W * 0.5, -SP_H * 0.5 - 20), 17, Color(0.88, 0.92, 1.0))
	name_lbl.z_index = z

	var bx    := center.x - SP_W * 0.5
	var by    := center.y + SP_H * 0.5 + 2.5
	var hp_bg := _crect(_root, Vector2(bx, by), Vector2(SP_W, 5), Color(0.07, 0.07, 0.09))
	hp_bg.z_index = z
	var hp_bar := _crect(_root, Vector2(bx, by), Vector2(SP_W * hp_ratio, 5), _hp_color(hp_ratio))
	hp_bar.z_index = z

	return {"body": body, "accent": accent, "name_lbl": name_lbl,
			"hp_bg": hp_bg, "hp_bar": hp_bar,
			"center": center, "is_3d": false, "bar_w": SP_W}

func _add_3d_sprite(center: Vector2, unit_name: String, hp_ratio: float, z: int) -> Dictionary:
	_arena_vp = SubViewport.new()
	_arena_vp.size = Vector2i(VP_W, VP_H)
	_arena_vp.transparent_bg = true
	_arena_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_arena_vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.5
	cam.look_at_from_position(Vector3(4, 4, 4), Vector3(0, 1.4, 0), Vector3.UP)
	_arena_vp.add_child(cam)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	_arena_vp.add_child(env_node)

	var light := DirectionalLight3D.new()
	light.light_energy = 1.5
	light.look_at_from_position(Vector3(3, 6, 3), Vector3(0, 0, 0), Vector3.UP)
	_arena_vp.add_child(light)

	var mesh_res = load("res://assets/obj/base2.obj")
	if mesh_res:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_res
		mi.rotation_degrees.y = 90
		_arena_vp.add_child(mi)

	var tex := TextureRect.new()
	tex.texture = _arena_vp.get_texture()
	tex.size = Vector2(VP_W, VP_H)
	tex.position = center - Vector2(VP_W * 0.5, VP_H * 0.60)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.z_index = z
	_root.add_child(tex)

	var name_lbl := _lbl(_root, unit_name,
		center - Vector2(SP_W * 0.5, VP_H * 0.44), 17, Color(0.88, 0.92, 1.0))
	name_lbl.z_index = z

	var bx    := center.x - SP_W * 0.5
	var by    := center.y + 49.0
	var hp_bg := _crect(_root, Vector2(bx, by), Vector2(SP_W, 5), Color(0.07, 0.07, 0.09))
	hp_bg.z_index = z
	var hp_bar := _crect(_root, Vector2(bx, by), Vector2(SP_W * hp_ratio, 5), _hp_color(hp_ratio))
	hp_bar.z_index = z

	return {"body": tex, "accent": tex, "name_lbl": name_lbl,
			"hp_bg": hp_bg, "hp_bar": hp_bar,
			"center": center, "is_3d": true, "bar_w": SP_W}

func _build_enemy_sprites(units: Array) -> void:
	for i in units.size():
		var unit: BattleUnit = units[i]
		var center := _iso_enemy(unit.col, unit.row)
		var z      := 100 + i
		var ratio  := float(unit.hp) / float(unit.hp_max)

		var body := _crect(_root,
			center - Vector2(EN_W * 0.5, EN_H * 0.5), Vector2(EN_W, EN_H),
			Color(0.42, 0.07, 0.07, 0.92))
		body.z_index = z
		_crect(_root, center + Vector2(-EN_W * 0.5, EN_H * 0.5 - 30),
			Vector2(EN_W, 28), Color(0.82, 0.15, 0.15, 0.85)).z_index = z

		var name_lbl := _lbl(_root, unit.unit_name,
			center + Vector2(-EN_W * 0.5, -EN_H * 0.5 - 26), 20, Color(1.0, 0.62, 0.62))
		name_lbl.z_index = z

		var bw  := EN_W + 40.0
		var bx  := center.x - bw * 0.5
		var by  := center.y + EN_H * 0.5 + 8
		_crect(_root, Vector2(bx, by), Vector2(bw, 10), Color(0.07, 0.07, 0.09)).z_index = z
		var hp_bar := _crect(_root, Vector2(bx, by), Vector2(bw * ratio, 10), Color(0.85, 0.18, 0.18))
		hp_bar.z_index = z

		_unit_nodes[unit] = {
			"body": body, "accent": body, "name_lbl": name_lbl,
			"hp_bar": hp_bar, "center": center,
			"is_3d": false, "bar_w": bw
		}

# ── ユニット更新 ─────────────────────────────────────────────

func _update_unit(unit: BattleUnit) -> void:
	if not _unit_nodes.has(unit):
		return
	var entry  := _unit_nodes[unit]
	var ratio  := float(unit.hp) / float(unit.hp_max)
	var bw: float = entry.get("bar_w", SP_W)
	var hp_bar: ColorRect = entry["hp_bar"]
	hp_bar.size.x = bw * clampf(ratio, 0.0, 1.0)
	hp_bar.color  = _hp_color(ratio)
	if not unit.is_alive:
		entry["body"].modulate = Color(0.35, 0.35, 0.35, 0.55)

# ── シグナルハンドラ ─────────────────────────────────────────

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	_build_player_sprites(pg.get_all_alive())
	_build_enemy_sprites(eg.get_all_alive())
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
	_enemy_action_lbl.text = "次の敵行動: %s" % action_name
	if not _manager.is_over:
		_rotate_btn.disabled = false
		_stay_btn.disabled   = false

func _on_battle_ended(won: bool, _loot: Array) -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	await _drain_queue()
	_status_lbl.text = "勝利！" if won else "撤退..."
	_log("\n[b]%s[/b]" % ("=== 勝利！ ===" if won else "=== 撤退... ==="))
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/formation.tscn")

func _on_rotate_pressed() -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	_manager.advance_turn(true)

func _on_stay_pressed() -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	_manager.advance_turn(false)

# ── アニメーションキュー ─────────────────────────────────────

func _drain_queue() -> void:
	while not _anim_queue.is_empty():
		var event: Dictionary = _anim_queue.pop_front()
		await _play_event(event)

func _play_event(event: Dictionary) -> void:
	match event["type"]:

		"turn_started":
			_status_lbl.text = "Turn %d" % event["n"]
			var ea: String = event["enemy_action"]
			if ea != "":
				_enemy_action_lbl.text = "敵行動: %s" % ea
			var order: String = " → ".join((event["timeline"] as Array).map(
				func(u: BattleUnit) -> String: return u.unit_name))
			_log("\n[color=#cccccc][Turn %d][/color]  %s" % [event["n"], order])
			await get_tree().create_timer(0.15).timeout

		"rotated":
			var tw := create_tween().set_parallel(true)
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			for unit in _unit_nodes.keys():
				var bu := unit as BattleUnit
				if bu.side == BattleUnit.Side.ENEMY:
					continue
				var entry      := _unit_nodes[unit]
				var new_center := _iso(bu.col, bu.row)
				var delta      := new_center - entry["center"]
				var body       = entry["body"]
				tw.tween_property(body, "position", body.position + delta, 0.55)
				var accent = entry["accent"]
				if accent != body:
					tw.tween_property(accent, "position", accent.position + delta, 0.55)
				tw.tween_property(entry["name_lbl"], "position",
					entry["name_lbl"].position + delta, 0.55)
				if entry.has("hp_bg"):
					tw.tween_property(entry["hp_bg"], "position",
						entry["hp_bg"].position + delta, 0.55)
				tw.tween_property(entry["hp_bar"], "position",
					entry["hp_bar"].position + delta, 0.55)
				var new_z := bu.row * 4 + bu.col
				body.z_index              = new_z
				accent.z_index            = new_z
				entry["name_lbl"].z_index = new_z
				if entry.has("hp_bg"):
					entry["hp_bg"].z_index = new_z
				entry["hp_bar"].z_index = new_z
				entry["center"]         = new_center
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

	var entry_a := _unit_nodes[attacker]
	var body_a  = entry_a["body"]
	var orig    := body_a.position

	# プレイヤー→敵: 右上へナッジ　敵→プレイヤー: 左下へナッジ
	var nudge := Vector2(70, -35) if attacker.side == BattleUnit.Side.PLAYER \
		else Vector2(-55, 28)
	var tw := create_tween()
	tw.tween_property(body_a, "position", orig + nudge, 0.10).set_ease(Tween.EASE_OUT)
	tw.tween_property(body_a, "position", orig, 0.16).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.08).timeout

	var entry_t := _unit_nodes[target]
	_flash_body(entry_t, _hit_color(attacker))
	_spawn_damage_float_iso(entry_t["center"], dmg, is_crit)
	if is_crit:
		_spawn_crit_text_iso(entry_t["center"])

	_update_unit(target)
	await get_tree().create_timer(0.48).timeout

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
		# TextureRect は modulate でフラッシュ（乗算なので明度を上げて色を出す）
		var tw := create_tween()
		tw.tween_property(body, "modulate",
			Color(color.r * 1.6 + 0.2, color.g * 1.2 + 0.1, color.b * 1.2 + 0.1), 0.07)
		tw.tween_property(body, "modulate", Color.WHITE, 0.25)
	else:
		var rect := body as ColorRect
		var orig := rect.color
		var tw := create_tween()
		tw.tween_property(rect, "color", color, 0.07)
		tw.tween_property(rect, "color", orig, 0.22)

func _spawn_damage_float_iso(center: Vector2, dmg: int, is_crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = str(dmg)
	lbl.add_theme_font_size_override("font_size", 34 if is_crit else 22)
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.15) if is_crit else Color(1.0, 0.95, 0.85))
	if _font:
		lbl.add_theme_font_override("font", _font)
	var start := center + Vector2(-10, -30)
	lbl.position = start
	lbl.z_index  = 50
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", start + Vector2(randf_range(-8, 8), -65), 0.75)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.22)
	tw.tween_callback(lbl.queue_free)

func _spawn_crit_text_iso(center: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "Critical!"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.position = center + Vector2(-30, -55)
	lbl.scale    = Vector2(0.4, 0.4)
	lbl.z_index  = 51
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.08)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.12)
	tw.tween_callback(lbl.queue_free)

# ── 補助・回復アニメーション ──────────────────────────────────

func _play_atk_support_anim(supporter: BattleUnit, attacker: BattleUnit) -> void:
	_log("  [color=#ff8833]%s 攻撃補助[/color]" % supporter.unit_name)
	if not _unit_nodes.has(supporter):
		await get_tree().create_timer(0.1).timeout
		return
	_flash_body(_unit_nodes[supporter], Color(1.0, 0.5, 0.1, 0.72))
	if _unit_nodes.has(attacker):
		_spawn_float_lbl_iso(attacker, "攻撃補助", Color(1.0, 0.55, 0.15), 14)
	await get_tree().create_timer(0.42).timeout

func _play_def_support_anim(supporter: BattleUnit, target: BattleUnit) -> void:
	_log("  [color=#4488ff]%s 守護 → %s[/color]" % [supporter.unit_name, target.unit_name])
	if not _unit_nodes.has(supporter):
		await get_tree().create_timer(0.1).timeout
		return
	_flash_body(_unit_nodes[supporter], Color(0.2, 0.55, 1.0, 0.72))
	if _unit_nodes.has(target):
		_spawn_float_lbl_iso(target, "守護", Color(0.4, 0.75, 1.0), 15)
	await get_tree().create_timer(0.45).timeout

func _play_heal_anim(unit: BattleUnit, amount: int) -> void:
	_log("  [color=#55ff99]%s +%d[/color]" % [unit.unit_name, amount])
	if not _unit_nodes.has(unit):
		await get_tree().create_timer(0.1).timeout
		return
	_flash_body(_unit_nodes[unit], Color(0.2, 1.0, 0.4, 0.45))
	_spawn_float_lbl_iso(unit, "+%d" % amount, Color(0.4, 1.0, 0.6), 18)
	_update_unit(unit)
	await get_tree().create_timer(0.35).timeout

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
