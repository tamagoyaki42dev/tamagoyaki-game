## 編成画面 — コードだけで組んだUI（.tscn不要）
## scenes/formation.tscn の Node にアタッチして起動
extends Node

const CARD_W   := 240.0
const CARD_H   := 130.0
const CARD_GAP := 14.0
const ROW_GAP  := 18.0
const BENCH_W  := 215.0
const BENCH_H  := 110.0
const GRID_Y   := 90.0

var GRID_X: float  # _ready() で左エリア中央に計算
const FONT_PATH := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"

var SW: float
var SH: float
var DIVIDER_X: float

var _root: Control
var _cards_root: Control   # グリッド＋ベンチカード（更新時に全差し替え）
var _detail_root: Control  # 右パネルコンテンツ（更新時に全差し替え）
var _selected: CharacterData = null
var _font: Font
var _preview_svp: SubViewport = null
var _preview_model: Node3D = null

func _ready() -> void:
	GameState.ensure_init()
	_font = load(FONT_PATH) as Font
	var vp := get_viewport().get_visible_rect().size
	SW = vp.x
	SH = vp.y
	DIVIDER_X = SW * 0.68
	GRID_X = (DIVIDER_X - (4.0 * (CARD_W + CARD_GAP) - CARD_GAP)) / 2.0
	_build_static_ui()
	_refresh()

# ══════════════════════════════════ 静的UI構築 ════════════════════════════════

func _build_static_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 背景
	_crect(_root, Vector2.ZERO, Vector2(SW, SH), Color(0.05, 0.06, 0.10))

	# 縦分割ライン
	_crect(_root, Vector2(DIVIDER_X, 0.0), Vector2(2.0, SH), Color(0.25, 0.55, 1.0, 0.5))

	# タイトル
	_lbl(_root, "編成", Vector2(GRID_X, 24.0), 28)

	# 行ラベル（前・中・後）
	for r in 3:
		var ry := GRID_Y + r * (CARD_H + ROW_GAP) + (CARD_H - 20.0) / 2.0
		_lbl(_root, ["前", "中", "後"][r], Vector2(GRID_X - 46.0, ry), 18, Color(0.55, 0.55, 0.65))

	# 列番号（1〜4）
	for c in 4:
		var cx := GRID_X + c * (CARD_W + CARD_GAP) + (CARD_W - 14.0) / 2.0
		_lbl(_root, str(c + 1), Vector2(cx, GRID_Y - 26.0), 13, Color(0.35, 0.35, 0.45))

	# ベンチ見出し
	var bench_lbl_y := GRID_Y + 3.0 * (CARD_H + ROW_GAP) + 14.0
	_lbl(_root, "ベンチ", Vector2(GRID_X, bench_lbl_y), 15, Color(0.55, 0.65, 0.75))

	# カード領域（_refresh()で毎回全差し替え）
	_cards_root = Control.new()
	_cards_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_cards_root)

	# 右パネル背景
	var px := DIVIDER_X + 24.0
	var pw := SW - DIVIDER_X - 40.0
	_panel(_root, Vector2(px, 24.0), Vector2(pw, SH - 48.0),
		Color(0.04, 0.05, 0.09, 0.88), Color(0.20, 0.30, 0.50))
	_lbl(_root, "キャラクター詳細", Vector2(px + 12.0, 34.0), 14, Color(0.40, 0.50, 0.65))
	_crect(_root, Vector2(px + 8.0, 56.0), Vector2(pw - 16.0, 1.0), Color(0.20, 0.30, 0.45))

	# 右パネル詳細コンテンツ領域
	_detail_root = Control.new()
	_detail_root.position = Vector2(px, 24.0)
	_detail_root.size = Vector2(pw, SH - 48.0)
	_root.add_child(_detail_root)

	_build_preview_viewport()
	_build_controls()

func _build_controls() -> void:
	var cy := SH - 70.0

	var info_btn := Button.new()
	info_btn.text = "← 敵情報"
	info_btn.position = Vector2(GRID_X, cy)
	info_btn.size = Vector2(140.0, 42.0)
	info_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/enemy_info.tscn"))
	_style_button(info_btn, Color(0.40, 0.50, 0.70))
	_root.add_child(info_btn)

	var start_btn := Button.new()
	start_btn.text = "遠征開始"
	start_btn.position = Vector2(DIVIDER_X - 220.0, cy)
	start_btn.size = Vector2(200.0, 42.0)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_on_start_pressed)
	_style_button(start_btn, Color(1.0, 0.55, 0.10))
	_root.add_child(start_btn)

# ══════════════════════════════════ カード更新 ════════════════════════════════

func _refresh() -> void:
	for child in _cards_root.get_children():
		child.queue_free()
	for child in _detail_root.get_children():
		child.queue_free()
	_build_grid_cards()
	_build_bench_cards()
	_build_detail_content()

func _build_grid_cards() -> void:
	for r in 3:
		for c in 4:
			var pos := Vector2i(r, c)
			var cd := GameState.get_at(pos)
			var px := GRID_X + c * (CARD_W + CARD_GAP)
			var py := GRID_Y + r * (CARD_H + ROW_GAP)
			_make_grid_card(pos, cd, Vector2(px, py))

func _make_grid_card(pos: Vector2i, cd: CharacterData, card_pos: Vector2) -> void:
	var is_sel := (cd != null and cd == _selected)
	var bg_col: Color
	var bdr_col: Color
	if cd == null:
		bg_col  = Color(0.04, 0.05, 0.08, 0.40)
		bdr_col = Color(0.18, 0.22, 0.32, 0.55)
	elif is_sel:
		bg_col  = Color(0.06, 0.14, 0.06, 0.95)
		bdr_col = Color(1.00, 0.90, 0.00)
	else:
		bg_col  = Color(0.04, 0.08, 0.18, 0.90)
		bdr_col = Color(0.25, 0.55, 0.95)

	var p := _panel(_cards_root, card_pos, Vector2(CARD_W, CARD_H), bg_col, bdr_col)

	if cd:
		_lbl(p, cd.char_name, Vector2(8.0, 4.0), 18)
		_lbl(p, CharacterJob.get_display_name(cd.job), Vector2(8.0, 28.0), 14, Color(0.65, 0.75, 1.00))
		_lbl(p, "HP%-3d ATK%-3d SPD%d" % [cd.hp_max, cd.attack, cd.speed],
			Vector2(8.0, 52.0), 13, Color(0.75, 0.80, 0.90))
		var supp := _support_str(cd)
		if supp != "":
			_lbl(p, supp, Vector2(8.0, 74.0), 12, Color(0.55, 0.85, 0.65))

	var btn := Button.new()
	btn.position = Vector2.ZERO
	btn.size = Vector2(CARD_W, CARD_H)
	btn.flat = true
	btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover",   _hover_box())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.pressed.connect(_on_grid_clicked.bind(pos))
	p.add_child(btn)

func _build_bench_cards() -> void:
	var bench_y := GRID_Y + 3.0 * (CARD_H + ROW_GAP) + 38.0
	var bench := GameState.get_bench_ordered()
	var grid_selected := _selected != null and GameState.is_in_formation(_selected)

	if bench.is_empty():
		if grid_selected:
			_make_bench_move_slot(_cards_root, Vector2(GRID_X, bench_y))
		else:
			_lbl(_cards_root, "（全員配置済み）",
				Vector2(GRID_X, bench_y + 20.0), 13, Color(0.35, 0.38, 0.45))
		return

	const BENCH_COLS := 4
	for i in bench.size():
		var cd: CharacterData = bench[i]
		var is_sel := (cd == _selected)
		var bg_col  := Color(0.10, 0.06, 0.16, 0.90) if is_sel else Color(0.08, 0.06, 0.12, 0.88)
		var bdr_col := Color(1.00, 0.90, 0.00) if is_sel else Color(0.45, 0.35, 0.65)
		var px := GRID_X + (i % BENCH_COLS) * (BENCH_W + CARD_GAP)
		var py := bench_y + (i / BENCH_COLS) * (BENCH_H + CARD_GAP)
		var p := _panel(_cards_root, Vector2(px, py), Vector2(BENCH_W, BENCH_H), bg_col, bdr_col)
		_lbl(p, cd.char_name, Vector2(8.0, 4.0), 16)
		_lbl(p, CharacterJob.get_display_name(cd.job), Vector2(8.0, 26.0), 13, Color(0.65, 0.75, 1.00))
		_lbl(p, "HP%d ATK%d SPD%d" % [cd.hp_max, cd.attack, cd.speed],
			Vector2(8.0, 48.0), 12, Color(0.70, 0.75, 0.85))
		var supp := _support_str(cd)
		if supp != "":
			_lbl(p, supp, Vector2(8.0, 68.0), 11, Color(0.55, 0.85, 0.65))
		var btn := Button.new()
		btn.position = Vector2.ZERO
		btn.size = Vector2(BENCH_W, BENCH_H)
		btn.flat = true
		btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover",   _hover_box())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
		btn.pressed.connect(_on_bench_clicked.bind(cd))
		p.add_child(btn)

	# グリッドキャラが選択されているとき次のセルに「ベンチへ移動」を表示
	if grid_selected:
		var n := bench.size()
		var px := GRID_X + (n % BENCH_COLS) * (BENCH_W + CARD_GAP)
		var py := bench_y + (n / BENCH_COLS) * (BENCH_H + CARD_GAP)
		_make_bench_move_slot(_cards_root, Vector2(px, py))

func _make_bench_move_slot(parent: Node, pos: Vector2) -> void:
	var p := _panel(parent, pos, Vector2(BENCH_W, BENCH_H),
		Color(0.08, 0.05, 0.14, 0.85), Color(0.55, 0.38, 0.75))
	_lbl(p, "ベンチへ移動", Vector2(8.0, 30.0), 13, Color(0.78, 0.65, 1.00))
	var btn := Button.new()
	btn.position = Vector2.ZERO
	btn.size = Vector2(BENCH_W, BENCH_H)
	btn.flat = true
	btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover",   _hover_box())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.pressed.connect(func():
		GameState.remove_from_grid(_selected)
		_selected = null
		_refresh())
	p.add_child(btn)

func _build_detail_content() -> void:
	_update_preview_model()
	var pw := SW - DIVIDER_X - 40.0
	if _selected == null:
		_lbl(_detail_root, "キャラクターを\n選択してください",
			Vector2(20.0, 660.0), 15, Color(0.38, 0.42, 0.52))
		return

	var cd := _selected
	var y := 652.0  # 3Dプレビュー(y=64,h=600)の下端+余白 - _detail_root offset(24)
	var lx := 20.0
	var vx := pw * 0.55

	_lbl(_detail_root, cd.char_name, Vector2(lx, y), 26)
	y += 42.0

	var gender := "女" if CharacterJob.is_female(cd.job) else "男"
	_lbl(_detail_root, "%s  %s" % [CharacterJob.get_display_name(cd.job), gender],
		Vector2(lx, y), 18, Color(0.65, 0.75, 1.00))
	y += 40.0

	_crect(_detail_root, Vector2(12.0, y), Vector2(pw - 24.0, 1.0), Color(0.22, 0.28, 0.42))
	y += 14.0

	var rows: Array = [
		["HP",    str(cd.hp_max)],
		["攻撃力", str(cd.attack)],
		["素早さ", str(cd.speed)],
	]
	if cd.indirect_attack > 0:
		rows.append(["間接攻撃", str(cd.indirect_attack)])
	if cd.atk_bonus > 0:
		rows.append(["攻補(%s)" % ("列" if cd.atk_bonus_is_row else "縦"), str(cd.atk_bonus)])
	if cd.def_bonus > 0:
		rows.append(["防御補助", str(cd.def_bonus)])
	if cd.self_regen > 0:
		rows.append(["自回復", str(cd.self_regen)])
	if cd.row_regen > 0:
		rows.append(["列回復", str(cd.row_regen)])

	for row: Array in rows:
		_lbl(_detail_root, row[0], Vector2(lx, y), 16, Color(0.60, 0.65, 0.75))
		_lbl(_detail_root, row[1], Vector2(vx, y), 16, Color(0.98, 0.92, 0.75))
		y += 30.0

	y += 8.0
	_crect(_detail_root, Vector2(12.0, y), Vector2(pw - 24.0, 1.0), Color(0.22, 0.28, 0.42))
	y += 14.0

	var crit_pct := int(CharacterJob.crit_rate(cd.job) * 100.0)
	_lbl(_detail_root, "クリティカル率", Vector2(lx, y), 15, Color(0.52, 0.57, 0.67))
	_lbl(_detail_root, "%d%%" % crit_pct, Vector2(vx, y), 15, Color(0.92, 0.82, 0.28))
	y += 28.0

	var hits := CharacterJob.attack_hits(cd.job)
	if hits > 1:
		_lbl(_detail_root, "攻撃回数", Vector2(lx, y), 15, Color(0.52, 0.57, 0.67))
		_lbl(_detail_root, "×%d" % hits, Vector2(vx, y), 15, Color(0.92, 0.82, 0.28))
		y += 28.0

	if CharacterJob.is_stone_attack(cd.job):
		_lbl(_detail_root, "特殊効果", Vector2(lx, y), 15, Color(0.52, 0.57, 0.67))
		_lbl(_detail_root, "石化攻撃", Vector2(vx, y), 15, Color(0.72, 0.58, 0.95))

func _support_str(cd: CharacterData) -> String:
	var parts: Array[String] = []
	if cd.atk_bonus > 0:
		parts.append("攻%d%s" % [cd.atk_bonus, "(列)" if cd.atk_bonus_is_row else ""])
	if cd.def_bonus > 0:
		parts.append("防%d" % cd.def_bonus)
	if cd.self_regen > 0:
		parts.append("自%d" % cd.self_regen)
	if cd.row_regen > 0:
		parts.append("列%d" % cd.row_regen)
	return "  ".join(parts)

# ══════════════════════════════════ クリック処理 ══════════════════════════════

func _on_grid_clicked(pos: Vector2i) -> void:
	var cd := GameState.get_at(pos)
	if _selected == null:
		_selected = cd
	elif _selected == cd:
		_selected = null
	else:
		var sel_pos := _selected_grid_pos()
		if sel_pos != Vector2i(-1, -1):
			# グリッド同士のスワップ
			GameState.swap(sel_pos, pos)
		else:
			# ベンチ→グリッド（既存がいれば押し出してベンチへ）
			GameState.place(pos, _selected)
		_selected = null
	_refresh()

func _on_bench_clicked(cd: CharacterData) -> void:
	if _selected == null:
		_selected = cd
	elif _selected == cd:
		_selected = null
	elif GameState.is_in_formation(_selected):
		# グリッドのキャラとベンチのキャラをスワップ
		var sel_pos := _selected_grid_pos()
		GameState.place(sel_pos, cd)
		_selected = null
	else:
		# ベンチ同士 → 選択し直し
		_selected = cd
	_refresh()

func _selected_grid_pos() -> Vector2i:
	for pos: Vector2i in GameState.formation:
		if GameState.formation[pos] == _selected:
			return pos
	return Vector2i(-1, -1)

func _on_start_pressed() -> void:
	if GameState.formation.is_empty():
		return
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

# ══════════════════════════════════ 3Dプレビュー ══════════════════════════════

func _build_preview_viewport() -> void:
	var px := DIVIDER_X + 24.0
	var pw := SW - DIVIDER_X - 40.0
	const PREVIEW_Y := 64.0
	const PREVIEW_H := 600.0
	var vp_w := int(pw - 8.0)
	var vp_h := int(PREVIEW_H)

	var container := SubViewportContainer.new()
	container.position = Vector2(px + 4.0, PREVIEW_Y)
	container.size = Vector2(vp_w, vp_h)
	_root.add_child(container)

	_preview_svp = SubViewport.new()
	_preview_svp.size = Vector2i(vp_w, vp_h)
	_preview_svp.transparent_bg = true
	_preview_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_preview_svp)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.75)
	env.ambient_light_energy = 0.6
	env_node.environment = env
	_preview_svp.add_child(env_node)

	var light := DirectionalLight3D.new()
	light.look_at_from_position(Vector3(3.0, 5.0, 4.0), Vector3.ZERO, Vector3.UP)
	light.light_energy = 1.2
	_preview_svp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.5
	cam.look_at_from_position(Vector3(0.0, 1.5, 5.0), Vector3(0.0, 0.75, 0.0), Vector3.UP)
	_preview_svp.add_child(cam)

func _update_preview_model() -> void:
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null

	if _selected == null or _preview_svp == null:
		return

	var path: String = BattleScene._JOB_CHAR_PATHS.get(_selected.job, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return

	var res := load(path) as PackedScene
	if not res:
		return

	_preview_model = res.instantiate() as Node3D
	_preview_svp.add_child(_preview_model)

	var tint: Color = BattleScene.job_tint_or_white(_selected.job)
	if tint != Color.WHITE:
		_tint_model(_preview_model, tint)

	var anim: AnimationPlayer = _preview_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")

func _tint_model(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i: int in range(mi.mesh.get_surface_count()):
				var base_mat: Material = mi.get_surface_override_material(i)
				if not base_mat:
					base_mat = mi.mesh.surface_get_material(i)
				if base_mat is StandardMaterial3D:
					var tinted := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					tinted.albedo_color = tint
					mi.set_surface_override_material(i, tinted)
	for child: Node in node.get_children():
		_tint_model(child, tint)

# ══════════════════════════════════ ヘルパー ══════════════════════════════════

func _hover_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1.0, 1.0, 1.0, 0.07)
	s.set_corner_radius_all(4)
	return s

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
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_color_override("font_color",          Color.WHITE)
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.40))

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
