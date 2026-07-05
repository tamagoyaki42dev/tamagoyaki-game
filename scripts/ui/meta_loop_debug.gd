extends Node

# 継承ループ（拠点⇔遠征⇔世代交代）の簡易シミュレーター（v0）。
# proto2_design.md「継承育成ループの機構定義」の骨組みだけを選択肢遷移で回す。
# 戦闘・結婚出産・親密度は未実装（数値は全部仮値・後で差し替え前提）。
# battle_scene.tscn とは無関係の独立シーン。F5(mainシーン)の戦闘デバッグ動線には触れない。
# 単体で試すときは Godot の F6（現在開いているシーンを再生）を使う。

enum _State { HOME, EXPEDITION_SELECT, RESULT, GAME_OVER }

const _TOWN_NAMES: Array[String] = ["近郊の町", "中間の町", "遠方の町"]

@export var initial_party_size: int = 4
@export var max_party: int = 7
@export var town_distance_days: Array[int] = [10, 20, 35]
@export var neglect_limit_days: int = 150
@export var revival_days: int = 100
@export var recruit_cost_days: int = 40
@export var wait_days: int = 30
@export var retirement_check_interval_days: int = 200

var _state: _State = _State.HOME
var _total_days: int = 0
var _party_size: int = 0
var _town_fallen: Array[bool] = []
var _town_days_since_defended: Array[int] = []
var _town_days_since_fallen: Array[int] = []
var _days_since_retirement_check: int = 0
var _log_text: String = ""

var _root: Control
var _status_lbl: Label
var _log_lbl: Label
var _choice_nodes: Array[Node] = []

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.10)
	_root.add_child(bg)

	var title := Label.new()
	title.text = "継承ループ 簡易シミュレーター（v0・数値は仮）"
	title.position = Vector2(660.0, 40.0)
	title.size = Vector2(600.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	_root.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.position = Vector2(120.0, 120.0)
	_status_lbl.size = Vector2(900.0, 260.0)
	_status_lbl.add_theme_font_size_override("font_size", 20)
	_status_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_root.add_child(_status_lbl)

	_log_lbl = Label.new()
	_log_lbl.position = Vector2(120.0, 400.0)
	_log_lbl.size = Vector2(1000.0, 100.0)
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_lbl.add_theme_font_size_override("font_size", 16)
	_log_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_root.add_child(_log_lbl)

	_restart()

func _restart() -> void:
	_total_days = 0
	_party_size = initial_party_size
	_town_fallen.clear()
	_town_days_since_defended.clear()
	_town_days_since_fallen.clear()
	for i in _TOWN_NAMES.size():
		_town_fallen.append(false)
		_town_days_since_defended.append(0)
		_town_days_since_fallen.append(0)
	_days_since_retirement_check = 0
	_log_text = "シミュレーション開始。"
	_state = _State.HOME
	_render()

func _render() -> void:
	var lines: Array[String] = []
	lines.append("経過日数：%d日（約%.1f年）" % [_total_days, _total_days / 360.0])
	lines.append("ロスター人数：%d / %d" % [_party_size, max_party])
	for i in _TOWN_NAMES.size():
		if _town_fallen[i]:
			var until_revival: int = maxi(0, revival_days - _town_days_since_fallen[i])
			lines.append("・%s：滅亡中（%d日経過・復活まで%d日）" % [_TOWN_NAMES[i], _town_days_since_fallen[i], until_revival])
		else:
			lines.append("・%s：健在（防衛から%d日／放置限界%d日・距離%d日）" % [_TOWN_NAMES[i], _town_days_since_defended[i], neglect_limit_days, town_distance_days[i]])
	_status_lbl.text = "\n".join(lines)
	_log_lbl.text = _log_text

	for n in _choice_nodes:
		n.queue_free()
	_choice_nodes.clear()

	match _state:
		_State.HOME:
			_render_home()
		_State.EXPEDITION_SELECT:
			_render_expedition_select()
		_State.RESULT:
			_choice_btn("拠点に戻る", 0, _go_home)
		_State.GAME_OVER:
			_status_lbl.text += "\n\n=== GAME OVER：町が同時に3つとも滅亡した ==="
			_choice_btn("最初からやり直す", 0, _restart)

func _render_home() -> void:
	var i := 0
	_choice_btn("遠征に出る", i, _go_expedition_select)
	i += 1
	if _party_size < max_party:
		_choice_btn("募集する（+1人・%d日）" % recruit_cost_days, i, _recruit)
		i += 1
	_choice_btn("何もせず時間を進める（%d日）" % wait_days, i, _wait)

func _render_expedition_select() -> void:
	var i := 0
	for t in _TOWN_NAMES.size():
		if _town_fallen[t]:
			continue
		var town_index := t
		_choice_btn("%s へ遠征（距離%d日）" % [_TOWN_NAMES[t], town_distance_days[t]], i, func(): _do_expedition(town_index))
		i += 1
	_choice_btn("やめて戻る", i, _go_home)

func _choice_btn(text: String, index: int, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = Vector2(120.0, 500.0 + index * 60.0)
	b.size = Vector2(460.0, 48.0)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(callback)
	_root.add_child(b)
	_choice_nodes.append(b)

func _go_home() -> void:
	_state = _State.HOME
	_render()

func _go_expedition_select() -> void:
	_state = _State.EXPEDITION_SELECT
	_render()

func _do_expedition(town_index: int) -> void:
	var days: int = town_distance_days[town_index]
	_advance_days(days)
	var win_chance: float = clampf(float(_party_size) / float(max_party), 0.1, 0.95)
	var won: bool = randf() < win_chance
	if won:
		_town_days_since_defended[town_index] = 0
		_log_text = "%s の防衛戦に勝利（勝率%d%%で抽選）。" % [_TOWN_NAMES[town_index], int(win_chance * 100.0)]
	else:
		_log_text = "%s の防衛戦に敗北（勝率%d%%で抽選）。仲間を1人失った。" % [_TOWN_NAMES[town_index], int(win_chance * 100.0)]
		_party_size = maxi(0, _party_size - 1)
		if randf() < 0.5:
			_town_fallen[town_index] = true
			_town_days_since_fallen[town_index] = 0
			_log_text += " %s は持ちこたえられず滅亡した。" % _TOWN_NAMES[town_index]
	_check_game_over()
	if _state != _State.GAME_OVER:
		_state = _State.RESULT
	_render()

func _recruit() -> void:
	_advance_days(recruit_cost_days)
	_party_size = mini(max_party, _party_size + 1)
	_log_text = "新規メンバーを1人勧誘した。"
	_render()

func _wait() -> void:
	_advance_days(wait_days)
	_log_text = "特に何もせず時間が過ぎた。"
	_render()

func _advance_days(days: int) -> void:
	_total_days += days
	_days_since_retirement_check += days
	for i in _TOWN_NAMES.size():
		if _town_fallen[i]:
			_town_days_since_fallen[i] += days
			if _town_days_since_fallen[i] >= revival_days:
				_town_fallen[i] = false
				_town_days_since_defended[i] = 0
				_log_text += "\n%s が復活した。" % _TOWN_NAMES[i]
		else:
			_town_days_since_defended[i] += days
			if _town_days_since_defended[i] >= neglect_limit_days:
				_town_fallen[i] = true
				_town_days_since_fallen[i] = 0
				_log_text += "\n%s は放置されて滅亡した。" % _TOWN_NAMES[i]
	if _days_since_retirement_check >= retirement_check_interval_days:
		_days_since_retirement_check = 0
		if _party_size > 0:
			_party_size -= 1
			_log_text += "\n加齢によりメンバーが1人引退した。"
	_check_game_over()

func _check_game_over() -> void:
	for f in _town_fallen:
		if not f:
			return
	_state = _State.GAME_OVER
