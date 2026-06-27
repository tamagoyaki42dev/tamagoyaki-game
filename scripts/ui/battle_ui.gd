class_name BattleUI
extends Control

const PANEL_W      := 420.0
const LOG_SPLIT    := 0.55
const PORTRAIT_W   := 56.0
const STAT_FONT_SIZE   := 12
const NAME_FONT_SIZE   := 16
const JOB_FONT_SIZE    := 12
const HP_FONT_SIZE     := 13
const HP_ROW_Y         := 27.0
const BAR_Y            := 48.0
const STAT_X_OFFSET    := 86.0   # HP数値の右に攻/速/持ちを横並びにするための x オフセット


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
var _party_portraits: Dictionary = {} # BattleUnit → TextureRect
var _party_job_lbls: Dictionary = {}  # BattleUnit → Label（番号＋職名）
var _party_hp_lbls: Dictionary = {}   # BattleUnit → Label（HP数値 現在/最大）
var _party_stat_lbls: Dictionary = {}  # BattleUnit → Label（攻ライン）

@export_range(1.0, 10.0, 0.5) var countdown_seconds: float = 3.0

# UIレイアウト（_ratio 系は画面幅・高さに対する比率）
@export_range(0.0, 1.0, 0.01) var ui_center_x_ratio: float    = 0.62
@export_range(0.0, 1.0, 0.01) var btn_y_ratio: float          = 0.80
@export var rotate_btn_size: Vector2                           = Vector2(280.0, 85.0)
@export var stay_btn_size: Vector2                             = Vector2(240.0, 85.0)
@export_range(0.0, 1.0, 0.01) var countdown_y_ratio: float    = 0.65
@export_range(12, 120, 2)     var countdown_font_size: int    = 72
@export_range(0.0, 1.0, 0.01) var phase_lbl_y_ratio: float    = 0.70
@export_range(12, 80, 1)      var phase_font_size: int        = 44
@export_range(0.0, 1.0, 0.01) var action_panel_x_ratio: float  = 0.60
@export_range(0.0, 400.0, 1.0) var action_panel_y: float       = 80.0
@export_range(100.0, 800.0, 5.0) var action_panel_w: float     = 360.0
@export_range(10, 40, 1) var action_panel_title_font_size: int = 22
@export_range(10, 36, 1) var action_panel_item_font_size: int  = 18
@export_range(20.0, 80.0, 2.0) var action_panel_row_h: float   = 52.0

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

	var cx := sw * ui_center_x_ratio
	var btn_y := sh * btn_y_ratio
	_phase_lbl = _lbl(self, "", Vector2(cx - 100.0, sh * phase_lbl_y_ratio), phase_font_size, Color(0.88, 0.78, 0.30))
	_phase_lbl.size = Vector2(200.0, 40.0)
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl = _lbl(self, "", Vector2(cx - 45.0, sh * countdown_y_ratio), countdown_font_size, Color(1.0, 0.85, 0.2))

	_rotate_btn = _build_btn("ローテーション", Vector2(cx - rotate_btn_size.x - 20.0, btn_y),
		rotate_btn_size, Color(0.55, 0.28, 0.03), _on_rotate_pressed)
	_stay_btn = _build_btn("ステイ", Vector2(cx + 20.0, btn_y),
		stay_btn_size, Color(0.03, 0.36, 0.40), _on_stay_pressed)
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
		entry.clip_contents = true
		add_child(entry)
		_party_entries[unit] = entry

		var strip := ColorRect.new()
		strip.position = Vector2(0.0, 0.0)
		strip.size = Vector2(5.0, slot_h - 4.0)
		strip.color = BattleScene.accent_color_for(i)
		entry.add_child(strip)

		# 正面ポートレート（事前ベイク PNG）。共有モデルの色分けは戦場と同じ tint を modulate で一致させる
		var portrait := TextureRect.new()
		portrait.position = Vector2(4.0, 4.0)
		portrait.size = Vector2(PORTRAIT_W, slot_h - 12.0)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var cd := unit.source_data as CharacterData
		if cd:
			var ppath := BattleScene.portrait_path_for_job(cd.job)
			if ResourceLoader.exists(ppath):
				portrait.texture = load(ppath) as Texture2D
			portrait.modulate = BattleScene.job_tint_or_white(cd.job)
		entry.add_child(portrait)
		_party_portraits[unit] = portrait

		var content_x := PORTRAIT_W + 8.0
		# 1行目：名前（番号付き・左）＋職種。職種は名前の直後（2スペースぶんの間隔）に続ける。
		# 浮いた1行ぶんで HP・ステータスのフォントを大きくして可読性を上げる。
		var name_text := "%d  %s  " % [i + 1, unit.unit_name]
		_lbl(entry, name_text.strip_edges(true, false),
			Vector2(content_x, 2.0), NAME_FONT_SIZE, Color(0.86, 0.90, 0.98))
		var name_w := float(name_text.length()) * NAME_FONT_SIZE * 0.6
		if _font:
			name_w = _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
		var job_name: String = CharacterJob.get_display_name(cd.job) if cd else unit.unit_name
		var job_lbl := _lbl(entry, job_name,
			Vector2(content_x + name_w, 6.0), JOB_FONT_SIZE, Color(0.66, 0.74, 0.90))
		_party_job_lbls[unit] = job_lbl

		# 2行目：HP数値＋その右にステータス（攻/速/持ち）を横並び（バーの縦帯に被らせない）
		var hp_lbl := _lbl(entry, "HP %d/%d" % [unit.hp, unit.hp_max],
			Vector2(content_x, HP_ROW_Y), HP_FONT_SIZE, Color(0.80, 0.88, 0.80))
		_party_hp_lbls[unit] = hp_lbl

		var stat_text: String = _build_atk_text(unit) + "  速 %d" % unit.speed
		var items_text: String = _build_stat_items_text(unit)
		if not items_text.is_empty():
			stat_text += "  " + items_text
		var stat_lbl := _lbl(entry, stat_text,
			Vector2(content_x + STAT_X_OFFSET, HP_ROW_Y), STAT_FONT_SIZE, Color(0.72, 0.80, 0.90))
		_party_stat_lbls[unit] = stat_lbl

		var bar := ProgressBar.new()
		bar.position = Vector2(content_x, BAR_Y)
		bar.size = Vector2(PANEL_W - 24.0 - PORTRAIT_W, 5.0)
		bar.min_value = 0.0
		bar.max_value = float(unit.hp_max)
		bar.value = float(unit.hp)
		bar.show_percentage = false
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = BattleScene.HP_COLOR_GREEN
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
	if _party_hp_lbls.has(unit):
		(_party_hp_lbls[unit] as Label).text = "HP %d/%d" % [unit.hp, unit.hp_max]

func _get_hp_color(pct: float) -> Color:
	if pct < BattleScene.HP_RED_THRESHOLD:
		return BattleScene.HP_COLOR_RED
	if pct < BattleScene.HP_YELLOW_THRESHOLD:
		return BattleScene.HP_COLOR_YELLOW
	return BattleScene.HP_COLOR_GREEN

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

static func _build_atk_text(unit: BattleUnit) -> String:
	var s: String = "攻 %d" % unit.attack
	if unit.attack_hits > 1:
		s += "×%d" % unit.attack_hits
	if unit.is_stone_attack:
		s += " 石"
	return s

static func _build_stat_items_text(unit: BattleUnit) -> String:
	var parts: Array[String] = []
	if unit.indirect_attack > 0:
		parts.append("間 %d" % unit.indirect_attack)
	if unit.atk_bonus > 0:
		if unit.atk_bonus_is_row:
			parts.append("攻補列 %d" % unit.atk_bonus)
		else:
			parts.append("攻補 %d" % unit.atk_bonus)
	if unit.def_bonus > 0:
		parts.append("防補 %d" % unit.def_bonus)
	if unit.self_regen > 0:
		parts.append("自 %d" % unit.self_regen)
	if unit.row_regen > 0:
		parts.append("列 %d" % unit.row_regen)
	return "  ".join(parts)

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
	var px := vp.x * action_panel_x_ratio
	var py := action_panel_y
	var pw := action_panel_w
	var sh := action_panel_row_h
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
		Vector2(px + 8.0, py + 6.0), action_panel_title_font_size, Color(0.92, 0.55, 0.55))

	var slot := _enemy_slot % cycle.size()
	for i: int in cycle.size():
		var sy := py + 44.0 + i * sh
		var is_now := (i == slot)
		var txt := ("▶ " if is_now else "   ") + \
			"%d. %s" % [i + 1, EnemyData.get_action_label(cycle[i])]
		_lbl(_action_panel, txt, Vector2(px + 8.0, sy + 8.0),
			action_panel_title_font_size if is_now else action_panel_item_font_size,
			Color(1.0, 0.65, 0.65) if is_now else Color(0.68, 0.55, 0.55))
