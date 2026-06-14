## バトル画面 — コードだけで組んだUI（.tscn不要）
## scenes/node.tscn の Node にアタッチして F5 で動く
extends Node

# ── レイアウト（_readyで実際のビューポートサイズから計算）────────────────────
const CARD_W   := 160.0
const CARD_H   := 95.0
const CARD_GAP := 12.0
const ROW_GAP  := 10.0

var SW: float
var SH: float
var GRID_X: float
var ENEMY_Y0: float
var PLAYER_Y0: float
var LOG_X: float

# ── ノード参照 ────────────────────────────────────────────────────────────────
var _root: Control
var _log_lbl: RichTextLabel
var _rotate_btn: Button
var _stay_btn: Button
var _status_lbl: Label
var _manager: BattleManager
var _cards: Dictionary = {}   # BattleUnit → {ctrl, hp_bar, hp_lbl}

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	SW       = vp.x
	SH       = vp.y
	GRID_X   = SW * 0.22
	ENEMY_Y0 = SH * 0.05
	PLAYER_Y0 = SH * 0.53
	LOG_X    = SW * 0.70
	_build_ui()
	_start_battle()

# ══════════════════════════════════ UI構築 ════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 背景画像
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load("res://assets/bg_arena.jpg")
	_root.add_child(bg)

	# 暗めオーバーレイ（テキスト読みやすさ確保）
	_crect(_root, Vector2.ZERO, Vector2(SW, SH), Color(0, 0, 0, 0.55))

	# 縦分割ライン
	_crect(_root, Vector2(LOG_X - 8, 0), Vector2(2, SH), Color(0.25, 0.55, 1.0, 0.5))

	# 横分割ライン
	_crect(_root, Vector2(0, SH * 0.5), Vector2(LOG_X - 10, 1), Color(0.25, 0.5, 0.9, 0.35))

	# セクションヘッダ
	_lbl(_root, "[ 敵 ]",  Vector2(40, ENEMY_Y0), 20, Color(1.0, 0.45, 0.45))
	_lbl(_root, "[ 味方 ]", Vector2(40, PLAYER_Y0 - 28), 20, Color(0.45, 0.75, 1.0))

	# 行ラベル（味方のみ：前→後）
	for i in 3:
		var py := PLAYER_Y0 + (i * (CARD_H + ROW_GAP)) + 30
		_lbl(_root, ["前","中","後"][i], Vector2(340, py), 15, Color(0.55, 0.55, 0.65))

	# ターン表示エリア（中央帯）
	_panel(_root, Vector2(0, SH * 0.5 - 56), Vector2(LOG_X - 10, 68),
		Color(0, 0, 0, 0.5), Color(0.2, 0.4, 0.7, 0.4))
	_status_lbl = _lbl(_root, "Turn 0", Vector2(LOG_X * 0.5 - 60, SH * 0.5 - 46), 22)

	# ローテーションボタン（オレンジ）
	_rotate_btn = Button.new()
	_rotate_btn.text = "ローテーション"
	_rotate_btn.position = Vector2(LOG_X * 0.5 - 188, SH * 0.5 - 12)
	_rotate_btn.size = Vector2(180, 46)
	_rotate_btn.add_theme_font_size_override("font_size", 16)
	_rotate_btn.disabled = true
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	_style_button(_rotate_btn, Color(1.0, 0.55, 0.1))
	_root.add_child(_rotate_btn)

	# ステイボタン（シアン）
	_stay_btn = Button.new()
	_stay_btn.text = "ステイ"
	_stay_btn.position = Vector2(LOG_X * 0.5 + 4, SH * 0.5 - 12)
	_stay_btn.size = Vector2(180, 46)
	_stay_btn.add_theme_font_size_override("font_size", 16)
	_stay_btn.disabled = true
	_stay_btn.pressed.connect(_on_stay_pressed)
	_style_button(_stay_btn, Color(0.3, 0.7, 1.0))
	_root.add_child(_stay_btn)

	# バトルログパネル
	_panel(_root, Vector2(LOG_X, 8), Vector2(SW - LOG_X - 8, SH - 16),
		Color(0.02, 0.03, 0.07, 0.88), Color(0.2, 0.3, 0.5))
	_log_lbl = RichTextLabel.new()
	_log_lbl.position = Vector2(LOG_X + 8, 16)
	_log_lbl.size = Vector2(SW - LOG_X - 24, SH - 32)
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

		# 名前
		_lbl(ctrl, unit.unit_name, Vector2(6, 5), 15)

		# 職業 or 敵タイプ
		if not is_enemy:
			var char_data := unit.source_data as CharacterData
			if char_data:
				_lbl(ctrl, CharacterJob.get_display_name(char_data.job),
					Vector2(6, 22), 11, Color(0.65, 0.75, 1.0))
		else:
			var enemy_data := unit.source_data as EnemyData
			if enemy_data:
				_lbl(ctrl, enemy_data.get_stat_type_name(),
					Vector2(6, 22), 11, Color(1.0, 0.65, 0.55))

		# HPバー背景
		_crect(ctrl, Vector2(6, 42), Vector2(CARD_W - 12, 8), Color(0.08, 0.08, 0.10))

		# HPバー本体
		var hp_bar := _crect(ctrl, Vector2(6, 42), Vector2(CARD_W - 12, 8), Color(0.2, 0.75, 0.3))

		# HPテキスト
		var hp_lbl := _lbl(ctrl, "%d/%d" % [unit.hp, unit.hp_max], Vector2(6, 54), 12)

		_cards[unit] = {panel = ctrl, hp_bar = hp_bar, hp_lbl = hp_lbl}

func _update_card(unit: BattleUnit) -> void:
	if not _cards.has(unit):
		return
	var c = _cards[unit]
	var ratio := float(unit.hp) / float(unit.hp_max)
	c.hp_bar.size.x = (CARD_W - 12) * clampf(ratio, 0.0, 1.0)
	c.hp_bar.color = _hp_color(ratio)
	c.hp_lbl.text = "%d/%d" % [unit.hp, unit.hp_max]
	if not unit.is_alive:
		c.panel.modulate = Color(0.35, 0.35, 0.35, 0.55)

func _rebuild_positions() -> void:
	for unit: BattleUnit in _cards.keys():
		_cards[unit].panel.position = _card_pos(unit)

func _card_pos(unit: BattleUnit) -> Vector2:
	var x := GRID_X + unit.col * (CARD_W + CARD_GAP)
	var y: float
	if unit.side == BattleUnit.Side.ENEMY:
		# 敵は行の概念なし。敵エリア内に垂直中央配置
		y = ENEMY_Y0 + (SH * 0.5 - ENEMY_Y0 - CARD_H) / 2.0
	else:
		y = PLAYER_Y0 + unit.row * (CARD_H + ROW_GAP)
	return Vector2(x, y)

func _hp_color(r: float) -> Color:
	if r > 0.6: return Color(0.15, 0.75, 0.25)
	if r > 0.3: return Color(0.85, 0.65, 0.05)
	return Color(0.85, 0.15, 0.15)

# ══════════════════════════════════ シグナル ══════════════════════════════════

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	_build_cards(pg, eg)
	_log("[color=#888888]=== バトル開始 ===[/color]")

func _on_turn_started(n: int, timeline: Array, enemy_action: String) -> void:
	_status_lbl.text = "Turn %d" % n
	var order := " → ".join(timeline.map(func(u: BattleUnit) -> String: return u.unit_name))
	_log("\n[color=#cccccc][Turn %d][/color]  %s" % [n, order])
	if enemy_action != "":
		_log("[color=#ffaa44]  敵: %s[/color]" % enemy_action)

func _on_action_announced(action_name: String) -> void:
	_log("[color=#ffaa44]敵の行動: %s[/color]" % action_name)
	# ターンが完了したのでボタンを有効化（次のターンの選択を受け付ける）
	if not _manager.is_over:
		_rotate_btn.disabled = false
		_stay_btn.disabled = false

func _on_unit_acted(attacker: BattleUnit, target: BattleUnit, dmg: int, is_crit: bool) -> void:
	var crit_tag := " [color=#ffdd00][CRIT][/color]" if is_crit else ""
	_log("  %s → [color=#ffcc44]%s[/color]: [b]%d[/b]%s  (%d/%d)" % [
		attacker.unit_name, target.unit_name, dmg, crit_tag, target.hp, target.hp_max])
	_update_card(target)

func _on_unit_petrified(unit: BattleUnit) -> void:
	_log("  [color=#aa88ff]%s 石化[/color]" % unit.unit_name)
	_update_card(unit)

func _on_unit_stone_cleared(unit: BattleUnit) -> void:
	_log("  [color=#ccaaff]%s 石化解除[/color]" % unit.unit_name)
	_update_card(unit)

func _on_unit_died(unit: BattleUnit) -> void:
	_log("[color=#ff5555]  ✦ %s 戦死[/color]" % unit.unit_name)
	_update_card(unit)

func _on_unit_healed(unit: BattleUnit, amount: int) -> void:
	_log("  [color=#55ff99]%s 回復: +%d (%d/%d)[/color]" % [unit.unit_name, amount, unit.hp, unit.hp_max])
	_update_card(unit)

func _on_rotated() -> void:
	_log("[color=#445566]  ── ローテーション ──[/color]")
	_rebuild_positions()

func _on_battle_ended(won: bool, _loot: Array) -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled = true
	if won:
		_status_lbl.text = "勝利！"
		_log("\n[color=#ffff55][b]=== 勝利！ ===[/b][/color]")
	else:
		_status_lbl.text = "撤退..."
		_log("\n[color=#ff4444][b]=== 撤退... ===[/b][/color]")

func _on_rotate_pressed() -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled = true
	_manager.advance_turn(true)

func _on_stay_pressed() -> void:
	_rotate_btn.disabled = true
	_stay_btn.disabled = true
	_manager.advance_turn(false)

func _log(text: String) -> void:
	_log_lbl.append_text(text + "\n")

# ════════════════════════════════ ヘルパー ════════════════════════════════════

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
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.start_battle(_make_party(), _make_enemies())

func _make_party() -> Array:
	# 前列（3人）
	var warrior := CharacterData.new()
	warrior.char_name = "アーサー"; warrior.job = CharacterJob.Type.WARRIOR
	warrior.hp_max = 35; warrior.attack = 20; warrior.speed = 15

	var samurai := CharacterData.new()
	samurai.char_name = "ライン"; samurai.job = CharacterJob.Type.SAMURAI
	samurai.hp_max = 28; samurai.attack = 24; samurai.speed = 28

	var archer := CharacterData.new()
	archer.char_name = "ルカ"; archer.job = CharacterJob.Type.ARCHER
	archer.hp_max = 24; archer.attack = 16; archer.speed = 12
	archer.indirect_attack = 12

	# 中列（3人）
	var knight := CharacterData.new()
	knight.char_name = "ガイ"; knight.job = CharacterJob.Type.KNIGHT
	knight.hp_max = 30; knight.attack = 12; knight.speed = 8
	knight.def_bonus = 12; knight.self_regen = 8

	var witch := CharacterData.new()
	witch.char_name = "リム"; witch.job = CharacterJob.Type.WITCH
	witch.hp_max = 22; witch.attack = 10; witch.speed = 16
	witch.atk_bonus = 14

	var mage := CharacterData.new()
	mage.char_name = "ソレン"; mage.job = CharacterJob.Type.MAGE
	mage.hp_max = 20; mage.attack = 8; mage.speed = 5
	mage.atk_bonus = 20; mage.def_bonus = 15; mage.row_regen = 10

	# 後列（1人）
	var cleric := CharacterData.new()
	cleric.char_name = "エレナ"; cleric.job = CharacterJob.Type.CLERIC
	cleric.hp_max = 18; cleric.attack = 8; cleric.speed = 6
	cleric.def_bonus = 20; cleric.row_regen = 15

	return [warrior, samurai, archer, knight, witch, mage, cleric]

func _make_enemies() -> Array:
	return [EnemyGenerator.generate(EnemyData.StatType.TANK)]
