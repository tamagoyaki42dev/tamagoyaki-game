class_name BattleUI
extends Control

const PANEL_W      := 420.0
const LOG_SPLIT    := 0.55
const PORTRAIT_W   := 56.0

const HP_YELLOW_THRESHOLD := 0.5
const HP_RED_THRESHOLD    := 0.25
const HP_COLOR_GREEN  := Color(0.15, 0.80, 0.30)
const HP_COLOR_YELLOW := Color(0.90, 0.78, 0.05)
const HP_COLOR_RED    := Color(0.85, 0.18, 0.10)

var _font: Font = null
var _manager: BattleManager = null
var _enemy_data: EnemyData = null
var _enemy_slot: int = 0

var _turn_lbl: Label
var _phase_lbl: Label
var _log: RichTextLabel
var _rotate_btn: Button
var _stay_btn: Button
var _action_panel: Control = null

var _party_bars: Dictionary = {}    # BattleUnit → ProgressBar
var _bar_fills: Dictionary = {}    # BattleUnit → StyleBoxFlat
var _party_entries: Dictionary = {} # BattleUnit → Panel

@export var countdown_seconds: float = 3.0
var _countdown_time: float = -1.0
var _countdown_lbl: Label
var _pending_rotate: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var jp := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"
	var en := "res://assets/fonts/Cinzel-Regular.ttf"
	if ResourceLoader.exists(jp):
		var jf := load(jp) as FontFile
		if ResourceLoader.exists(en):
			jf.set_fallbacks([load(en)])
		_font = jf

func _process(delta: float) -> void:
	if _countdown_time < 0.0:
		return
	_countdown_time -= delta
	_countdown_lbl.text = str(ceili(_countdown_time)) if _countdown_time > 0.0 else ""
	if _countdown_time <= 0.0:
		_countdown_time = -1.0
		_execute_pending_action()

func _start_selection_phase() -> void:
	_pending_rotate = false
	_rotate_btn.disabled = false
	_stay_btn.disabled = false
	_countdown_time = countdown_seconds
	_phase_lbl.text = "Stay..."
	_update_selection_visual()

func _execute_pending_action() -> void:
	if not _manager or _manager.is_over or _rotate_btn.disabled:
		return
	_countdown_lbl.text = ""
	_rotate_btn.disabled = true
	_stay_btn.disabled = true
	_phase_lbl.text = "Rotate..." if _pending_rotate else "Stay..."
	_manager.advance_turn(_pending_rotate)

func _update_selection_visual() -> void:
	var rot_a := 1.0 if _pending_rotate else 0.38
	var stay_a := 0.38 if _pending_rotate else 1.0
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.55, 0.28, 0.03, rot_a)
	rs.set_corner_radius_all(9)
	_rotate_btn.add_theme_stylebox_override("normal", rs)
	_rotate_btn.add_theme_stylebox_override("hover", rs)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.03, 0.36, 0.40, stay_a)
	ss.set_corner_radius_all(9)
	_stay_btn.add_theme_stylebox_override("normal", ss)
	_stay_btn.add_theme_stylebox_override("hover", ss)

func setup(manager: BattleManager) -> void:
	_manager = manager
	_manager.battle_started.connect(_on_battle_started)
	_manager.turn_started.connect(_on_turn_started)
	_manager.action_announced.connect(_on_action_announced)
	_manager.unit_acted.connect(_on_unit_acted)
	_manager.unit_died.connect(_on_unit_died)
	_manager.unit_healed.connect(_on_unit_healed)
	_manager.unit_petrified.connect(_on_unit_petrified)
	_manager.unit_stone_cleared.connect(_on_unit_stone_cleared)
	_manager.attack_support_used.connect(_on_atk_support)
	_manager.defense_support_used.connect(_on_def_support)
	_manager.battle_ended.connect(_on_battle_ended)
	_build_ui()

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var sw := vp.x
	var sh := vp.y
	var px := sw - PANEL_W

	var bg := Panel.new()
	bg.position = Vector2(px, 0.0)
	bg.size = Vector2(PANEL_W, sh)
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color = Color(0.03, 0.04, 0.09, 0.92)
	bg_sty.border_color = Color(0.25, 0.55, 1.0, 0.5)
	bg_sty.set_border_width_all(1)
	bg.add_theme_stylebox_override("panel", bg_sty)
	add_child(bg)

	_turn_lbl = _lbl(self, "Turn 0", Vector2(16.0, 16.0), 22, Color(0.88, 0.78, 0.30))

	_phase_lbl = _lbl(self, "", Vector2(sw * 0.35 - 100.0, sh * 0.82), 26, Color(0.88, 0.78, 0.30))
	_phase_lbl.size = Vector2(200.0, 40.0)
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl = _lbl(self, "", Vector2(sw * 0.35 - 45.0, sh * 0.72), 64, Color(1.0, 0.85, 0.2))

	var cx := sw * 0.35
	var btn_y := sh * 0.90
	_rotate_btn = _build_btn("ローテーション", Vector2(cx - 250.0, btn_y),
		Vector2(230.0, 70.0), Color(0.55, 0.28, 0.03), _on_rotate_pressed)
	_stay_btn = _build_btn("ステイ", Vector2(cx + 20.0, btn_y),
		Vector2(200.0, 70.0), Color(0.03, 0.36, 0.40), _on_stay_pressed)
	_rotate_btn.disabled = true
	_stay_btn.disabled = true

	var log_y := sh * LOG_SPLIT + 16.0
	_log = RichTextLabel.new()
	_log.position = Vector2(px + 8.0, log_y)
	_log.size = Vector2(PANEL_W - 16.0, sh - log_y - 8.0)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 15)
	if _font:
		_log.add_theme_font_override("normal_font", _font)
	add_child(_log)

func _build_party_panel(units: Array) -> void:
	var vp := get_viewport().get_visible_rect().size
	var sh := vp.y
	var px := vp.x - PANEL_W
	var slot_h := (sh * LOG_SPLIT) / float(units.size())

	for i: int in units.size():
		var unit: BattleUnit = units[i]
		var ey := 8.0 + i * slot_h

		var entry := Panel.new()
		entry.position = Vector2(px + 4.0, ey)
		entry.size = Vector2(PANEL_W - 8.0, slot_h - 4.0)
		var es := StyleBoxFlat.new()
		es.bg_color = Color(0.08, 0.10, 0.18, 0.55)
		es.set_corner_radius_all(4)
		entry.add_theme_stylebox_override("panel", es)
		add_child(entry)
		_party_entries[unit] = entry

		var portrait := ColorRect.new()
		portrait.position = Vector2(4.0, 4.0)
		portrait.size = Vector2(PORTRAIT_W, slot_h - 12.0)
		portrait.color = Color(0.10, 0.12, 0.22, 0.85)
		entry.add_child(portrait)

		var content_x := PORTRAIT_W + 8.0
		_lbl(entry, unit.unit_name, Vector2(content_x, 6.0), 17, Color(0.86, 0.90, 0.98))
		_lbl(entry, "ATK %d  SPD %d" % [unit.attack, unit.speed],
			Vector2(content_x, 26.0), 13, Color(0.58, 0.65, 0.80))

		var bar := ProgressBar.new()
		bar.position = Vector2(content_x, 46.0)
		bar.size = Vector2(PANEL_W - 24.0 - PORTRAIT_W, 10.0)
		bar.min_value = 0.0
		bar.max_value = float(unit.hp_max)
		bar.value = float(unit.hp)
		bar.show_percentage = false
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = HP_COLOR_GREEN
		bar_fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", bar_fill)
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.04, 0.12, 0.04, 0.9)
		bar_bg.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bar_bg)
		entry.add_child(bar)
		_party_bars[unit] = bar
		_bar_fills[unit] = bar_fill

func _build_btn(text: String, pos: Vector2, sz: Vector2,
		color: Color, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.add_theme_font_size_override("font_size", 20)
	if _font:
		btn.add_theme_font_override("font", _font)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(color.r, color.g, color.b, 0.85)
	sty.set_corner_radius_all(9)
	var dis := StyleBoxFlat.new()
	dis.bg_color = Color(0.05, 0.05, 0.08, 0.5)
	dis.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("normal",   sty)
	btn.add_theme_stylebox_override("hover",    sty)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.pressed.connect(cb)
	add_child(btn)
	return btn

func _update_hp(unit: BattleUnit) -> void:
	if not _party_bars.has(unit):
		return
	var bar := _party_bars[unit] as ProgressBar
	bar.value = float(unit.hp)
	var fill := _bar_fills.get(unit) as StyleBoxFlat
	if fill:
		fill.bg_color = _get_hp_color(clampf(float(unit.hp) / float(unit.hp_max), 0.0, 1.0))

func _get_hp_color(pct: float) -> Color:
	if pct < HP_RED_THRESHOLD:
		return HP_COLOR_RED
	if pct < HP_YELLOW_THRESHOLD:
		return HP_COLOR_YELLOW
	return HP_COLOR_GREEN

func _log_add(text: String) -> void:
	_log.append_text(text + "\n")

func _lbl(parent: Node, text: String, pos: Vector2,
		sz: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	if _font:
		l.add_theme_font_override("font", _font)
	parent.add_child(l)
	return l

# ── Signal handlers ──────────────────────────────────────────────

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	_build_party_panel(pg.get_all_alive())
	for unit: BattleUnit in eg.get_all_alive():
		if unit.source_data is EnemyData:
			_enemy_data = unit.source_data as EnemyData
	_build_enemy_action_panel()
	_log_add("[color=#888888]=== バトル開始 ===[/color]")

func _on_turn_started(n: int, timeline: Array, _enemy_action: String) -> void:
	_turn_lbl.text = "Turn %d" % n
	_phase_lbl.text = "Battle!"
	var order: String = " → ".join((timeline as Array).map(
		func(u: BattleUnit) -> String: return u.unit_name))
	_log_add("\n[color=#cccccc][Turn %d][/color]  %s" % [n, order])

func _on_action_announced(_action: String) -> void:
	if _enemy_data and not _enemy_data.action_cycle.is_empty():
		_enemy_slot = (_enemy_slot + 1) % _enemy_data.action_cycle.size()
		_build_enemy_action_panel()
	_phase_lbl.text = "Choose..."
	if _manager and not _manager.is_over:
		_start_selection_phase()

func _on_unit_acted(attacker: BattleUnit, target: BattleUnit,
		dmg: int, is_crit: bool) -> void:
	_log_add("  %s → [color=#ffcc44]%s[/color]: [b]%d[/b]%s" % [
		attacker.unit_name, target.unit_name, dmg, " ★" if is_crit else ""])
	_update_hp(target)

func _on_unit_died(unit: BattleUnit) -> void:
	_log_add("[color=#ff5555]  ✦ %s 戦死[/color]" % unit.unit_name)
	if _party_entries.has(unit):
		var entry := _party_entries[unit] as Panel
		var dead_sty := StyleBoxFlat.new()
		dead_sty.bg_color = Color(0.10, 0.10, 0.10, 0.55)
		dead_sty.set_corner_radius_all(4)
		entry.add_theme_stylebox_override("panel", dead_sty)
	if _bar_fills.has(unit):
		(_bar_fills[unit] as StyleBoxFlat).bg_color = Color(0.30, 0.30, 0.30)

func _on_unit_healed(unit: BattleUnit, amount: int) -> void:
	_log_add("  [color=#55ff99]%s %s[/color]" % [
		unit.unit_name, "回復（MAX）" if amount <= 0 else "+%d" % amount])
	_update_hp(unit)

func _on_unit_petrified(unit: BattleUnit) -> void:
	_log_add("  [color=#aa88ff]%s 石化[/color]" % unit.unit_name)

func _on_unit_stone_cleared(unit: BattleUnit) -> void:
	_log_add("  [color=#ccaaff]%s 石化解除[/color]" % unit.unit_name)

func _on_atk_support(supporter: BattleUnit, _attacker: BattleUnit) -> void:
	_log_add("  [color=#ff8833]%s 攻撃補助[/color]" % supporter.unit_name)

func _on_def_support(supporter: BattleUnit, target: BattleUnit) -> void:
	_log_add("  [color=#4488ff]%s 守護 → %s[/color]" % [supporter.unit_name, target.unit_name])

func _on_battle_ended(won: bool, _loot: Array) -> void:
	_countdown_time = -1.0
	_countdown_lbl.text = ""
	_pending_rotate = false
	_rotate_btn.disabled = true
	_stay_btn.disabled   = true
	_phase_lbl.text = "Victory!" if won else "Retreat..."
	_log_add("\n[b]%s[/b]" % ("=== 勝利！ ===" if won else "=== 撤退... ==="))

func _on_rotate_pressed() -> void:
	_pending_rotate = true
	_phase_lbl.text = "Rotate..."
	_update_selection_visual()

func _on_stay_pressed() -> void:
	_pending_rotate = false
	_phase_lbl.text = "Stay..."
	_update_selection_visual()

func _build_enemy_action_panel() -> void:
	if _action_panel and is_instance_valid(_action_panel):
		_action_panel.queue_free()
	if not _enemy_data or _enemy_data.action_cycle.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	var cycle: Array = _enemy_data.action_cycle
	var px := vp.x * 0.60
	var py := 100.0
	var pw := 260.0
	var sh := 40.0
	var ph := 44.0 + cycle.size() * sh + 8.0

	_action_panel = Control.new()
	add_child(_action_panel)

	var bg := Panel.new()
	bg.position = Vector2(px, py)
	bg.size = Vector2(pw, ph)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.09, 0.04, 0.04, 0.92)
	sty.border_color = Color(0.55, 0.18, 0.18, 0.70)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(5)
	bg.add_theme_stylebox_override("panel", sty)
	_action_panel.add_child(bg)

	_lbl(_action_panel, _enemy_data.get_stat_type_name(),
		Vector2(px + 8.0, py + 6.0), 16, Color(0.92, 0.55, 0.55))

	var slot := _enemy_slot % cycle.size()
	for i: int in cycle.size():
		var sy := py + 44.0 + i * sh
		var is_now := (i == slot)
		var txt := ("▶ " if is_now else "   ") + \
			"%d. %s" % [i + 1, EnemyData.get_action_label(cycle[i])]
		_lbl(_action_panel, txt, Vector2(px + 8.0, sy + 8.0),
			16 if is_now else 14,
			Color(1.0, 0.65, 0.65) if is_now else Color(0.68, 0.55, 0.55))
