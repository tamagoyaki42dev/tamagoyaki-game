## バトル画面 — アニメーションキューで1アクションずつ順番に再生
extends Node

const CARD_W   := 190.0
const CARD_H   := 115.0
const CARD_GAP := 14.0
const ROW_GAP  := 12.0

var SW: float
var SH: float
var GRID_X: float
var ENEMY_Y0: float
var PLAYER_Y0: float
var LOG_X: float

var _root: Control
var _log_lbl: RichTextLabel
var _rotate_btn: Button
var _stay_btn: Button
var _status_lbl: Label
var _enemy_action_lbl: Label
var _manager: BattleManager
var _cards: Dictionary = {}   # BattleUnit → {panel, hp_bar, hp_lbl}
var _anim_queue: Array = []
var _arena_vp: SubViewport

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	SW        = vp.x
	SH        = vp.y
	GRID_X    = SW * 0.22
	ENEMY_Y0  = SH * 0.05
	PLAYER_Y0 = SH * 0.58
	LOG_X     = SW * 0.70
	_build_ui()
	_start_battle()

# ══════════════════════════════════ 3Dアリーナ ═══════════════════════════════

func _build_3d_arena() -> void:
	_arena_vp = SubViewport.new()
	_arena_vp.size = Vector2i(int(LOG_X - 10), int(SH * 0.48))
	_arena_vp.transparent_bg = true
	_arena_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_arena_vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
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
		_arena_vp.add_child(mi)

	var tex_rect := TextureRect.new()
	tex_rect.texture = _arena_vp.get_texture()
	tex_rect.position = Vector2.ZERO
	tex_rect.size = Vector2(LOG_X - 10, SH * 0.48)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tex_rect)

# ══════════════════════════════════ UI構築 ════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ArenaBg.new()
	bg.position     = Vector2.ZERO
	bg.size         = Vector2(LOG_X - 10, SH)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_build_3d_arena()

	_crect(_root, Vector2.ZERO, Vector2(SW, SH), Color(0, 0, 0, 0.35))
	_crect(_root, Vector2(LOG_X - 8, 0), Vector2(2, SH), Color(0.25, 0.55, 1.0, 0.5))
	_crect(_root, Vector2(0, SH * 0.5), Vector2(LOG_X - 10, 1), Color(0.25, 0.5, 0.9, 0.35))

	_lbl(_root, "[ 敵 ]",  Vector2(40, ENEMY_Y0), 20, Color(1.0, 0.45, 0.45))
	_lbl(_root, "[ 味方 ]", Vector2(40, PLAYER_Y0 - 28), 20, Color(0.45, 0.75, 1.0))

	for i in 3:
		var py := PLAYER_Y0 + (i * (CARD_H + ROW_GAP)) + 30
		_lbl(_root, ["前","中","後"][i], Vector2(340, py), 15, Color(0.55, 0.55, 0.65))

	_panel(_root, Vector2(0, SH * 0.5 - 60), Vector2(LOG_X - 10, 96),
		Color(0, 0, 0, 0.5), Color(0.2, 0.4, 0.7, 0.4))
	_status_lbl = _lbl(_root, "Turn 0",
		Vector2(LOG_X * 0.5 - 52, SH * 0.5 - 56), 30, Color(0.95, 0.82, 0.3))
	_enemy_action_lbl = _lbl(_root, "",
		Vector2(40, SH * 0.5 - 20), 13, Color(1.0, 0.65, 0.4))

	_rotate_btn = Button.new()
	_rotate_btn.text = "ローテーション"
	_rotate_btn.position = Vector2(LOG_X * 0.5 - 188, SH * 0.5 - 12)
	_rotate_btn.size = Vector2(180, 46)
	_rotate_btn.add_theme_font_size_override("font_size", 16)
	_rotate_btn.disabled = true
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	_style_button(_rotate_btn, Color(1.0, 0.55, 0.1))
	_root.add_child(_rotate_btn)

	_stay_btn = Button.new()
	_stay_btn.text = "ステイ"
	_stay_btn.position = Vector2(LOG_X * 0.5 + 4, SH * 0.5 - 12)
	_stay_btn.size = Vector2(180, 46)
	_stay_btn.add_theme_font_size_override("font_size", 16)
	_stay_btn.disabled = true
	_stay_btn.pressed.connect(_on_stay_pressed)
	_style_button(_stay_btn, Color(0.3, 0.7, 1.0))
	_root.add_child(_stay_btn)

	_panel(_root, Vector2(LOG_X, 8), Vector2(SW - LOG_X - 8, SH - 16),
		Color(0.02, 0.03, 0.07, 0.88), Color(0.2, 0.3, 0.5))
	_lbl(_root, "◆ BATTLE LOG ◆", Vector2(LOG_X + 12, 16), 12, Color(0.4, 0.55, 0.8))
	_crect(_root, Vector2(LOG_X + 8, 34), Vector2(SW - LOG_X - 24, 1), Color(0.2, 0.3, 0.5))
	_log_lbl = RichTextLabel.new()
	_log_lbl.position = Vector2(LOG_X + 8, 38)
	_log_lbl.size = Vector2(SW - LOG_X - 24, SH - 54)
	_log_lbl.bbcode_enabled = true
	_log_lbl.scroll_following = true
	_root.add_child(_log_lbl)

# ══════════════════════════════ ユニットカード ════════════════════════════════

func _build_cards(pg: RotationGrid, eg: RotationGrid) -> void:
	for unit in pg.get_all_alive() + eg.get_all_alive():
		var is_enemy: bool = unit.side == BattleUnit.Side.ENEMY
		var bg_col     := Color(0.15, 0.04, 0.04, 0.90) if is_enemy else Color(0.04, 0.08, 0.18, 0.90)
		var border_col := Color(0.9, 0.25, 0.25) if is_enemy else Color(0.25, 0.55, 0.95)
		var ctrl := _panel(_root, _card_pos(unit), Vector2(CARD_W, CARD_H), bg_col, border_col, 5)

		var portrait_bg := Color(0.10, 0.03, 0.03, 0.8) if is_enemy else Color(0.03, 0.06, 0.14, 0.8)
		_crect(ctrl, Vector2(CARD_W - 48, 0), Vector2(48, CARD_H), portrait_bg)
		var sprite := CharacterSprite.new()
		sprite.position     = Vector2(CARD_W - 48, 0)
		sprite.size         = Vector2(48, CARD_H)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_enemy:
			var cd := unit.source_data as CharacterData
			if cd:
				var hue := float(abs(hash(cd.char_name)) % 360) / 360.0
				sprite.setup(cd.job, Color.from_hsv(hue, 0.58, 0.82))
		else:
			sprite.setup(-1, Color(0.72, 0.20, 0.20))
		ctrl.add_child(sprite)

		_lbl(ctrl, unit.unit_name, Vector2(6, 5), 15)

		if not is_enemy:
			var cd := unit.source_data as CharacterData
			if cd:
				_lbl(ctrl, CharacterJob.get_display_name(cd.job), Vector2(6, 22), 11, Color(0.65, 0.75, 1.0))
		else:
			var ed := unit.source_data as EnemyData
			if ed:
				_lbl(ctrl, ed.get_stat_type_name(), Vector2(6, 22), 11, Color(1.0, 0.65, 0.55))

		_lbl(ctrl, "ATK %d" % unit.attack, Vector2(6, 38),  11, Color(1.0, 0.75, 0.3))
		_lbl(ctrl, "SPD %d" % unit.speed,  Vector2(80, 38), 11, Color(0.5, 1.0, 0.6))

		_crect(ctrl, Vector2(6, 57), Vector2(CARD_W - 60, 8), Color(0.08, 0.08, 0.10))
		var hp_bar := _crect(ctrl, Vector2(6, 57), Vector2(CARD_W - 60, 8), Color(0.2, 0.75, 0.3))
		var hp_lbl := _lbl(ctrl, "%d/%d" % [unit.hp, unit.hp_max], Vector2(6, 68), 12)

		_cards[unit] = {panel = ctrl, hp_bar = hp_bar, hp_lbl = hp_lbl}

func _update_card(unit: BattleUnit) -> void:
	if not _cards.has(unit):
		return
	var c = _cards[unit]
	var ratio := float(unit.hp) / float(unit.hp_max)
	c.hp_bar.size.x = (CARD_W - 60) * clampf(ratio, 0.0, 1.0)
	c.hp_bar.color   = _hp_color(ratio)
	c.hp_lbl.text    = "%d/%d" % [unit.hp, unit.hp_max]
	if not unit.is_alive:
		c.panel.modulate = Color(0.35, 0.35, 0.35, 0.55)

func _rebuild_positions() -> void:
	for unit: BattleUnit in _cards.keys():
		_cards[unit].panel.position = _card_pos(unit)

func _card_pos(unit: BattleUnit) -> Vector2:
	var x := GRID_X + unit.col * (CARD_W + CARD_GAP)
	var y: float
	if unit.side == BattleUnit.Side.ENEMY:
		y = ENEMY_Y0 + (SH * 0.5 - ENEMY_Y0 - CARD_H) / 2.0
	else:
		y = PLAYER_Y0 + unit.row * (CARD_H + ROW_GAP)
	return Vector2(x, y)

func _hp_color(r: float) -> Color:
	if r > 0.6: return Color(0.15, 0.75, 0.25)
	if r > 0.3: return Color(0.85, 0.65, 0.05)
	return Color(0.85, 0.15, 0.15)

# ══════════════════════════════ シグナルハンドラ ══════════════════════════════
# advance_turn()はすべて同期的に発火するため、シグナルは全部キューに積む。
# action_announced / battle_ended だけがキューの再生トリガーになる。

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	_build_cards(pg, eg)
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

# ══════════════════════════════ アニメーションキュー ══════════════════════════

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
			_rebuild_positions()
			_log("[color=#445566]  ── ローテーション ──[/color]")
			await get_tree().create_timer(0.25).timeout

		"acted":
			await _play_attack_anim(
				event["attacker"], event["target"], event["dmg"], event["is_crit"])

		"healed":
			await _play_heal_anim(event["unit"], event["amount"])

		"petrified":
			_update_card(event["unit"])
			_spawn_float_lbl(event["unit"], "石化!", Color(0.7, 0.5, 1.0), 18)
			_log("  [color=#aa88ff]%s 石化[/color]" % (event["unit"] as BattleUnit).unit_name)
			await get_tree().create_timer(0.4).timeout

		"stone_cleared":
			_update_card(event["unit"])
			_spawn_float_lbl(event["unit"], "解除", Color(0.9, 0.8, 1.0), 16)
			_log("  [color=#ccaaff]%s 石化解除[/color]" % (event["unit"] as BattleUnit).unit_name)
			await get_tree().create_timer(0.35).timeout

		"died":
			_update_card(event["unit"])
			_log("[color=#ff5555]  ✦ %s 戦死[/color]" % (event["unit"] as BattleUnit).unit_name)
			await get_tree().create_timer(0.2).timeout

		"atk_support":
			await _play_atk_support_anim(event["supporter"], event["attacker"])

		"def_support":
			await _play_def_support_anim(event["supporter"], event["target"])

# ══════════════════════════════ 攻撃アニメーション ═══════════════════════════

func _play_attack_anim(attacker: BattleUnit, target: BattleUnit,
		dmg: int, is_crit: bool) -> void:
	var crit_str := " ★" if is_crit else ""
	_log("  %s → [color=#ffcc44]%s[/color]: [b]%d[/b]%s" % [
		attacker.unit_name, target.unit_name, dmg, crit_str])

	if not _cards.has(attacker) or not _cards.has(target):
		await get_tree().create_timer(0.1).timeout
		return

	var atk_panel: Panel = _cards[attacker].panel
	var tgt_panel: Panel = _cards[target].panel
	var orig_pos          := atk_panel.position

	# 攻撃側カードのナッジ（味方は上、敵は下）
	var nudge := Vector2(0, -35.0 if attacker.side == BattleUnit.Side.PLAYER else 35.0)
	var nudge_t := create_tween()
	nudge_t.tween_property(atk_panel, "position", orig_pos + nudge, 0.10).set_ease(Tween.EASE_OUT)
	nudge_t.tween_property(atk_panel, "position", orig_pos, 0.14).set_ease(Tween.EASE_IN)

	# ナッジのピークでヒットエフェクトを発火
	await get_tree().create_timer(0.08).timeout

	var flash := ColorRect.new()
	flash.size         = tgt_panel.size
	flash.position     = Vector2.ZERO
	flash.color        = _hit_color(attacker)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tgt_panel.add_child(flash)
	var flash_t := create_tween()
	flash_t.tween_property(flash, "color:a", 0.0, 0.28)
	flash_t.tween_callback(flash.queue_free)

	_spawn_damage_float(target, dmg, is_crit)
	if is_crit:
		_spawn_crit_text(target)

	_update_card(target)

	await get_tree().create_timer(0.45).timeout

func _hit_color(attacker: BattleUnit) -> Color:
	if attacker.side == BattleUnit.Side.ENEMY:
		return Color(1.0, 0.2, 0.2, 0.65)
	if attacker.is_stone_attack:
		return Color(0.55, 0.3, 0.95, 0.65)   # 紫 = 石化/魔法
	if attacker.indirect_attack > 0:
		return Color(1.0, 0.9, 0.25, 0.65)    # 黄 = 遠距離
	return Color(1.0, 0.25, 0.15, 0.65)        # 赤 = 近接物理

func _spawn_damage_float(unit: BattleUnit, dmg: int, is_crit: bool) -> void:
	if not _cards.has(unit):
		return
	var panel: Panel = _cards[unit].panel
	var lbl          := Label.new()
	lbl.text = str(dmg)
	lbl.add_theme_font_size_override("font_size", 34 if is_crit else 22)
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.15) if is_crit else Color(1.0, 0.95, 0.85))
	var start := panel.position + Vector2(panel.size.x * 0.25, panel.size.y * 0.1)
	lbl.position = start
	lbl.z_index  = 10
	_root.add_child(lbl)
	var t := create_tween()
	t.tween_property(lbl, "position", start + Vector2(randf_range(-10, 10), -58), 0.7)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.22)
	t.tween_callback(lbl.queue_free)

func _spawn_crit_text(unit: BattleUnit) -> void:
	if not _cards.has(unit):
		return
	var panel: Panel = _cards[unit].panel
	var lbl          := Label.new()
	lbl.text = "Critical!"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.position = panel.position + Vector2(panel.size.x * 0.05, -32)
	lbl.scale    = Vector2(0.4, 0.4)
	lbl.z_index  = 11
	_root.add_child(lbl)
	var t := create_tween()
	t.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.08)
	t.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.12)
	t.tween_callback(lbl.queue_free)

# ══════════════════════════════ 補助アニメーション ═══════════════════════════

func _play_atk_support_anim(supporter: BattleUnit, attacker: BattleUnit) -> void:
	_log("  [color=#ff8833]%s 攻撃補助[/color]" % supporter.unit_name)
	if not _cards.has(supporter):
		await get_tree().create_timer(0.1).timeout
		return
	var sup_panel: Panel = _cards[supporter].panel

	var flash := ColorRect.new()
	flash.size         = sup_panel.size
	flash.position     = Vector2.ZERO
	flash.color        = Color(1.0, 0.5, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sup_panel.add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.72, 0.07)
	ft.tween_property(flash, "color:a", 0.0,  0.38)
	ft.tween_callback(flash.queue_free)

	if _cards.has(attacker):
		_spawn_float_lbl(attacker, "攻撃補助", Color(1.0, 0.55, 0.15), 14)

	await get_tree().create_timer(0.42).timeout

func _play_def_support_anim(supporter: BattleUnit, target: BattleUnit) -> void:
	_log("  [color=#4488ff]%s 守護 → %s[/color]" % [supporter.unit_name, target.unit_name])
	if not _cards.has(supporter):
		await get_tree().create_timer(0.1).timeout
		return
	var sup_panel: Panel = _cards[supporter].panel

	var flash := ColorRect.new()
	flash.size         = sup_panel.size
	flash.position     = Vector2.ZERO
	flash.color        = Color(0.2, 0.55, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sup_panel.add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.72, 0.07)
	ft.tween_property(flash, "color:a", 0.0,  0.38)
	ft.tween_callback(flash.queue_free)

	if _cards.has(target):
		var tgt_panel: Panel = _cards[target].panel
		var shield := Panel.new()
		shield.size         = tgt_panel.size
		shield.position     = Vector2.ZERO
		shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shield.add_theme_stylebox_override("panel", _make_stylebox(
			Color(0.2, 0.5, 1.0, 0.15), Color(0.35, 0.68, 1.0, 0.95), 5, 3))
		shield.modulate.a = 0.0
		tgt_panel.add_child(shield)
		var bt := create_tween()
		bt.tween_property(shield, "modulate:a", 1.0, 0.08)
		bt.tween_property(shield, "modulate:a", 0.0, 0.45).set_delay(0.1)
		bt.tween_callback(shield.queue_free)

		_spawn_float_lbl(target, "守護", Color(0.4, 0.75, 1.0), 15)

	await get_tree().create_timer(0.45).timeout

# ══════════════════════════════ 回復アニメーション ═══════════════════════════

func _play_heal_anim(unit: BattleUnit, amount: int) -> void:
	_log("  [color=#55ff99]%s +%d[/color]" % [unit.unit_name, amount])
	if not _cards.has(unit):
		await get_tree().create_timer(0.1).timeout
		return
	var panel: Panel = _cards[unit].panel

	var flash := ColorRect.new()
	flash.size         = panel.size
	flash.position     = Vector2.ZERO
	flash.color        = Color(0.2, 1.0, 0.4, 0.45)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.3)
	ft.tween_callback(flash.queue_free)

	_spawn_float_lbl(unit, "+%d" % amount, Color(0.4, 1.0, 0.6), 18)
	_update_card(unit)
	await get_tree().create_timer(0.35).timeout

# ══════════════════════════════ ヘルパー ══════════════════════════════════════

# カード上空にテキストをフロート表示（_root 座標系で追加）
func _spawn_float_lbl(unit: BattleUnit, text: String,
		color: Color, size: int = 16) -> void:
	if not _cards.has(unit):
		return
	var panel: Panel = _cards[unit].panel
	var lbl          := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	var start := panel.position + Vector2(panel.size.x * 0.2, panel.size.y * 0.15)
	lbl.position = start
	lbl.z_index  = 10
	_root.add_child(lbl)
	var t := create_tween()
	t.tween_property(lbl, "position", start + Vector2(0, -42), 0.6)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.15)
	t.tween_callback(lbl.queue_free)

func _log(text: String) -> void:
	_log_lbl.append_text(text + "\n")

func _make_stylebox(bg: Color, border: Color, radius: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

func _panel(parent: Node, pos: Vector2, sz: Vector2,
		bg: Color, border: Color, radius: int = 4) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", _make_stylebox(bg, border, radius))
	parent.add_child(p)
	return p

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
	parent.add_child(l)
	return l

# ════════════════════════════════ バトルデータ ════════════════════════════════

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
