extends Node3D

# 顔（目・まつ毛・眉・口）を調整する専用シーン。tools/face_editor.tscn からF6で単独起動する。
# 画面左のスライダー/チェック/カラーピッカー/ドロップダウンで全パラメータを調整でき、
# その場で顔が再生成されて反映される（dev_tooling_design.md「全ツール画面UI完結・エディタ往復ゼロ」）。
# 戦闘シーン（本番）には一切影響しない。顔は512x512テクスチャに手続き描画してデカールとして貼る。
#
# ライブ更新の仕組み：各パラメータの setter が _live_update() を呼び、顔テクスチャの再生成と
# 顔板の配置更新だけを差分的に行う（モデルの再読込は char/head パス変更時のみ＝重い処理を避ける）。
# 画面のスライダー等は DevControls 経由で target.set(prop, v) を呼ぶため、既存のsetterがそのまま動く。
# 気に入った顔が決まったら「PNGへベイク」ボタンで _face_preview.png に書き出す（本番ベイク元）。

const DevControls := preload("res://scripts/tools/dev_controls.gd")

const TEX: int = 512
const SAVE_PATH: String = "res://tools/_face_preview.png"
const PIVOT_Y: float = 1.5   # ビュー回転の中心高さ（頭のあたり）
const _CHAR_NAMES: PackedStringArray = ["Barbarian", "Mage", "Knight", "Rogue", "Ranger", "Rogue_Hooded"]
const _BANGS_STYLES: PackedStringArray = ["ぱっつん", "M字", "センター分け"]
const _EXPRESSION_DIR: String = "res://assets/face_expressions/"

var _built: bool = false
var _pivot: Node3D = null
var _char: Node3D = null
var _face_plane: MeshInstance3D = null
var _custom_head: MeshInstance3D = null
var _custom_head_orig_mesh: Mesh = null
var _hair_mesh: MeshInstance3D = null
var _cam: Camera3D = null

var _ui_layer: CanvasLayer = null
var _preset_name_edit: LineEdit = null
var _preset_load_opt: OptionButton = null

# ===== 配置・プレビュー =====
# 胴に使うKayKitキャラ。のっぺらぼう頭は素体非依存なので胴だけ差し替えれば全職で使える。
var char_glb: String = "res://assets/kaykit/characters/Barbarian.glb"
var character: String = "Mage":  # 2026-07-12確定：魔女(WITCH)に割り当てる完成デザインのベース
	set(v):
		character = v
		char_glb = "res://assets/kaykit/characters/" + v + ".glb"
		_rebuild()
var custom_head_glb: String = "res://assets/kaykit/characters/base.glb":
	set(v): custom_head_glb = v; _rebuild()
var custom_head_mesh_name: String = "Barbarian_Head_001":
	set(v): custom_head_mesh_name = v; _rebuild()
var face_height: float = 1.57:
	set(v): face_height = v; _live_update()
var face_forward: float = 0.48:
	set(v): face_forward = v; _live_update()
var face_size: float = 0.85:
	set(v): face_size = v; _live_update()
var face_side: float = 0.0:
	set(v): face_side = v; _live_update()
var face_curve_radius: float = 0.51:  # 顔デカールを頭の丸みに沿わせる球面半径。0=平ら、頭幅の半分(≈0.5)前後で頭に貼り付く
	set(v): face_curve_radius = v; _live_update()
var bake_face_to_head: bool = true:  # ON=目を頭テクスチャに焼き込む（板を消し、どの角度でも浮かない）。OFF=板デカール（調整用・軽い）
	set(v): bake_face_to_head = v; _live_update()
var view_yaw_deg: float = 23.0:   # キャラを左右に回す（正面↔横↔後ろ）
	set(v): view_yaw_deg = v; _update_view()
var view_pitch_deg: float = -5.0:   # キャラを上下に傾ける（見下ろし↔見上げ）
	set(v): view_pitch_deg = v; _update_view()
var cam_distance: float = 2.4:
	set(v): cam_distance = v; _live_update()
var cam_height: float = 1.85:
	set(v): cam_height = v; _live_update()
var cam_side: float = 0.8:
	set(v): cam_side = v; _live_update()
var cam_fov: float = 45.0:
	set(v): cam_fov = v; _live_update()

# ===== 目本体（白目なし・ソリッド）=====
var eye_offset: float = 96.0:
	set(v): eye_offset = v; _live_update()
var eye_cy: float = 284.0:
	set(v): eye_cy = v; _live_update()
var eye_rx: float = 22.0:
	set(v): eye_rx = v; _live_update()
var eye_ry: float = 70.0:
	set(v): eye_ry = v; _live_update()
var eye_squareness: float = 2.3:   # 2=楕円, 大=角丸長方形（ポッケ寄り）
	set(v): eye_squareness = v; _live_update()
var eye_color: Color = Color(0.20, 0.18, 0.30):
	set(v): eye_color = v; _live_update()
var eye_rim_enabled: bool = true:
	set(v): eye_rim_enabled = v; _live_update()
var eye_rim_color: Color = Color(0.36, 0.32, 0.50):
	set(v): eye_rim_color = v; _live_update()
var eye_rim_ratio: float = 0.67:
	set(v): eye_rim_ratio = v; _live_update()
var eye_rim_drop: float = 0.49:
	set(v): eye_rim_drop = v; _live_update()

# ===== まつ毛（目の上端の横線）=====
var lash_enabled: bool = true:
	set(v): lash_enabled = v; _live_update()
var lash_color: Color = Color(0.07, 0.06, 0.09):
	set(v): lash_color = v; _live_update()
var lash_rx_ratio: float = 1.5:
	set(v): lash_rx_ratio = v; _live_update()
var lash_ry: float = 8.0:
	set(v): lash_ry = v; _live_update()
var lash_drop: float = 6.0:
	set(v): lash_drop = v; _live_update()
var lash_rot_deg: float = 8.0:
	set(v): lash_rot_deg = v; _live_update()

# ===== 眉（まつ毛と別・上に離す）=====
var brow_enabled: bool = true:
	set(v): brow_enabled = v; _live_update()
var brow_color: Color = Color(0.34, 0.24, 0.19):
	set(v): brow_color = v; _live_update()
var brow_inner_dx: float = 37.0:
	set(v): brow_inner_dx = v; _live_update()
var brow_outer_dx: float = 74.0:
	set(v): brow_outer_dx = v; _live_update()
var brow_gap: float = 28.0:
	set(v): brow_gap = v; _live_update()
var brow_tilt: float = 10.0:
	set(v): brow_tilt = v; _live_update()
var brow_arch: float = 25.0:
	set(v): brow_arch = v; _live_update()
var brow_thick: float = 5.0:
	set(v): brow_thick = v; _live_update()

# ===== 口（横線）=====
var mouth_enabled: bool = false:  # 2026-07-12確定：無しの方が幼く可愛いと判断
	set(v): mouth_enabled = v; _live_update()
var mouth_color: Color = Color(0.42, 0.24, 0.26):
	set(v): mouth_color = v; _live_update()
var mouth_cy: float = 361.0:
	set(v): mouth_cy = v; _live_update()
var mouth_rx: float = 50.0:
	set(v): mouth_rx = v; _live_update()
var mouth_ry: float = 2.0:
	set(v): mouth_ry = v; _live_update()
var mouth_smile: float = 8.0:  # 0=真顔の横線、上げるほど中央が下がって両端上がる笑み(‿)
	set(v): mouth_smile = v; _live_update()

# ===== 髪（塗り）=====
# 頭テクスチャに前髪・生え際・サイドの髪を描き込む（3Dメッシュ無しでハゲ感を消す）。bake ONで頭に焼き付く。
var hair_enabled: bool = true:
	set(v): hair_enabled = v; _live_update()
var hair_color: Color = Color(0.6039216, 0.47843137, 0.23529412):   # 髪色（金髪・2026-07-12確定）
	set(v): hair_color = v; _live_update()
var hair_top_cy: float = 2.0:   # 頭頂の髪塊の中心高さ
	set(v): hair_top_cy = v; _live_update()
var hair_top_rx: float = 320.0:   # 髪塊の横幅
	set(v): hair_top_rx = v; _live_update()
var hair_top_ry: float = 174.0:   # 髪塊の縦（下ほど生え際が下がる）
	set(v): hair_top_ry = v; _live_update()
var hair_top_square: float = 2.6:     # 髪塊の角丸み（大=四角い＝広く覆う）
	set(v): hair_top_square = v; _live_update()
var hair_bangs_style: String = "M字":  # 前髪の形（2026-07-12確定）
	set(v): hair_bangs_style = v; _live_update()
var hair_bangs_cy: float = 196.0: # 前髪の下端（眉のあたりまで）
	set(v): hair_bangs_cy = v; _live_update()
var hair_bangs_rx: float = 166.0:  # 前髪の横幅
	set(v): hair_bangs_rx = v; _live_update()
var hair_bangs_ry: float = 86.0:   # 前髪の縦の厚み
	set(v): hair_bangs_ry = v; _live_update()
var hair_side_enabled: bool = true:                        # 顔まわりのサイドの髪（フェイスライン）
	set(v): hair_side_enabled = v; _live_update()
var hair_side_dx: float = 220.0:  # サイド髪の左右位置
	set(v): hair_side_dx = v; _live_update()
var hair_side_cy: float = 266.0:  # サイド髪の高さ（下ほど長い）
	set(v): hair_side_cy = v; _live_update()
var hair_side_rx: float = 44.0:    # サイド髪の太さ
	set(v): hair_side_rx = v; _live_update()
var hair_side_ry: float = 204.0:   # サイド髪の長さ
	set(v): hair_side_ry = v; _live_update()

# ===== 髪（3Dメッシュ）=====
# Blenderで作った髪型メッシュ（base.glbと同じ座標系）を頭に載せる。膨らみ・ロング・毛量を出せる。
# 髪glbが無い間はスキップ（エラーにならない）。作ったらパスとメッシュ名を指定してenableをON。
var hair_mesh_enabled: bool = true:
	set(v): hair_mesh_enabled = v; _rebuild()
var hair_mesh_glb: String = "res://assets/kaykit/parts/Mage_hair_final.glb":  # ユーザーがBlenderで作った完成髪（2026-07-12確定）
	set(v): hair_mesh_glb = v; _rebuild()
var hair_mesh_name: String = "HairMesh":
	set(v): hair_mesh_name = v; _rebuild()
var hair_mesh_use_tint: bool = false:   # 髪色をコード側で上書きする（メッシュは明るめ/グレーで作ると効く）。今回はBlender側で塗った本物の色を使うためOFF
	set(v): hair_mesh_use_tint = v; _apply_hair_tint()
var hair_mesh_tint: Color = Color(0.6039216, 0.47843137, 0.23529412):
	set(v): hair_mesh_tint = v; _apply_hair_tint()
var hair_mesh_scale: float = 1.0:   # 髪メッシュの大きさ（頭中心を基準に拡大縮小。帽子に収める用）
	set(v): hair_mesh_scale = v; _apply_hair_transform()
var hair_mesh_offset: Vector3 = Vector3.ZERO:             # 髪メッシュの位置微調整（下げる/前後など）
	set(v): hair_mesh_offset = v; _apply_hair_transform()

func _ready() -> void:
	_build_ui()
	_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

# ===== 画面UI（dev_tooling_design.md「全ツール画面UI完結」・DevControls流用）=====
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui_layer = layer
	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 470.0
	layer.add_child(left)
	var sc := ScrollContainer.new()
	left.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(450, 0)
	sc.add_child(vb)

	var title := Label.new()
	title.text = "顔エディタ"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	DevControls.add_header(vb, "配置・プレビュー")
	DevControls.add_dropdown(vb, "キャラ", _CHAR_NAMES, _CHAR_NAMES.find(character), _on_character_selected)
	_add_text_row(vb, "頭部glb", custom_head_glb, func(v: String) -> void: custom_head_glb = v)
	_add_text_row(vb, "頭メッシュ名", custom_head_mesh_name, func(v: String) -> void: custom_head_mesh_name = v)
	DevControls.add_slider(vb, "顔の高さ", self, "face_height", 1.0, 2.2, 0.01)
	DevControls.add_slider(vb, "顔の前後", self, "face_forward", 0.0, 1.0, 0.01)
	DevControls.add_slider(vb, "顔サイズ", self, "face_size", 0.3, 1.4, 0.01)
	DevControls.add_slider(vb, "顔の左右", self, "face_side", -0.3, 0.3, 0.01)
	DevControls.add_slider(vb, "顔の湾曲半径", self, "face_curve_radius", 0.0, 1.2, 0.01)
	DevControls.add_checkbox(vb, "頭に焼き込み", self, "bake_face_to_head")
	DevControls.add_slider(vb, "ビューYaw", self, "view_yaw_deg", -180.0, 180.0, 1.0)
	DevControls.add_slider(vb, "ビューPitch", self, "view_pitch_deg", -80.0, 80.0, 1.0)
	DevControls.add_slider(vb, "カメラ距離", self, "cam_distance", 1.5, 3.5, 0.05)
	DevControls.add_slider(vb, "カメラ高さ", self, "cam_height", 1.0, 2.5, 0.05)
	DevControls.add_slider(vb, "カメラ左右", self, "cam_side", 0.0, 1.5, 0.05)
	DevControls.add_slider(vb, "画角(FOV)", self, "cam_fov", 20.0, 70.0, 1.0)
	var bake_btn := Button.new()
	bake_btn.text = "PNGへベイク"
	bake_btn.pressed.connect(_bake_png)
	vb.add_child(bake_btn)
	var export_btn := Button.new()
	export_btn.text = "Blender用glbを書き出し"
	export_btn.pressed.connect(_export_scene_glb)
	vb.add_child(export_btn)

	DevControls.add_header(vb, "目")
	DevControls.add_slider(vb, "目の間隔", self, "eye_offset", 40.0, 160.0, 1.0)
	DevControls.add_slider(vb, "目の高さ", self, "eye_cy", 200.0, 380.0, 1.0)
	DevControls.add_slider(vb, "目の横半径", self, "eye_rx", 20.0, 90.0, 1.0)
	DevControls.add_slider(vb, "目の縦半径", self, "eye_ry", 20.0, 100.0, 1.0)
	DevControls.add_slider(vb, "目の角丸み", self, "eye_squareness", 2.0, 8.0, 0.1)
	DevControls.add_color(vb, "目の色", self, "eye_color")
	DevControls.add_checkbox(vb, "目のリム", self, "eye_rim_enabled")
	DevControls.add_color(vb, "リムの色", self, "eye_rim_color")
	DevControls.add_slider(vb, "リム比率", self, "eye_rim_ratio", 0.2, 0.95, 0.01)
	DevControls.add_slider(vb, "リム下がり", self, "eye_rim_drop", 0.0, 0.6, 0.01)

	DevControls.add_header(vb, "まつ毛")
	DevControls.add_checkbox(vb, "まつ毛あり", self, "lash_enabled")
	DevControls.add_color(vb, "まつ毛の色", self, "lash_color")
	DevControls.add_slider(vb, "まつ毛の横比率", self, "lash_rx_ratio", 0.6, 1.5, 0.01)
	DevControls.add_slider(vb, "まつ毛の太さ", self, "lash_ry", 3.0, 24.0, 0.5)
	DevControls.add_slider(vb, "まつ毛の下がり", self, "lash_drop", -10.0, 30.0, 0.5)
	DevControls.add_slider(vb, "まつ毛の角度", self, "lash_rot_deg", -30.0, 30.0, 1.0)

	DevControls.add_header(vb, "眉")
	DevControls.add_checkbox(vb, "眉あり", self, "brow_enabled")
	DevControls.add_color(vb, "眉の色", self, "brow_color")
	DevControls.add_slider(vb, "眉内側位置", self, "brow_inner_dx", 0.0, 70.0, 1.0)
	DevControls.add_slider(vb, "眉外側位置", self, "brow_outer_dx", 0.0, 80.0, 1.0)
	DevControls.add_slider(vb, "眉と目の間隔", self, "brow_gap", 0.0, 60.0, 1.0)
	DevControls.add_slider(vb, "眉の傾き", self, "brow_tilt", -30.0, 40.0, 1.0)
	DevControls.add_slider(vb, "眉のアーチ", self, "brow_arch", -10.0, 40.0, 1.0)
	DevControls.add_slider(vb, "眉の太さ", self, "brow_thick", 2.0, 20.0, 0.5)

	DevControls.add_header(vb, "口")
	DevControls.add_checkbox(vb, "口あり", self, "mouth_enabled")
	DevControls.add_color(vb, "口の色", self, "mouth_color")
	DevControls.add_slider(vb, "口の高さ", self, "mouth_cy", 300.0, 470.0, 1.0)
	DevControls.add_slider(vb, "口の横半径", self, "mouth_rx", 4.0, 50.0, 1.0)
	DevControls.add_slider(vb, "口の太さ", self, "mouth_ry", 1.0, 20.0, 0.5)
	DevControls.add_slider(vb, "口の笑み", self, "mouth_smile", 0.0, 40.0, 1.0)

	DevControls.add_header(vb, "表情プリセット")
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	_preset_name_edit = LineEdit.new()
	_preset_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_name_edit.placeholder_text = "名前（例：怒り）"
	preset_row.add_child(_preset_name_edit)
	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_save_pressed)
	preset_row.add_child(save_btn)
	vb.add_child(preset_row)
	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 8)
	var load_lb := Label.new()
	load_lb.text = "読み込み"
	load_lb.custom_minimum_size = Vector2(70, 0)
	load_row.add_child(load_lb)
	_preset_load_opt = OptionButton.new()
	_preset_load_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_load_opt.item_selected.connect(_on_preset_selected)
	load_row.add_child(_preset_load_opt)
	vb.add_child(load_row)
	_refresh_preset_list()

	DevControls.add_header(vb, "髪（塗り）")
	DevControls.add_checkbox(vb, "髪（塗り）あり", self, "hair_enabled")
	DevControls.add_color(vb, "髪の色", self, "hair_color")
	DevControls.add_slider(vb, "髪塊の高さ", self, "hair_top_cy", -120.0, 220.0, 2.0)
	DevControls.add_slider(vb, "髪塊の横幅", self, "hair_top_rx", 150.0, 380.0, 2.0)
	DevControls.add_slider(vb, "髪塊の縦幅", self, "hair_top_ry", 120.0, 360.0, 2.0)
	DevControls.add_slider(vb, "髪塊の角丸み", self, "hair_top_square", 2.0, 6.0, 0.1)
	DevControls.add_dropdown(vb, "前髪の形", _BANGS_STYLES, _BANGS_STYLES.find(hair_bangs_style), _on_bangs_style_selected)
	DevControls.add_slider(vb, "前髪の下端", self, "hair_bangs_cy", 140.0, 320.0, 2.0)
	DevControls.add_slider(vb, "前髪の横幅", self, "hair_bangs_rx", 60.0, 260.0, 2.0)
	DevControls.add_slider(vb, "前髪の厚み", self, "hair_bangs_ry", 30.0, 160.0, 2.0)
	DevControls.add_checkbox(vb, "サイド髪あり", self, "hair_side_enabled")
	DevControls.add_slider(vb, "サイド髪の位置", self, "hair_side_dx", 120.0, 260.0, 2.0)
	DevControls.add_slider(vb, "サイド髪の高さ", self, "hair_side_cy", 240.0, 470.0, 2.0)
	DevControls.add_slider(vb, "サイド髪の太さ", self, "hair_side_rx", 20.0, 100.0, 2.0)
	DevControls.add_slider(vb, "サイド髪の長さ", self, "hair_side_ry", 80.0, 280.0, 2.0)

	DevControls.add_header(vb, "髪（3Dメッシュ）")
	DevControls.add_checkbox(vb, "3D髪メッシュあり", self, "hair_mesh_enabled")
	_add_text_row(vb, "髪glb", hair_mesh_glb, func(v: String) -> void: hair_mesh_glb = v)
	_add_text_row(vb, "髪メッシュ名", hair_mesh_name, func(v: String) -> void: hair_mesh_name = v)
	DevControls.add_checkbox(vb, "髪色を上書き", self, "hair_mesh_use_tint")
	DevControls.add_color(vb, "髪メッシュtint", self, "hair_mesh_tint")
	DevControls.add_slider(vb, "髪メッシュ拡大", self, "hair_mesh_scale", 0.3, 2.0, 0.01)
	_add_offset_slider(vb, "髪オフセットX", 0)
	_add_offset_slider(vb, "髪オフセットY", 1)
	_add_offset_slider(vb, "髪オフセットZ", 2)

# パス/メッシュ名などの文字列項目。Enter確定時のみ反映（打鍵ごとの重い_rebuild()を避ける）。
func _add_text_row(parent: Container, label: String, initial: String, on_change: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lb := Label.new()
	lb.text = label
	lb.custom_minimum_size = Vector2(150, 0)
	row.add_child(lb)
	var edit := LineEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(t: String) -> void:
		on_change.call(t)
		_rebuild())
	row.add_child(edit)
	parent.add_child(row)
	return edit

# hair_mesh_offset(Vector3)の1軸分のスライダー。DevControlsはVector3非対応のため個別実装。
func _add_offset_slider(parent: Container, label: String, axis: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lb := Label.new()
	lb.text = label
	lb.custom_minimum_size = Vector2(150, 0)
	row.add_child(lb)
	var sld := HSlider.new()
	sld.min_value = -1.0
	sld.max_value = 1.0
	sld.step = 0.01
	sld.custom_minimum_size = Vector2(180, 0)
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sld.value = hair_mesh_offset[axis]
	row.add_child(sld)
	var val_lb := Label.new()
	val_lb.custom_minimum_size = Vector2(64, 0)
	val_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lb.text = "%.2f" % hair_mesh_offset[axis]
	row.add_child(val_lb)
	sld.value_changed.connect(func(v: float) -> void:
		var off: Vector3 = hair_mesh_offset
		off[axis] = v
		hair_mesh_offset = off
		val_lb.text = "%.2f" % v)
	parent.add_child(row)

func _on_character_selected(idx: int) -> void:
	character = _CHAR_NAMES[idx]

func _on_bangs_style_selected(idx: int) -> void:
	hair_bangs_style = _BANGS_STYLES[idx]

# ===== 表情プリセット（保存・読込） =====
# 目/まつ毛/眉/口の現在値を FaceExpression(.tres) として名前付き保存し、後から呼び出す（dev_tooling_design.md A2）。
# 実際の表情デザイン（怒/悲/笑等の数値）はこのツールで人が調整するもの＝ここでは決め打ちしない。
func _on_save_pressed() -> void:
	_save_preset(_preset_name_edit.text.strip_edges())
	_refresh_preset_list()

func _save_preset(name: String) -> void:
	if name.is_empty():
		push_warning("プリセット名が空のため表情プリセットを保存できません")
		return
	var expr := FaceExpression.new()
	expr.eye_offset = eye_offset
	expr.eye_cy = eye_cy
	expr.eye_rx = eye_rx
	expr.eye_ry = eye_ry
	expr.eye_squareness = eye_squareness
	expr.eye_color = eye_color
	expr.eye_rim_enabled = eye_rim_enabled
	expr.eye_rim_color = eye_rim_color
	expr.eye_rim_ratio = eye_rim_ratio
	expr.eye_rim_drop = eye_rim_drop
	expr.lash_enabled = lash_enabled
	expr.lash_color = lash_color
	expr.lash_rx_ratio = lash_rx_ratio
	expr.lash_ry = lash_ry
	expr.lash_drop = lash_drop
	expr.lash_rot_deg = lash_rot_deg
	expr.brow_enabled = brow_enabled
	expr.brow_color = brow_color
	expr.brow_inner_dx = brow_inner_dx
	expr.brow_outer_dx = brow_outer_dx
	expr.brow_gap = brow_gap
	expr.brow_tilt = brow_tilt
	expr.brow_arch = brow_arch
	expr.brow_thick = brow_thick
	expr.mouth_enabled = mouth_enabled
	expr.mouth_color = mouth_color
	expr.mouth_cy = mouth_cy
	expr.mouth_rx = mouth_rx
	expr.mouth_ry = mouth_ry
	expr.mouth_smile = mouth_smile
	DirAccess.make_dir_recursive_absolute(_EXPRESSION_DIR)
	ResourceSaver.save(expr, _EXPRESSION_DIR + name + ".tres")

func _on_preset_selected(idx: int) -> void:
	if idx <= 0:
		return
	_load_preset(_EXPRESSION_DIR + _preset_load_opt.get_item_text(idx))

func _load_preset(path: String) -> void:
	var expr: FaceExpression = load(path)
	if expr == null:
		push_warning("表情プリセットの読込に失敗: " + path)
		return
	eye_offset = expr.eye_offset
	eye_cy = expr.eye_cy
	eye_rx = expr.eye_rx
	eye_ry = expr.eye_ry
	eye_squareness = expr.eye_squareness
	eye_color = expr.eye_color
	eye_rim_enabled = expr.eye_rim_enabled
	eye_rim_color = expr.eye_rim_color
	eye_rim_ratio = expr.eye_rim_ratio
	eye_rim_drop = expr.eye_rim_drop
	lash_enabled = expr.lash_enabled
	lash_color = expr.lash_color
	lash_rx_ratio = expr.lash_rx_ratio
	lash_ry = expr.lash_ry
	lash_drop = expr.lash_drop
	lash_rot_deg = expr.lash_rot_deg
	brow_enabled = expr.brow_enabled
	brow_color = expr.brow_color
	brow_inner_dx = expr.brow_inner_dx
	brow_outer_dx = expr.brow_outer_dx
	brow_gap = expr.brow_gap
	brow_tilt = expr.brow_tilt
	brow_arch = expr.brow_arch
	brow_thick = expr.brow_thick
	mouth_enabled = expr.mouth_enabled
	mouth_color = expr.mouth_color
	mouth_cy = expr.mouth_cy
	mouth_rx = expr.mouth_rx
	mouth_ry = expr.mouth_ry
	mouth_smile = expr.mouth_smile

func _refresh_preset_list() -> void:
	if not _preset_load_opt:
		return
	_preset_load_opt.clear()
	_preset_load_opt.add_item("（なし）")
	var dir := DirAccess.open(_EXPRESSION_DIR)
	if dir:
		for f: String in dir.get_files():
			if f.ends_with(".tres"):
				_preset_load_opt.add_item(f)

# モデル込みで全部組み直す（char/headパス変更時のみ。重い）。UI(_ui_layer)は消さずに残す。
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_built = false
	for c in get_children():
		if c == _ui_layer:
			continue
		remove_child(c)
		c.free()
	# ビュー回転用のピボット（頭の高さ中心で回す）。キャラ・顔・ライトをこの下に入れて一緒に回す。
	_pivot = Node3D.new()
	_pivot.name = "ViewPivot"
	_pivot.position = Vector3(0.0, PIVOT_Y, 0.0)
	add_child(_pivot)
	_char = (load(char_glb) as PackedScene).instantiate()
	_char.position = Vector3(0.0, -PIVOT_Y, 0.0)   # ピボットのオフセットを打ち消してキャラを原点に戻す
	_pivot.add_child(_char)
	var head: MeshInstance3D = _find_head(_char)
	var head_had: bool = head != null
	if head != null:
		_replace_with_custom_head(head)   # head はこの中で削除される（以後参照しない）
	_face_plane = _build_face_plane()
	_char.add_child(_face_plane)
	_face_plane.owner = _char   # owner未設定だとGLTFDocument書き出し(append_from_scene)から漏れる
	_hair_mesh = null
	if hair_mesh_enabled and head_had and _custom_head != null:
		_add_hair_mesh(_custom_head.get_parent())
	_build_env_and_cam()
	_built = true
	_live_update()   # bake_face_to_head の状態を尊重（ONなら焼き込み・OFFなら板デカール）。以前はここで常にデカールに戻して髪が消えるバグがあった
	_update_view()

# 顔テクスチャ再生成＋配置＋カメラだけ更新（スライダー用・軽い）
func _live_update() -> void:
	if not _built:
		return
	if bake_face_to_head:
		# 焼き込みモード：板を消して頭テクスチャに直接描く（どの角度でも浮かない）
		if _face_plane != null:
			_face_plane.visible = false
		_bake_face_onto_head()
	else:
		# デカールモード：頭を元メッシュ/元マテリアルに戻し、板を出して調整（軽い・ライブ向き）
		if _custom_head != null:
			if _custom_head_orig_mesh != null:
				_custom_head.mesh = _custom_head_orig_mesh
			_custom_head.material_override = null
		if _face_plane != null:
			_face_plane.visible = true
		_apply_face_texture()
		_reposition()
	_update_cam()

func _apply_face_texture() -> void:
	if _face_plane == null:
		return
	var mat: StandardMaterial3D = _face_plane.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_texture = ImageTexture.create_from_image(_generate_face_image())

func _reposition() -> void:
	if _face_plane == null:
		return
	_face_plane.mesh = _build_face_mesh()   # 湾曲量・大きさが変わるたびメッシュを作り直す（12x12・軽い）
	_face_plane.position = Vector3(face_side, face_height, face_forward)

func _update_cam() -> void:
	if _cam == null:
		return
	_cam.fov = cam_fov
	_cam.position = Vector3(cam_side, cam_height, cam_distance)
	_cam.look_at(Vector3(0.0, face_height, 0.0), Vector3.UP)

# キャラ全体を頭の高さ中心で回す（ビュー角度の変更）
func _update_view() -> void:
	if _pivot == null:
		return
	_pivot.rotation_degrees = Vector3(view_pitch_deg, view_yaw_deg, 0.0)

func _bake_png() -> void:
	_generate_face_image().save_png(SAVE_PATH)
	print("baked face -> ", SAVE_PATH)

# 今表示中のキャラ（胴＋帽子＋焼き込み頭＋髪の現在スケール/色）を1つのglbに書き出す。
# Blenderでの参照用（実寸で帽子との重なりが見える）。ゲーム本編には使わない一時ファイル。
func _export_scene_glb() -> void:
	if _char == null:
		push_warning("scene not built yet")
		return
	# 非表示ノードがあるとGodotがKHR_node_visibility拡張を書き出し、Blenderの
	# gLTFインポーターが未対応でエラーになる（2026-07-12に実際に踏んだ罠）。
	# 焼き込みモード時は顔板（板デカール）は本来不要な重複物なので、書き出しの間だけ
	# ツリーから完全に外す（可視化して残すと、頭に焼いた目と二重に写り込む＝これも実際に踏んだ）。
	var face_plane_parent: Node = null
	if bake_face_to_head and _face_plane != null and _face_plane.get_parent() != null:
		face_plane_parent = _face_plane.get_parent()
		face_plane_parent.remove_child(_face_plane)
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = doc.append_from_scene(_char, state)
	if face_plane_parent != null:
		face_plane_parent.add_child(_face_plane)
		_face_plane.owner = _char
		_face_plane.visible = false
	if err != OK:
		push_error("gltf export (append_from_scene) failed: " + str(err))
		return
	var out_path: String = "res://tools/_%s_export_for_blender.glb" % character
	err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(out_path))
	if err != OK:
		push_error("gltf export (write_to_filesystem) failed: " + str(err))
		return
	print("exported scene for Blender -> ", out_path)

func _build_face_plane() -> MeshInstance3D:
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = "FacePlane"
	face.mesh = _build_face_mesh()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(_generate_face_image())
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.material_override = mat
	face.position = Vector3(face_side, face_height, face_forward)
	return face

# 顔デカールのメッシュを作る。face_curve_radius>0なら球面パッチに湾曲させて頭の丸みに沿わせる（=横から見ても浮かない）。
# 中央を最前面、縁ほど奥（頭側）へ引っ込めることで凸面の頭にフィットさせる。
func _build_face_mesh() -> ArrayMesh:
	var n: int = 12
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var r: float = face_curve_radius
	for j in range(n + 1):
		for i in range(n + 1):
			var fx: float = float(i) / float(n)   # 0..1
			var fy: float = float(j) / float(n)
			var lx: float = (fx - 0.5) * face_size
			var ly: float = (0.5 - fy) * face_size   # 画像は上がy小さい→ワールドは上がy大きい
			var lz: float = 0.0
			if r > 0.001:
				var d2: float = lx * lx + ly * ly
				# 中央z=0、縁ほど-（頭側へ引っ込む）＝球面キャップ
				lz = -(r - sqrt(max(r * r - d2, 0.0)))
			verts.append(Vector3(lx, ly, lz))
			uvs.append(Vector2(fx, fy))
	var indices: PackedInt32Array = PackedInt32Array()
	for j in range(n):
		for i in range(n):
			var a: int = j * (n + 1) + i
			var b: int = a + 1
			var c: int = a + (n + 1)
			var d: int = c + 1
			indices.append_array([a, c, b, b, c, d])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# 頭メッシュの前面頂点だけコードで平面投影の新UVを振り直し、顔を頭テクスチャに焼き込む。
# 頭は一様な肌色なので元UVは捨ててよい＝顔にテクスチャ全面を割ける（高解像度）。
# 前面(+Z)頂点→顔画像座標へ投影、それ以外→肌色texelへ逃がす。板を使わないので真横でも浮かない。
func _bake_face_onto_head() -> void:
	if _custom_head == null or _custom_head_orig_mesh == null:
		return
	var arr: Array = _custom_head_orig_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	if verts.is_empty() or norms.size() != verts.size():
		push_warning("head mesh lacks normals; cannot bake")
		return
	# テクスチャ：肌色で全面を埋め、顔画像を合成（blend_rect＝ネイティブ高速アルファ合成。
	# 以前は512x512をGDScriptループで合成していて重く、スライダーがもっさりしていたのを解消）
	var skin: Color = Color(0.969, 0.765, 0.627)
	var img: Image = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	img.fill(skin)
	var face: Image = _generate_face_image()
	img.blend_rect(face, Rect2i(0, 0, TEX, TEX), Vector2i(0, 0))
	# 新UV：前面＋側面まで平面投影（顔の特徴は中央にあり、側面頂点は画像端＝肌に落ちるので破綻しない）。
	# 明確に後ろ向き(nz<-0.35)の頂点だけ肌コーナーへ逃がし、UVの不連続な継ぎ目を「頭の後ろ」に隠す＝
	# 正面〜斜めで側面の引き伸ばし（継ぎ目のにじみ）が見えなくなる。
	var newuv: PackedVector2Array = PackedVector2Array()
	newuv.resize(verts.size())
	for i in range(verts.size()):
		if norms[i].z > -0.35:
			var fx: float = (verts[i].x - face_side) / face_size + 0.5
			var fy: float = 0.5 - (verts[i].y - face_height) / face_size
			newuv[i] = Vector2(clampf(fx, 0.0, 1.0), clampf(fy, 0.0, 1.0))
		else:
			newuv[i] = Vector2(0.02, 0.02)
	arr[Mesh.ARRAY_TEX_UV] = newuv
	var newmesh: ArrayMesh = ArrayMesh.new()
	newmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_custom_head.mesh = newmesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_custom_head.material_override = mat

# ---------- 顔の手続き生成 ----------
func _generate_face_image() -> Image:
	var img: Image = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = float(TEX) * 0.5
	var eye_top: float = eye_cy - eye_ry
	# (0) 髪（塗り）＝顔の一番奥に描く。頭頂の髪塊＋前髪＋サイドの髪。
	if hair_enabled:
		_superellipse(img, cx, hair_top_cy, hair_top_rx, hair_top_ry, hair_color, hair_top_square)   # 頭頂〜生え際
		_draw_bangs(img, cx)   # 前髪（スタイル別）
		if hair_side_enabled:
			_superellipse(img, cx - hair_side_dx, hair_side_cy, hair_side_rx, hair_side_ry, hair_color, 2.4)  # 左サイド
			_superellipse(img, cx + hair_side_dx, hair_side_cy, hair_side_rx, hair_side_ry, hair_color, 2.4)  # 右サイド
	for side in [-1.0, 1.0]:
		var ex: float = cx + side * eye_offset
		# (1) 目本体（超楕円：eye_squarenessで楕円↔角丸長方形）
		_superellipse(img, ex, eye_cy, eye_rx, eye_ry, eye_color, eye_squareness)
		if eye_rim_enabled:
			_superellipse(img, ex, eye_cy + eye_ry * eye_rim_drop, eye_rx * eye_rim_ratio, eye_ry * eye_rim_ratio * 0.7, eye_rim_color, eye_squareness)
		# (2) まつ毛
		if lash_enabled:
			var lash_cy: float = eye_top + lash_drop
			_ellipse(img, ex, lash_cy, eye_rx * lash_rx_ratio, lash_ry, lash_color, -side * lash_rot_deg)
		# (3) 眉
		if brow_enabled:
			var lash_top: float = eye_top + lash_drop - lash_ry
			var inner_x: float = ex - side * brow_inner_dx
			var outer_x: float = ex + side * brow_outer_dx
			var inner_y: float = lash_top - brow_gap
			var outer_y: float = lash_top - brow_gap - brow_tilt
			_brow_stroke(img, inner_x, inner_y, outer_x, outer_y, brow_arch, brow_thick, brow_color)
	# (4) 口（両端→中央のベジェ。arch=-smileで中央を下げると笑み(‿)になる）
	if mouth_enabled:
		_brow_stroke(img, cx - mouth_rx, mouth_cy, cx + mouth_rx, mouth_cy, -mouth_smile, mouth_ry, mouth_color)
	return img

# Blender製の髪型メッシュ（別glb）を頭に載せる。base.glbと同座標系なら位置合わせ不要で直置き。
# 静止プレビュー用（本番アニメ追従はheadボーンへのBoneAttachment3Dで別途）。
func _add_hair_mesh(parent: Node) -> void:
	if not ResourceLoader.exists(hair_mesh_glb):
		return  # 髪glbがまだ無い＝スキップ（エラーにしない）
	var src_root: Node = (load(hair_mesh_glb) as PackedScene).instantiate()
	var src: MeshInstance3D = null
	if hair_mesh_name != "":
		src = _find_named(src_root, hair_mesh_name)
	else:
		src = _find_first_mesh(src_root)
	if src == null or src.mesh == null:
		push_warning("hair mesh not found in " + hair_mesh_glb)
		src_root.queue_free()
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "HairMesh"
	mi.mesh = src.mesh
	src_root.queue_free()  # メッシュ参照だけ抜き取ったので、インスタンス化したシーン全体はもう不要
	parent.add_child(mi)
	mi.owner = _char   # owner未設定だとGLTFDocument書き出し(append_from_scene)から漏れる
	_hair_mesh = mi
	_apply_hair_transform()
	_apply_hair_tint()

# 髪メッシュを頭中心を基準に拡大縮小＋位置微調整（帽子に収める用）。頂点は絶対座標なので
# 頭中心(≈y1.6)を軸にスケールし、原点(足元)へ縮まないようにする。
func _apply_hair_transform() -> void:
	if _hair_mesh == null:
		return
	var s: float = hair_mesh_scale
	var pivot: Vector3 = Vector3(0.0, 1.6, 0.0)
	_hair_mesh.scale = Vector3(s, s, s)
	_hair_mesh.position = pivot * (1.0 - s) + hair_mesh_offset

func _apply_hair_tint() -> void:
	if _hair_mesh == null:
		return
	if hair_mesh_use_tint:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = hair_mesh_tint
		# VRoidの外髪は片面ポリゴンで、デフォルトの背面カリングだと裏向きの面が消える
		# （内髪・リボンだけ見えて外髪が出ない症状の原因）。両面表示にして全面出す。
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_hair_mesh.material_override = mat
	else:
		# tint OFF：glbに埋め込まれた部位別マテリアルをそのまま使う（一切上書きしない）。
		# 外髪・内髪は alpha_scissor（アルファテスト＝深度も書くのでちらつかない）、リボンは
		# 不透明、と既にBlender側で正しく設定済み。ここで外髪を不透明化すると隙間のない壁になり
		# 背後の内髪を覆い隠す（＝「外髪か内髪の片方しか出ない」症状の真因）ため、矯正は入れない。
		# surface override は元々どこでもセットしていないので、material_override を外すだけでよい。
		_hair_mesh.material_override = null

func _find_first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _find_first_mesh(c)
		if r != null:
			return r
	return null

func _replace_with_custom_head(head: MeshInstance3D) -> void:
	if not ResourceLoader.exists(custom_head_glb):
		push_warning("custom_head_glb not found: " + custom_head_glb)
		return
	var src_root: Node = (load(custom_head_glb) as PackedScene).instantiate()
	var src: MeshInstance3D = _find_named(src_root, custom_head_mesh_name)
	if src == null or src.mesh == null:
		push_warning("custom head mesh not found: " + custom_head_mesh_name)
		src_root.queue_free()
		return
	var head_transform: Transform3D = head.transform
	var head_parent: Node = head.get_parent()
	# 元の頭はもう使わないので非表示ではなく削除する（非表示ノードがglTF書き出し時に
	# KHR_node_visibility拡張を要求し、Blender側のインポーターが対応しておらずエラーになるため）
	head.get_parent().remove_child(head)
	head.queue_free()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CustomHead"
	mi.mesh = src.mesh
	src_root.queue_free()  # メッシュ参照だけ抜き取ったので、インスタンス化したシーン全体はもう不要
	head_parent.add_child(mi)
	mi.owner = _char   # owner未設定だとGLTFDocument書き出し(append_from_scene)から漏れる
	mi.transform = head_transform
	_custom_head = mi
	_custom_head_orig_mesh = src.mesh

func _build_env_and_cam() -> void:
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	add_child(key)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.fov = cam_fov
	add_child(_cam)
	_cam.position = Vector3(cam_side, cam_height, cam_distance)
	_cam.look_at(Vector3(0.0, face_height, 0.0), Vector3.UP)
	_cam.current = true   # F6実行の実行シーンのみ（@tool廃止済み＝常にtrueで良い）

# 前髪をスタイル別に描く。by=前髪ブロックの中心y、下端がhair_bangs_cyに来るよう配置。
func _draw_bangs(img: Image, cx: float) -> void:
	var by: float = hair_bangs_cy - hair_bangs_ry
	match hair_bangs_style:
		"M字":
			# 左右2つの塊＋中央に短いふさ＝下端がM/W字にうねる
			var off: float = hair_bangs_rx * 0.46
			_superellipse(img, cx - off, by, hair_bangs_rx * 0.58, hair_bangs_ry, hair_color, 2.4)
			_superellipse(img, cx + off, by, hair_bangs_rx * 0.58, hair_bangs_ry, hair_color, 2.4)
			_superellipse(img, cx, by - hair_bangs_ry * 0.30, hair_bangs_rx * 0.34, hair_bangs_ry * 0.95, hair_color, 2.4)
		"センター分け":
			# 中央を分け目にして左右へ流す。中央上に地肌のすき間を残す。
			var off2: float = hair_bangs_rx * 0.52
			_superellipse(img, cx - off2, by + hair_bangs_ry * 0.10, hair_bangs_rx * 0.58, hair_bangs_ry, hair_color, 2.2, 16.0)
			_superellipse(img, cx + off2, by + hair_bangs_ry * 0.10, hair_bangs_rx * 0.58, hair_bangs_ry, hair_color, 2.2, -16.0)
		_:
			# ぱっつん：横に広くて下端が平らな1枚のふさ（指数を上げて底を平たく）
			_superellipse(img, cx, by, hair_bangs_rx, hair_bangs_ry, hair_color, 3.4)

# ---------- 描画ヘルパ ----------
func _brow_stroke(img: Image, x0: float, y0: float, x1: float, y1: float, arch: float, thick: float, col: Color) -> void:
	var ctrl_x: float = (x0 + x1) * 0.5
	var ctrl_y: float = (y0 + y1) * 0.5 - arch
	var steps: int = 40
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var it: float = 1.0 - t
		var px: float = it * it * x0 + 2.0 * it * t * ctrl_x + t * t * x1
		var py: float = it * it * y0 + 2.0 * it * t * ctrl_y + t * t * y1
		var taper: float = sin(t * PI)
		var rad: float = thick * (0.25 + 0.75 * taper)
		_filled_circle(img, px, py, rad, col)

func _filled_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var x0: int = int(max(0.0, floor(cx - r)))
	var x1: int = int(min(float(TEX - 1), ceil(cx + r)))
	var y0: int = int(max(0.0, floor(cy - r)))
	var y1: int = int(min(float(TEX - 1), ceil(cy + r)))
	var r2: float = r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			if dx * dx + dy * dy <= r2:
				_blend(img, x, y, col)

# 超楕円：exponent=2で普通の楕円、値を上げるほど角丸長方形に近づく
func _superellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color, exponent: float, rot_deg: float = 0.0) -> void:
	var rot: float = deg_to_rad(rot_deg)
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	var r: float = max(rx, ry)
	var x0: int = int(max(0.0, floor(cx - r)))
	var x1: int = int(min(float(TEX - 1), ceil(cx + r)))
	var y0: int = int(max(0.0, floor(cy - r)))
	var y1: int = int(min(float(TEX - 1), ceil(cy + r)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var lx: float = dx * cr + dy * sr
			var ly: float = -dx * sr + dy * cr
			var nx: float = abs(lx / rx)
			var ny: float = abs(ly / ry)
			if pow(nx, exponent) + pow(ny, exponent) <= 1.0:
				_blend(img, x, y, col)

func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color, rot_deg: float = 0.0) -> void:
	_superellipse(img, cx, cy, rx, ry, col, 2.0, rot_deg)

func _blend(img: Image, x: int, y: int, col: Color) -> void:
	var dst: Color = img.get_pixel(x, y)
	var a: float = col.a
	img.set_pixel(x, y, Color(
		col.r * a + dst.r * (1.0 - a),
		col.g * a + dst.g * (1.0 - a),
		col.b * a + dst.b * (1.0 - a),
		a + dst.a * (1.0 - a)))

func _find_named(n: Node, nm: String) -> MeshInstance3D:
	if n is MeshInstance3D and n.name == nm:
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _find_named(c, nm)
		if r != null:
			return r
	return null

func _find_head(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).ends_with("_Head"):
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _find_head(c)
		if r != null:
			return r
	return null
