## アイソメトリック表示プレビュー
## scenes/iso_preview.tscn から F6 で単独起動して確認する
extends Node

const TILE_W  := 240.0
const TILE_H  := 120.0
const PANEL_X := 1500.0

const SP_W := 70.0    # プレイヤースプライト幅
const SP_H := 95.0    # プレイヤースプライト高
const EN_W := 220.0   # 敵スプライト幅
const EN_H := 260.0   # 敵スプライト高

var _root: Control
var SW: float
var SH: float
var _origin: Vector2

var _rot_btn: Button
var _stay_btn: Button
var _rot_sty_normal:   StyleBoxFlat
var _rot_sty_selected: StyleBoxFlat
var _stay_sty_normal:   StyleBoxFlat
var _stay_sty_selected: StyleBoxFlat
var _selected_action: int = 1  # 0=ローテーション, 1=ステイ（デフォルト）

var _timer: float = 0.0
var _timer_lbl: Label
var _turn: int = 4
var _turn_lbl: Label
var _enemy_hp_r: float = 0.65
var _enemy_body: ColorRect
var _enemy_hp_bar: ColorRect
var _enemy_bar_w: float
var _player_bodies: Array = []  # {body: ColorRect, center: Vector2}
var _arena_vp: SubViewport
var _log: RichTextLabel
var _enemy_cycle: Array = ["攻撃", "全体攻撃", "力を溜める", "×2連続"]
var _enemy_slot: int = 3
var _action_panel: Control
var _phase: int = 0       # 0=SELECT, 1=BATTLE, 2=HEAL
var _phase_timer: float = 0.0
var _font: Font = null

var _screenshot_mode: bool = false
var _screenshot_frames: int = 0

func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tools/screenshot.png")
	img.save_png(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tools/screenshot_trigger"))

func _ready() -> void:
	_screenshot_mode = "screenshot_mode" in OS.get_cmdline_args()
	var jp_path := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"
	var en_path := "res://assets/fonts/Cinzel-Regular.ttf"
	if ResourceLoader.exists(jp_path):
		var jp_font := load(jp_path) as FontFile
		if ResourceLoader.exists(en_path):
			jp_font.set_fallbacks([load(en_path)])
		_font = jp_font

	var vp := get_viewport().get_visible_rect().size
	SW = vp.x
	SH = vp.y
	_origin = Vector2(SW * 0.22, SH * 0.50)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color   = Color(0.04, 0.05, 0.10)
	bg.z_index = -100
	_root.add_child(bg)

	# プレイヤーエリアのみグリッド（4列）
	var grid := _IsoGrid.new()
	grid.origin = _origin
	grid.tile_w = TILE_W
	grid.tile_h = TILE_H
	_root.add_child(grid)

	# プレビュー用仮データ
	var names  : Array = ["アーサー", "ライン", "ルカ", "ガイ", "リム", "ソレン", "エレナ"]
	var hp_r   : Array = [0.9, 0.7, 1.0, 0.55, 0.8, 1.0, 0.95]
	var atk_v  : Array = [185, 210, 145, 175, 120, 130, 110]
	var spd_v  : Array = [72, 65, 88, 58, 95, 78, 82]
	var max_hp : Array = [500, 480, 360, 620, 280, 310, 290]

	var idx := 0
	for r in 3:
		for c in 4:
			if idx >= names.size():
				break
			var hue := float(abs(hash(names[idx])) % 360) / 360.0
			if idx == 0:
				_add_3d_player_sprite(_iso(c, r), r * 4 + c,
					names[idx], float(hp_r[idx]),
					roundi(float(max_hp[idx]) * float(hp_r[idx])), int(max_hp[idx]),
					r, c)
			else:
				_add_player_sprite(
					_iso(c, r), names[idx], float(hp_r[idx]),
					Color.from_hsv(hue, 0.60, 0.65),
					r * 4 + c,
					roundi(float(max_hp[idx]) * float(hp_r[idx])), int(max_hp[idx]),
					r, c
				)
			idx += 1

	# 敵（絶対座標で指定・PANEL_X に連動しない）
	_add_enemy_sprite(
		Vector2(1000.0, 300.0),
		"ゴブリン王", 0.65, 650, 1000
	)

	_build_right_panel(names, hp_r, atk_v, spd_v, max_hp)
	_build_enemy_action_panel()
	_build_action_buttons()

	# フェーズラベル（ボタン上・中央）
	_timer_lbl = Label.new()
	_timer_lbl.text = "3"
	_timer_lbl.position = Vector2(1100.0, 645.0)
	_timer_lbl.size = Vector2(180.0, 55.0)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.add_theme_font_size_override("font_size", 24)
	_timer_lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.30))
	if _font:
		_timer_lbl.add_theme_font_override("font", _font)
	_timer_lbl.z_index = 10
	_root.add_child(_timer_lbl)

	_timer = 3.0
	_refresh_button_styles()

	# ターン数（戦場エリア左上）
	_turn_lbl = _lbl(_root, "Turn  %d" % _turn, Vector2(20, 18), 22, Color(0.88, 0.78, 0.30))

	_lbl(_root, "[ アイソメトリック表示プレビュー ]   ESC → 前の画面に戻る",
		Vector2(14, SH - 26), 10, Color(0.28, 0.28, 0.38))

# ──────────────────────────────────────────────────────────
func _iso(col: float, row: float) -> Vector2:
	return _origin + Vector2(
		(col - row) * TILE_W * 0.5,
		(col + row) * TILE_H * 0.5
	)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.15, 0.78, 0.28)
	elif ratio > 0.3:
		return Color(0.88, 0.68, 0.08)
	return Color(0.88, 0.18, 0.18)

func _rect(center: Vector2, w: float, h: float, color: Color, z: int) -> void:
	var r := ColorRect.new()
	r.size     = Vector2(w, h)
	r.position = center - Vector2(w * 0.5, h * 0.5)
	r.color    = color
	r.z_index  = z
	_root.add_child(r)

func _add_3d_player_sprite(center: Vector2, z_idx: int,
		unit_name: String, hp_ratio: float, cur_hp: int, max_hp: int,
		row: int, col: int) -> void:
	const VP_W := 180
	const VP_H := 240
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
		mi.rotation_degrees.y = 90  # 右上（敵方向）を向く
		_arena_vp.add_child(mi)

	var tex := TextureRect.new()
	tex.texture = _arena_vp.get_texture()
	tex.size = Vector2(VP_W, VP_H)
	tex.position = center - Vector2(VP_W * 0.5, VP_H * 0.60)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.z_index = z_idx
	_root.add_child(tex)

	# 名前（帽子のすぐ上）
	var name_lbl := _lbl(_root, unit_name,
		center - Vector2(SP_W * 0.5, VP_H * 0.44),
		17, Color(0.88, 0.92, 1.0))
	name_lbl.z_index = z_idx

	# HP バー（足元の少し下）
	var bx := center.x - SP_W * 0.5
	var by := center.y + 49.0
	var hp_bg := ColorRect.new()
	hp_bg.size     = Vector2(SP_W, 5)
	hp_bg.position = Vector2(bx, by)
	hp_bg.color    = Color(0.07, 0.07, 0.09)
	hp_bg.z_index  = z_idx
	_root.add_child(hp_bg)
	var hp_bar := ColorRect.new()
	hp_bar.size     = Vector2(SP_W * hp_ratio, 5)
	hp_bar.position = Vector2(bx, by)
	hp_bar.color    = _hp_color(hp_ratio)
	hp_bar.z_index  = z_idx
	_root.add_child(hp_bar)

	# _player_bodies に登録して rotate アニメーションに参加させる
	# body/accent は tex を共用（TextureRect も position プロパティを持つ）
	_player_bodies.append({
		"body": tex, "accent": tex,
		"name_lbl": name_lbl,
		"hp_bg": hp_bg, "hp_bar": hp_bar,
		"center": center, "row": row, "col": col
	})

func _add_player_sprite(center: Vector2, unit_name: String, hp_ratio: float,
		color: Color, z: int, cur_hp: int, max_hp: int, row: int, col: int) -> void:
	# 本体（暗め）
	var body := ColorRect.new()
	body.size     = Vector2(SP_W, SP_H)
	body.position = center - Vector2(SP_W * 0.5, SP_H * 0.5)
	body.color    = Color(color.r * 0.32, color.g * 0.32, color.b * 0.32, 0.95)
	body.z_index  = z
	_root.add_child(body)

	# 下部アクセント帯
	var accent := ColorRect.new()
	accent.size     = Vector2(SP_W, 10)
	accent.position = center + Vector2(-SP_W * 0.5, SP_H * 0.5 - 11)
	accent.color    = Color(color.r, color.g, color.b, 0.75)
	accent.z_index  = z
	_root.add_child(accent)

	# 名前（上）
	var nl := Label.new()
	nl.text     = unit_name
	nl.position = center + Vector2(-SP_W * 0.5, -SP_H * 0.5 - 20)
	nl.add_theme_font_size_override("font_size", 17)
	nl.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	if _font:
		nl.add_theme_font_override("font", _font)
	nl.z_index  = z
	_root.add_child(nl)

	# HP バー（下）
	var bx := center.x - SP_W * 0.5
	var by := center.y + SP_H * 0.5 + 2.5
	var hp_bg := ColorRect.new()
	hp_bg.size     = Vector2(SP_W, 5)
	hp_bg.position = Vector2(bx, by)
	hp_bg.color    = Color(0.07, 0.07, 0.09)
	hp_bg.z_index  = z
	_root.add_child(hp_bg)
	var hp_bar := ColorRect.new()
	hp_bar.size     = Vector2(SP_W * hp_ratio, 5)
	hp_bar.position = Vector2(bx, by)
	hp_bar.color    = _hp_color(hp_ratio)
	hp_bar.z_index  = z
	_root.add_child(hp_bar)

	_player_bodies.append({
		"body": body, "accent": accent, "name_lbl": nl,
		"hp_bg": hp_bg, "hp_bar": hp_bar,
		"center": center, "row": row, "col": col
	})


func _add_enemy_sprite(center: Vector2, unit_name: String, hp_ratio: float,
		cur_hp: int, max_hp: int) -> void:
	_enemy_body = ColorRect.new()
	_enemy_body.size     = Vector2(EN_W, EN_H)
	_enemy_body.position = center - Vector2(EN_W * 0.5, EN_H * 0.5)
	_enemy_body.color    = Color(0.42, 0.07, 0.07, 0.92)
	_enemy_body.z_index  = 1
	_root.add_child(_enemy_body)
	_rect(center + Vector2(0, EN_H * 0.5 - 16), EN_W, 28,
		Color(0.82, 0.15, 0.15, 0.85), 1)

	var nl := Label.new()
	nl.text     = unit_name
	nl.position = center + Vector2(-EN_W * 0.5, -EN_H * 0.5 - 28)
	nl.add_theme_font_size_override("font_size", 22)
	nl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62))
	if _font:
		nl.add_theme_font_override("font", _font)
	nl.z_index  = 1
	_root.add_child(nl)

	var bar_w := EN_W + 60.0
	var bx    := center.x - bar_w * 0.5
	var by    := center.y + EN_H * 0.5 + 6
	_rect(Vector2(center.x, by + 4), bar_w, 10, Color(0.07, 0.07, 0.09), 1)
	_enemy_bar_w  = bar_w
	_enemy_hp_bar = ColorRect.new()
	_enemy_hp_bar.size     = Vector2(bar_w * hp_ratio, 10)
	_enemy_hp_bar.position = Vector2(bx, by - 1)
	_enemy_hp_bar.color    = Color(0.85, 0.18, 0.18)
	_enemy_hp_bar.z_index  = 1
	_root.add_child(_enemy_hp_bar)

	var hl := Label.new()
	hl.text     = "HP %d/%d" % [cur_hp, max_hp]
	hl.position = Vector2(bx, by + 18)
	hl.add_theme_font_size_override("font_size", 16)
	hl.add_theme_color_override("font_color", Color(0.82, 0.48, 0.48))
	if _font:
		hl.add_theme_font_override("font", _font)
	hl.z_index  = 1
	_root.add_child(hl)

# ──────────────────────────────────────────────────────────
func _build_right_panel(names: Array, hp_r: Array, atk_v: Array,
		spd_v: Array, max_hp: Array) -> void:
	var n       := names.size()
	var panel_w := SW - PANEL_X - 8.0

	# z_index=20 で常に戦場カードの手前に描画
	var rp := Control.new()
	rp.z_index = 20
	_root.add_child(rp)

	var rp_bg := ColorRect.new()
	rp_bg.position = Vector2(PANEL_X - 6, 0)
	rp_bg.size     = Vector2(panel_w + 14, SH)
	rp_bg.color    = Color(0.03, 0.04, 0.09, 0.92)
	rp.add_child(rp_bg)

	var vsep := ColorRect.new()
	vsep.position = Vector2(PANEL_X - 6, 18)
	vsep.size     = Vector2(1, SH - 36)
	vsep.color    = Color(0.20, 0.25, 0.42, 0.45)
	rp.add_child(vsep)

	# ── 上半分: パーティステータス ──
	var status_h := SH * 0.55
	var entry_h  := status_h / float(n)

	for i in n:
		var ey  := 8.0 + i * entry_h
		var ex  := PANEL_X + 4.0
		var hue := float(abs(hash(names[i])) % 360) / 360.0

		# エントリ背景パネル
		var entry_bg   := Panel.new()
		entry_bg.position = Vector2(PANEL_X - 2, ey + 2)
		entry_bg.size     = Vector2(panel_w + 4, entry_h - 4)
		var entry_style   := StyleBoxFlat.new()
		entry_style.bg_color = Color(0.08, 0.10, 0.18, 0.55)
		entry_style.set_corner_radius_all(4)
		entry_bg.add_theme_stylebox_override("panel", entry_style)
		rp.add_child(entry_bg)

		var ph := entry_h - 10.0
		var pw: float = minf(ph * 0.90, 55.0)
		var portrait := ColorRect.new()
		portrait.position = Vector2(ex, ey + 4)
		portrait.size     = Vector2(pw, ph)
		portrait.color    = Color.from_hsv(hue, 0.50, 0.38, 0.95)
		rp.add_child(portrait)
		_lbl(rp, names[i].substr(0, 1),
			Vector2(ex + pw * 0.26, ey + ph * 0.22), 17, Color.WHITE)

		var tx    := ex + pw + 8.0
		var cur_h := roundi(max_hp[i] * hp_r[i])
		_lbl(rp, names[i], Vector2(tx, ey + 5), 18, Color(0.86, 0.90, 0.98))

		var bar_w := panel_w - pw - 28.0
		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(tx, ey + 27)
		hp_bg.size     = Vector2(bar_w, 9)
		hp_bg.color    = Color(0.09, 0.09, 0.11)
		rp.add_child(hp_bg)

		var hp_bar := ColorRect.new()
		hp_bar.position = Vector2(tx, ey + 27)
		hp_bar.size     = Vector2(bar_w * float(hp_r[i]), 9)
		hp_bar.color    = _hp_color(hp_r[i])
		rp.add_child(hp_bar)

		_lbl(rp, "HP %d/%d" % [cur_h, max_hp[i]],
			Vector2(tx, ey + 40), 15, Color(0.58, 0.70, 0.58))
		_lbl(rp, "ATK %d   SPD %d" % [atk_v[i], spd_v[i]],
			Vector2(tx, ey + 58), 15, Color(0.58, 0.65, 0.80))

		if i < n - 1:
			var hsep := ColorRect.new()
			hsep.position = Vector2(PANEL_X, ey + entry_h - 1.0)
			hsep.size     = Vector2(panel_w, 1)
			hsep.color    = Color(0.15, 0.18, 0.30, 0.45)
			rp.add_child(hsep)

	# ── セパレータ ──
	var mid_y   := status_h + 12.0
	var mid_sep := ColorRect.new()
	mid_sep.position = Vector2(PANEL_X, mid_y)
	mid_sep.size     = Vector2(panel_w, 1)
	mid_sep.color    = Color(0.20, 0.25, 0.42, 0.70)
	rp.add_child(mid_sep)

	# ── 下半分: バトルログ（金枠フレーム付き）──
	var log_y := mid_y + 8.0

	var log_frame := Panel.new()
	log_frame.position = Vector2(PANEL_X - 2, log_y - 4)
	log_frame.size     = Vector2(panel_w + 4, SH - log_y)
	var log_style      := StyleBoxFlat.new()
	log_style.bg_color = Color(0.06, 0.04, 0.03, 0.88)
	log_style.border_color = Color(0.68, 0.52, 0.22, 0.85)
	log_style.set_border_width_all(2)
	log_style.set_corner_radius_all(5)
	log_frame.add_theme_stylebox_override("panel", log_style)
	rp.add_child(log_frame)

	var rt    := RichTextLabel.new()
	rt.position          = Vector2(PANEL_X + 6, log_y + 4)
	rt.size              = Vector2(panel_w - 12, SH - log_y - 16.0)
	rt.bbcode_enabled    = true
	rt.scroll_following  = true
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_constant_override("line_separation", 3)
	if _font:
		rt.add_theme_font_override("normal_font", _font)
	rt.text = (
		"[color=#606880]ターン 1 開始[/color]\n"
		+ "アーサーの攻撃 → ゴブリン王に [color=#f5c842]38[/color] ダメージ\n"
		+ "ラインの攻撃 → ゴブリン王に [color=#f5c842]45[/color] ダメージ\n"
		+ "[color=#4488ff]ソレン（補助）→ ルカの攻撃力アップ[/color]\n"
		+ "ルカの攻撃 → ゴブリン王に [color=#f5c842]62[/color] ダメージ"
		+ " [color=#ffd700]CRITICAL![/color]\n"
		+ "ゴブリン王の攻撃 → ガイに [color=#f06060]72[/color] ダメージ\n"
		+ "[color=#606880]ターン 2 開始[/color]\n"
		+ "エレナの回復 → ガイに [color=#55cc88]+55[/color]\n"
		+ "リムの魔法 → ゴブリン王に [color=#aa66ff]28[/color] ダメージ"
	)
	_log = rt
	rp.add_child(rt)

func _build_action_buttons() -> void:
	# グリッド右端（~817）と右パネル（1500）の中間エリアに固定配置
	var btn_y    := 710.0
	var cx       := 1190.0  # 空きエリア中心 x
	var rot_w    := 230.0
	var stay_w   := 200.0
	var gap      := 28.0
	var total_w  := rot_w + gap + stay_w
	var rot_x    := cx - total_w * 0.5
	var stay_x   := rot_x + rot_w + gap
	var btn_h    := 74.0

	# ── スタイル定義 ──
	_rot_sty_normal = StyleBoxFlat.new()
	_rot_sty_normal.bg_color = Color(0.55, 0.28, 0.03, 0.85)
	_rot_sty_normal.set_corner_radius_all(9)

	_rot_sty_selected = StyleBoxFlat.new()
	_rot_sty_selected.bg_color     = Color(0.92, 0.52, 0.05, 1.0)
	_rot_sty_selected.border_color = Color(1.0, 0.82, 0.38)
	_rot_sty_selected.set_border_width_all(3)
	_rot_sty_selected.set_corner_radius_all(9)

	_stay_sty_normal = StyleBoxFlat.new()
	_stay_sty_normal.bg_color = Color(0.03, 0.36, 0.40, 0.85)
	_stay_sty_normal.set_corner_radius_all(9)

	_stay_sty_selected = StyleBoxFlat.new()
	_stay_sty_selected.bg_color     = Color(0.04, 0.42, 0.50, 1.0)
	_stay_sty_selected.border_color = Color(0.32, 0.68, 0.78)
	_stay_sty_selected.set_border_width_all(3)
	_stay_sty_selected.set_corner_radius_all(9)

	var hover_rot := StyleBoxFlat.new()
	hover_rot.bg_color = Color(0.72, 0.40, 0.05, 0.95)
	hover_rot.set_corner_radius_all(9)

	var hover_stay := StyleBoxFlat.new()
	hover_stay.bg_color = Color(0.04, 0.52, 0.58, 0.95)
	hover_stay.set_corner_radius_all(9)

	# ── ローテーションボタン ──
	_rot_btn = Button.new()
	_rot_btn.text     = "ローテーション"
	_rot_btn.position = Vector2(rot_x, btn_y)
	_rot_btn.size     = Vector2(rot_w, btn_h)
	_rot_btn.z_index  = 10
	_rot_btn.add_theme_stylebox_override("normal",  _rot_sty_normal)
	_rot_btn.add_theme_stylebox_override("hover",   hover_rot)
	_rot_btn.add_theme_stylebox_override("pressed", _rot_sty_selected)
	_rot_btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.75))
	_rot_btn.add_theme_font_size_override("font_size", 20)
	if _font:
		_rot_btn.add_theme_font_override("font", _font)
	_rot_btn.pressed.connect(_on_rotation_pressed)
	_root.add_child(_rot_btn)

	# ── ステイボタン ──
	_stay_btn = Button.new()
	_stay_btn.text     = "ステイ"
	_stay_btn.position = Vector2(stay_x, btn_y)
	_stay_btn.size     = Vector2(stay_w, btn_h)
	_stay_btn.z_index  = 10
	_stay_btn.add_theme_stylebox_override("normal",  _stay_sty_normal)
	_stay_btn.add_theme_stylebox_override("hover",   hover_stay)
	_stay_btn.add_theme_stylebox_override("pressed", _stay_sty_selected)
	_stay_btn.add_theme_color_override("font_color", Color(0.75, 0.98, 1.0))
	_stay_btn.add_theme_font_size_override("font_size", 20)
	if _font:
		_stay_btn.add_theme_font_override("font", _font)
	_stay_btn.pressed.connect(_on_stay_pressed)
	_root.add_child(_stay_btn)

func _on_rotation_pressed() -> void:
	_selected_action = 0
	_refresh_button_styles()

func _on_stay_pressed() -> void:
	_selected_action = 1
	_refresh_button_styles()

func _refresh_button_styles() -> void:
	_rot_btn.add_theme_stylebox_override("normal",
		_rot_sty_selected if _selected_action == 0 else _rot_sty_normal)
	_stay_btn.add_theme_stylebox_override("normal",
		_stay_sty_selected if _selected_action == 1 else _stay_sty_normal)

func _process(delta: float) -> void:
	if _screenshot_mode:
		_screenshot_frames += 1
		if _screenshot_frames == 90:
			_save_screenshot()
			get_tree().quit()
		return
	match _phase:
		0:  # SELECT
			_timer -= delta
			if _timer <= 0.0:
				_enter_action_phase()
			else:
				_timer_lbl.text = "%d" % ceili(_timer)
		1:  # ACTION (Rotate.../Stay...)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_enter_battle_phase()
		2:  # BATTLE
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_enter_heal_phase()
		3:  # HEAL
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_enter_select_phase()

func _enter_action_phase() -> void:
	_phase = 1
	_phase_timer = 0.6
	_timer_lbl.text = "Rotate..." if _selected_action == 0 else "Stay..."
	if _selected_action == 0:
		_animate_rotation()

func _enter_battle_phase() -> void:
	_phase = 2
	_phase_timer = 0.85
	_timer_lbl.text = "Battle!"

	var action_str := "ローテーション" if _selected_action == 0 else "ステイ"
	_turn += 1
	_turn_lbl.text = "Turn  %d" % _turn

	var atk_dmg := randi_range(80, 160)
	var def_dmg := randi_range(50, 95)

	_enemy_hp_r = maxf(0.0, _enemy_hp_r - randf_range(0.06, 0.11))
	_enemy_hp_bar.size.x = _enemy_bar_w * _enemy_hp_r
	_enemy_hp_bar.color  = _hp_color(_enemy_hp_r)

	_log.append_text(
		"\n[color=#606880]ターン %d  %s[/color]\n" % [_turn - 1, action_str]
		+ "パーティの攻撃 → ゴブリン王に [color=#f5c842]%d[/color] ダメージ\n" % [atk_dmg]
		+ "ゴブリン王の攻撃 → 前衛に [color=#f06060]%d[/color] ダメージ" % [def_dmg]
	)

	_anim_flash(_enemy_body, Color(1.0, 0.55, 0.55))
	_anim_dmg_float(
		_enemy_body.position + Vector2(EN_W * 0.5, EN_H * 0.3),
		atk_dmg, Color(1.0, 0.88, 0.28)
	)
	if _player_bodies.size() > 0:
		var t: Dictionary = _player_bodies[randi() % _player_bodies.size()]
		_anim_flash(t["body"], Color(1.0, 0.30, 0.30))
		_anim_dmg_float(t["center"] + Vector2(0, -25), def_dmg, Color(1.0, 0.42, 0.42))

func _enter_heal_phase() -> void:
	_phase = 3
	_phase_timer = 0.65
	_timer_lbl.text = "Healing..."

func _animate_rotation() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	for entry in _player_bodies:
		var old_row: int = entry["row"]
		var col: int     = entry["col"]
		var new_row: int = (old_row + 2) % 3
		var new_center: Vector2 = _iso(col, new_row)
		var delta: Vector2      = new_center - entry["center"]
		tw.tween_property(entry["body"],     "position", entry["body"].position + delta,     0.55)
		tw.tween_property(entry["accent"],   "position", entry["accent"].position + delta,   0.55)
		tw.tween_property(entry["name_lbl"], "position", entry["name_lbl"].position + delta, 0.55)
		tw.tween_property(entry["hp_bg"],    "position", entry["hp_bg"].position + delta,    0.55)
		tw.tween_property(entry["hp_bar"],   "position", entry["hp_bar"].position + delta,   0.55)
		var new_z := new_row * 4 + col
		entry["body"].z_index     = new_z
		entry["accent"].z_index   = new_z
		entry["name_lbl"].z_index = new_z
		entry["hp_bg"].z_index    = new_z
		entry["hp_bar"].z_index   = new_z
		entry["center"] = new_center
		entry["row"]    = new_row

func _enter_select_phase() -> void:
	_phase = 0
	_timer = 3.0
	_enemy_slot = (_enemy_slot + 1) % _enemy_cycle.size()
	_action_panel.queue_free()
	_build_enemy_action_panel()
	_selected_action = 1
	_timer_lbl.text = "3"
	_refresh_button_styles()

func _anim_flash(rect: ColorRect, flash_color: Color) -> void:
	var orig := rect.color
	var tw := create_tween()
	tw.tween_property(rect, "color", flash_color, 0.07)
	tw.tween_property(rect, "color", orig, 0.22)

func _anim_dmg_float(pos: Vector2, dmg: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text     = "-%d" % dmg
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.z_index  = 50
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", pos + Vector2(0, -65), 0.75)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.tween_callback(lbl.queue_free)

func _build_enemy_action_panel() -> void:
	var thinking_type := "弱者狙い"
	var px  := 1130.0
	var py  := 175.0
	var pw  := 290.0
	var s_h := 42.0
	var ph  := 46.0 + _enemy_cycle.size() * s_h + 10.0

	_action_panel = Control.new()
	_action_panel.z_index = 5
	_root.add_child(_action_panel)
	var ap := _action_panel

	# パネル背景
	var bg  := Panel.new()
	bg.position = Vector2(px, py)
	bg.size     = Vector2(pw, ph)
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.09, 0.04, 0.04, 0.92)
	sty.border_color = Color(0.55, 0.18, 0.18, 0.70)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(5)
	bg.add_theme_stylebox_override("panel", sty)
	ap.add_child(bg)

	# 思考タイプ
	_lbl(ap, thinking_type, Vector2(px + 10, py + 7), 17, Color(0.92, 0.55, 0.55))

	# セパレータ
	var sep := ColorRect.new()
	sep.position = Vector2(px + 4, py + 30)
	sep.size     = Vector2(pw - 8, 1)
	sep.color    = Color(0.50, 0.15, 0.15, 0.55)
	ap.add_child(sep)

	# 行動スロット
	for i in _enemy_cycle.size():
		var sy      := py + 46.0 + i * s_h
		var is_now  := (i == _enemy_slot)
		var is_past := (i < _enemy_slot)

		# 現在スロットのハイライト背景
		if is_now:
			var hl := ColorRect.new()
			hl.position = Vector2(px + 2, sy + 2)
			hl.size     = Vector2(pw - 4, s_h - 4)
			hl.color    = Color(0.52, 0.08, 0.08, 0.60)
			ap.add_child(hl)

		var label_txt := ("▶ " if is_now else "   ") + "%d.  %s" % [i + 1, _enemy_cycle[i]]
		var label_clr: Color
		if is_now:
			label_clr = Color(1.0, 0.65, 0.65)
		elif is_past:
			label_clr = Color(0.35, 0.22, 0.22)
		else:
			label_clr = Color(0.68, 0.55, 0.55)

		_lbl(ap, label_txt, Vector2(px + 8, sy + 10),
			18 if is_now else 15, label_clr)

		# 現在スロットに「次の行動」バッジ
		if is_now:
			_lbl(ap, "次の行動", Vector2(px + pw - 80, sy + 12),
				13, Color(1.0, 0.42, 0.42, 0.88))

func _lbl(parent: Node, text: String, pos: Vector2,
		sz: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	if _font:
		l.add_theme_font_override("font", _font)
	parent.add_child(l)
	return l

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/formation.tscn")

# ── グリッド線描画 ────────────────────────────────────────
class _IsoGrid extends Node2D:
	var origin: Vector2
	var tile_w: float
	var tile_h: float

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var col := Color(0.4, 0.65, 1.0, 0.18)
		for c in range(0, 4):   # 4マス幅（0〜3列）
			for r in range(0, 3):  # プレイヤーエリアのみ
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
