## バトル画面 — コードだけで組んだUI（.tscn不要）
## scenes/node.tscn の Node にアタッチして F5 で動く
extends Node

# ── レイアウト（_readyで実際のビューポートサイズから計算）────────────────────
const CARD_W   := 160.0
const CARD_H   := 82.0
const CARD_GAP := 12.0
const ROW_GAP  := 16.0

var SW: float
var SH: float
var GRID_X: float
var ENEMY_Y0: float
var PLAYER_Y0: float
var LOG_X: float

# ── ノード参照 ────────────────────────────────────────────────────────────────
var _root: Control
var _log_lbl: RichTextLabel
var _turn_btn: Button
var _status_lbl: Label
var _manager: BattleManager
var _cards: Dictionary = {}   # BattleUnit → {ctrl, hp_bar, hp_lbl}

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	SW       = vp.x
	SH       = vp.y
	GRID_X   = SW * 0.22
	ENEMY_Y0 = SH * 0.07
	PLAYER_Y0 = SH * 0.55
	LOG_X    = SW * 0.70
	_build_ui()
	_start_battle()

# ══════════════════════════════════ UI構築 ════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 背景
	_crect(_root, Vector2.ZERO, Vector2(SW, SH), Color(0.07, 0.08, 0.12))

	# 縦分割ライン（バトルエリア / ログ）
	_crect(_root, Vector2(LOG_X - 8, 0), Vector2(2, SH), Color(0.25, 0.25, 0.35))

	# 横分割ライン（敵エリア / 味方エリア）
	_crect(_root, Vector2(0, SH * 0.5), Vector2(LOG_X - 10, 2), Color(0.3, 0.3, 0.4, 0.4))

	# セクションヘッダ
	_lbl(_root, "[ 敵 ]",  Vector2(40, ENEMY_Y0), 20, Color(1.0, 0.45, 0.45))
	_lbl(_root, "[ 味方 ]", Vector2(40, PLAYER_Y0 - 30), 20, Color(0.45, 0.75, 1.0))

	# 行ラベル（敵：後→前、味方：前→後）
	for i in 3:
		var ey := ENEMY_Y0 + (i * (CARD_H + ROW_GAP)) + 26
		var py := PLAYER_Y0 + (i * (CARD_H + ROW_GAP)) + 26
		_lbl(_root, ["後","中","前"][i], Vector2(340, ey), 15, Color(0.55, 0.55, 0.55))
		_lbl(_root, ["前","中","後"][i], Vector2(340, py), 15, Color(0.55, 0.55, 0.55))

	# ターン数表示
	_status_lbl = _lbl(_root, "Turn 0", Vector2(LOG_X * 0.5 - 60, SH * 0.5 - 46), 22)

	# 次のターンボタン
	_turn_btn = Button.new()
	_turn_btn.text = "次のターン →"
	_turn_btn.position = Vector2(LOG_X * 0.5 - 90, SH * 0.5 - 12)
	_turn_btn.size = Vector2(180, 46)
	_turn_btn.add_theme_font_size_override("font_size", 18)
	_turn_btn.pressed.connect(_on_turn_pressed)
	_root.add_child(_turn_btn)

	# バトルログ
	_log_lbl = RichTextLabel.new()
	_log_lbl.position = Vector2(LOG_X, 16)
	_log_lbl.size = Vector2(SW - LOG_X - 16, SH - 32)
	_log_lbl.bbcode_enabled = true
	_log_lbl.scroll_following = true
	_root.add_child(_log_lbl)

# ══════════════════════════════ ユニットカード ════════════════════════════════

func _build_cards(pg: RotationGrid, eg: RotationGrid) -> void:
	for unit in pg.get_all_alive() + eg.get_all_alive():
		var is_enemy: bool = unit.side == BattleUnit.Side.ENEMY
		var ctrl := Control.new()
		ctrl.position = _card_pos(unit)
		ctrl.size = Vector2(CARD_W, CARD_H)
		_root.add_child(ctrl)

		# 背景
		_crect(ctrl, Vector2.ZERO, Vector2(CARD_W, CARD_H),
			Color(0.18, 0.10, 0.10) if is_enemy else Color(0.09, 0.12, 0.22))

		# 枠線（1px）
		for d in [Vector2(0,0),Vector2(CARD_W-1,0),Vector2(0,CARD_H-1),Vector2(CARD_W-1,CARD_H-1)]:
			pass  # 今は省略

		# 名前
		_lbl(ctrl, unit.unit_name, Vector2(6, 5), 15)

		# HPバー背景
		_crect(ctrl, Vector2(6, 34), Vector2(CARD_W - 12, 11), Color(0.18, 0.18, 0.18))

		# HPバー本体
		var hp_bar := _crect(ctrl, Vector2(6, 34), Vector2(CARD_W - 12, 11), Color(0.2, 0.75, 0.3))

		# HPテキスト
		var hp_lbl := _lbl(ctrl, "%d/%d" % [unit.hp, unit.hp_max], Vector2(6, 50), 13)

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
		y = ENEMY_Y0 + (2 - unit.row) * (CARD_H + ROW_GAP)
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

func _on_turn_started(n: int, timeline: Array) -> void:
	_status_lbl.text = "Turn %d" % n
	var order := " → ".join(timeline.map(func(u: BattleUnit) -> String: return u.unit_name))
	_log("\n[color=#cccccc][Turn %d][/color]  %s" % [n, order])

func _on_unit_acted(attacker: BattleUnit, target: BattleUnit, dmg: int) -> void:
	_log("  %s → [color=#ffcc44]%s[/color]: [b]%d[/b]  (%d/%d)" % [
		attacker.unit_name, target.unit_name, dmg, target.hp, target.hp_max])
	_update_card(target)

func _on_unit_died(unit: BattleUnit) -> void:
	_log("[color=#ff5555]  ✦ %s 戦死[/color]" % unit.unit_name)
	_update_card(unit)

func _on_rotated() -> void:
	_log("[color=#445566]  ── ローテーション ──[/color]")
	_rebuild_positions()

func _on_battle_ended(won: bool, _loot: Array) -> void:
	_turn_btn.disabled = true
	if won:
		_status_lbl.text = "勝利！"
		_log("\n[color=#ffff55][b]=== 勝利！ ===[/b][/color]")
	else:
		_status_lbl.text = "全滅..."
		_log("\n[color=#ff4444][b]=== 全滅... ===[/b][/color]")

func _on_turn_pressed() -> void:
	_manager.advance_turn()

func _log(text: String) -> void:
	_log_lbl.append_text(text + "\n")

# ════════════════════════════════ ヘルパー ════════════════════════════════════

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
	_manager.unit_acted.connect(_on_unit_acted)
	_manager.unit_died.connect(_on_unit_died)
	_manager.rotated.connect(_on_rotated)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.start_battle(_make_party(), _make_enemies())

func _make_party() -> Array:
	var w := CharacterData.new()
	w.char_name = "アーサー"; w.job = CharacterJob.Type.WARRIOR
	w.hp_max = 120; w.attack = 15; w.defense = 8; w.speed = 8
	var c := CharacterData.new()
	c.char_name = "エレナ"; c.job = CharacterJob.Type.CLERIC
	c.hp_max = 80; c.attack = 6; c.defense = 5; c.speed = 7
	var s := CharacterData.new()
	s.char_name = "リム"; s.job = CharacterJob.Type.SCOUT
	s.hp_max = 70; s.attack = 12; s.defense = 3; s.speed = 14
	return [w, c, s]

func _make_enemies() -> Array:
	return [
		EnemyGenerator.generate(1),
		EnemyGenerator.generate(1),
		EnemyGenerator.generate(1, 0.5),
	]
