extends Node3D
## KayKitキャラ・カスタマイザー（開発ツール）
## 全キャラが共通のRig_Mediumスケルトンを持つモジュラー構造を利用し、
## パーツ（頭/体/腕/脚/兜/帽子/マント/マスク等）を職跨ぎで混ぜて見た目を組む。
## アニメも再生して、混ぜたパーツがちゃんと一緒に動くか確認できる。
## scenes/char_customizer.tscn から単独起動する。
##
## アニメ合流は anim_browser.build_merged_anim を再利用。

const AnimBrowser := preload("res://scripts/tools/anim_browser.gd")

const CHAR_DIR := "res://assets/kaykit/characters/"
const HOST := "Knight"  # スケルトン供給元（本キャラ＝フル23ボーン。パーツは全部剥がす）
# ※Mannequin_Mediumは骨セットが本キャラと異なり（handslot欠落）スキンバインドが割れるため不可
const SOURCES: Array[String] = [
	"Barbarian", "Knight", "Mage", "Ranger", "Rogue", "Rogue_Hooded",
	"Skeleton_Warrior", "Skeleton_Mage", "Skeleton_Minion", "Skeleton_Rogue",
]
# メッシュ名の末尾スロット名がKayKit側で表記ゆれしているものを正規名へ寄せる
# （例：Skeleton_Mageは頭部メッシュが"Head"でなく"Skull"）
const SLOT_ALIAS: Dictionary = {
	"Skull": "Head",
}
const CORE_SLOTS: Array[String] = [
	"Head", "Body", "ArmLeft", "ArmRight", "LegLeft", "LegRight",
]
const PREVIEW_CLIPS: Array[String] = [
	"General/Idle_A", "General/Idle_B", "MovementBasic/Walking_A",
	"MovementBasic/Running_A", "CombatMelee/Melee_1H_Attack_Chop",
	"General/Hit_B", "Simulation/Waving",
]
const NONE_LABEL := "（なし）"

@export var cam_position: Vector3 = Vector3(2.2, 1.9, 4.4)
@export var cam_look_at: Vector3 = Vector3(0.0, 1.15, 0.0)
@export var cam_fov: float = 42.0
@export var char_scale: float = 1.0
@export var default_clip: String = "General/Idle_A"
@export var rotate_speed: float = 0.01

# slot -> { src_char -> 実メッシュ名 }
var _part_meshname: Dictionary = {}
# 表示順に並べたスロット名
var _slot_order: Array[String] = []
# slot -> 選択中の src_char（"" = なし）
var _selection: Dictionary = {}
# slot -> 検出済み色域 [{color:Color, count:int}, ...]（そのパーツを組み立てるたび再検出）
var _bands: Dictionary = {}
# slot -> {band_idx(int) -> 上書き色}。エントリが無いバンドは元の色のまま。
var _band_tint: Dictionary = {}
# slot -> スウォッチ行（OptionButton変更のたびに中身を作り直す）
var _band_rows: Dictionary = {}

var _char_root: Node3D
var _anim: AnimationPlayer
var _current_clip: String = ""
var _dragging: bool = false

var _name_lbl: Label

func _ready() -> void:
	_scan_parts()
	_init_selection()
	_build_world()
	_build_ui()
	_current_clip = default_clip
	_rebuild_character()

# ── パーツ走査 ─────────────────────────────────────────────
## 6キャラのSkeleton3D配下MeshInstanceを走査し、スロット→(キャラ→メッシュ名)を作る。
func _scan_parts() -> void:
	for src: String in SOURCES:
		var scn: PackedScene = load(CHAR_DIR + src + ".glb")
		if not scn:
			continue
		var root: Node = scn.instantiate()
		var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel:
			for child in skel.get_children():
				if child is MeshInstance3D:
					var slot := _slot_of(child.name)
					slot = SLOT_ALIAS.get(slot, slot)
					if not _part_meshname.has(slot):
						_part_meshname[slot] = {}
					(_part_meshname[slot] as Dictionary)[src] = child.name
		root.free()
	# 表示順：コア→その他（アルファベット）
	for s: String in CORE_SLOTS:
		if _part_meshname.has(s):
			_slot_order.append(s)
	var extras: Array[String] = []
	for s: String in _part_meshname:
		if not CORE_SLOTS.has(s):
			extras.append(s)
	extras.sort()
	_slot_order.append_array(extras)

## メッシュ名 "CharPrefix_Suffix" の Suffix をスロット名として返す。
## キャラ名自体に"_"を含むもの（Skeleton_Mage等）があるため最後の"_"で分割する。
static func _slot_of(mesh_name: String) -> String:
	var i := mesh_name.rfind("_")
	return mesh_name.substr(i + 1) if i >= 0 else mesh_name

func _init_selection() -> void:
	for slot: String in _slot_order:
		if CORE_SLOTS.has(slot):
			# コアはデフォルトでKnight（無ければ先頭）
			var opts := (_part_meshname[slot] as Dictionary)
			_selection[slot] = "Knight" if opts.has("Knight") else (opts.keys()[0] as String)
		else:
			_selection[slot] = ""  # 装飾は初期オフ
		_band_tint[slot] = {}
		_bands[slot] = []

# ── キャラ組み立て ─────────────────────────────────────────
func _rebuild_character() -> void:
	if _char_root and is_instance_valid(_char_root):
		_char_root.queue_free()
	_char_root = assemble(_selection, _part_meshname)
	if not _char_root:
		return
	_char_root.scale = Vector3.ONE * char_scale
	add_child(_char_root)
	_anim = AnimBrowser.build_merged_anim(_char_root)
	for full: String in _anim.get_animation_list():
		var a := _anim.get_animation(full)
		if a and a.length > 0.0:
			a.loop_mode = Animation.LOOP_LINEAR
	if _current_clip != "" and _anim.has_animation(_current_clip):
		_anim.play(_current_clip)
	_refresh_all_bands()

## 現在組み立て済みの各パーツの色域を再検出し、既存の上書き色があれば再適用する。
## assemble()のたびにノードが作り直されるため毎回呼ぶ（検出自体は頂点走査のみで軽い）。
func _refresh_all_bands() -> void:
	for slot: String in _slot_order:
		var mi := _find_mesh_for_slot(slot)
		if not mi:
			_bands[slot] = []
			_refresh_band_ui(slot)
			continue
		_bands[slot] = detect_uv_color_bands(mi)
		var overrides: Dictionary = _band_tint[slot]
		if not overrides.is_empty():
			recolor_part(mi, _bands[slot], overrides)
		_refresh_band_ui(slot)

## _char_root内で指定スロットに対応するMeshInstance3Dを探す。
func _find_mesh_for_slot(slot: String) -> MeshInstance3D:
	if not _char_root:
		return null
	var skel: Skeleton3D = _char_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return null
	for child in skel.get_children():
		if not child is MeshInstance3D:
			continue
		var s: String = SLOT_ALIAS.get(_slot_of(child.name), _slot_of(child.name))
		if s == slot:
			return child as MeshInstance3D
	return null

## 選択に従いHOSTスケルトンへ選択パーツを差してキャラを組む（静的＝テスト可能）。
static func assemble(selection: Dictionary, part_meshname: Dictionary) -> Node3D:
	var host_scn: PackedScene = load(CHAR_DIR + HOST + ".glb")
	if not host_scn:
		return null
	var host: Node3D = host_scn.instantiate() as Node3D
	# HOST由来のAnimationPlayerは除去（自前で合流するため）
	var old_ap := host.find_child("AnimationPlayer", true, false)
	if old_ap:
		old_ap.get_parent().remove_child(old_ap)
		old_ap.free()
	var host_skel: Skeleton3D = host.find_child("Skeleton3D", true, false) as Skeleton3D
	if not host_skel:
		return host
	# HOST標準パーツを全部剥がす
	for child in host_skel.get_children():
		if child is MeshInstance3D:
			host_skel.remove_child(child)
			child.free()
	# 選択パーツを差す
	for slot: String in selection:
		var src: String = selection[slot]
		if src == "":
			continue
		var meshname: String = (part_meshname[slot] as Dictionary).get(src, "")
		if meshname == "":
			continue
		var src_scn: PackedScene = load(CHAR_DIR + src + ".glb")
		if not src_scn:
			continue
		var src_root: Node = src_scn.instantiate()
		var src_skel: Skeleton3D = src_root.find_child("Skeleton3D", true, false) as Skeleton3D
		var part: MeshInstance3D = src_skel.find_child(meshname, false, false) as MeshInstance3D if src_skel else null
		if part:
			part.get_parent().remove_child(part)
			part.owner = null  # 元シーンのowner参照を切る（reparent警告回避）
			host_skel.add_child(part)
			part.skeleton = part.get_path_to(host_skel)
		src_root.free()
	return host

## メッシュが実際に使っているUV座標をサンプルし、テクスチャ上の支配的な色を検出する
## （肌/髪/金属など、パーツ内の異なる色域を見分けるため）。同一パーツを塗り替える際、
## 「何色に見えているか」だけを手掛かりに貪欲クラスタリングする（静的＝テスト可能）。
static func detect_uv_color_bands(mi: MeshInstance3D, max_bands: int = 6, merge_threshold: float = 0.2) -> Array:
	if not mi.mesh or mi.mesh.get_surface_count() == 0:
		return []
	var mat := mi.mesh.surface_get_material(0)
	if not (mat is StandardMaterial3D) or not (mat as StandardMaterial3D).albedo_texture:
		return []
	var tex: Texture2D = (mat as StandardMaterial3D).albedo_texture
	var img := tex.get_image()
	img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	var bands: Array = []
	for uv in uvs:
		var px := clampi(int(uv.x * w), 0, w - 1)
		var py := clampi(int(uv.y * h), 0, h - 1)
		var c := img.get_pixel(px, py)
		var best_i := -1
		var best_d := INF
		for i in bands.size():
			var bc: Color = (bands[i] as Dictionary)["color"]
			var d := absf(c.r - bc.r) + absf(c.g - bc.g) + absf(c.b - bc.b)
			if d < best_d:
				best_d = d
				best_i = i
		if best_i >= 0 and best_d <= merge_threshold:
			var b: Dictionary = bands[best_i]
			var n: int = b["count"]
			b["color"] = (b["color"] as Color).lerp(c, 1.0 / float(n + 1))
			b["count"] = n + 1
		else:
			bands.append({"color": c, "count": 1})

	bands.sort_custom(func(a, b): return (a as Dictionary)["count"] > (b as Dictionary)["count"])
	if bands.size() > max_bands:
		bands = bands.slice(0, max_bands)
	return bands

## 知覚輝度（人の目の感度に近い加重平均）。乗算でなく置換で塗り替えるための陰影抽出に使う。
static func _luminance(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

## 検出済みバンドのうち上書き色があるものだけ塗り替えたテクスチャを作りmaterial_overrideへ適用する。
## 単純な乗算（元の色×tint）だと黒に近い色（髪など）は何を掛けても黒のまま変わらないため、
## 「そのピクセルがバンド平均よりどれだけ明暗にあるか」を輝度比として取り出し、
## tint×陰影比で置き換える（黒髪も金髪や赤髪に塗り替えられる）。
static func recolor_part(mi: MeshInstance3D, bands: Array, band_tint: Dictionary) -> void:
	if not mi.mesh or mi.mesh.get_surface_count() == 0 or bands.is_empty():
		return
	if band_tint.is_empty():
		mi.material_override = null
		return
	var base_mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
	if not base_mat or not base_mat.albedo_texture:
		return
	var img := base_mat.albedo_texture.get_image()
	img.decompress()
	var w := img.get_width()
	var h := img.get_height()

	# 実際に使われている領域だけを塗り替える（UVの外接矩形＋余白）
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var minv := Vector2(1, 1)
	var maxv := Vector2(0, 0)
	for uv in uvs:
		minv = minv.min(uv)
		maxv = maxv.max(uv)
	var pad := 2
	var x0 := clampi(int(minv.x * w) - pad, 0, w - 1)
	var y0 := clampi(int(minv.y * h) - pad, 0, h - 1)
	var x1 := clampi(int(maxv.x * w) + pad, 0, w - 1)
	var y1 := clampi(int(maxv.y * h) + pad, 0, h - 1)

	var out := Image.create(w, h, false, img.get_format())
	out.copy_from(img)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var best_i := -1
			var best_d := INF
			for i in bands.size():
				var bc: Color = (bands[i] as Dictionary)["color"]
				var d := absf(c.r - bc.r) + absf(c.g - bc.g) + absf(c.b - bc.b)
				if d < best_d:
					best_d = d
					best_i = i
			if best_i >= 0 and band_tint.has(best_i):
				var orig: Color = (bands[best_i] as Dictionary)["color"]
				var tint: Color = band_tint[best_i]
				var shade := clampf(_luminance(c) / maxf(_luminance(orig), 0.02), 0.0, 2.5)
				out.set_pixel(x, y, Color(
					clampf(tint.r * shade, 0.0, 1.0),
					clampf(tint.g * shade, 0.0, 1.0),
					clampf(tint.b * shade, 0.0, 1.0),
					c.a))
	var new_tex := ImageTexture.create_from_image(out)
	var mat: StandardMaterial3D = base_mat.duplicate() as StandardMaterial3D
	mat.albedo_texture = new_tex
	mat.albedo_color = Color.WHITE
	mi.material_override = mat

# ── 3Dワールド ─────────────────────────────────────────────
func _build_world() -> void:
	var cam := Camera3D.new()
	cam.look_at_from_position(cam_position, cam_look_at, Vector3.UP)
	cam.fov = cam_fov
	add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.4
	add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.37, 0.45)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.20)
	ground.material_override = mat
	add_child(ground)

# ── UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 460.0
	layer.add_child(left)

	var sc := ScrollContainer.new()
	left.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(440, 0)
	sc.add_child(vb)

	var title := Label.new()
	title.text = "KayKit カスタマイザー"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "パーツを職跨ぎで混ぜる。装飾は（なし）でオフ。"
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))
	vb.add_child(hint)

	for slot: String in _slot_order:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var row := HBoxContainer.new()
		var lb := Label.new()
		lb.text = slot
		lb.custom_minimum_size = Vector2(120, 0)
		if not CORE_SLOTS.has(slot):
			lb.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
		row.add_child(lb)
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(230, 0)
		var options: Array[String] = []
		if not CORE_SLOTS.has(slot):
			opt.add_item(NONE_LABEL)
			options.append("")
		for src: String in SOURCES:
			if (_part_meshname[slot] as Dictionary).has(src):
				opt.add_item(src)
				options.append(src)
		# 現在選択にカーソルを合わせる
		var cur: String = _selection[slot]
		opt.selected = options.find(cur)
		opt.item_selected.connect(_on_slot_changed.bind(slot, options))
		row.add_child(opt)
		col.add_child(row)

		# 色域スウォッチ行（バンド数はパーツごとに違うため、選択のたび作り直す）
		var swatch_row := HBoxContainer.new()
		swatch_row.add_theme_constant_override("separation", 3)
		col.add_child(swatch_row)
		_band_rows[slot] = swatch_row

		vb.add_child(col)

	var color_hint := Label.new()
	color_hint.text = "色スウォッチ＝そのパーツの検出色域。押して変更（陰影は保持）"
	color_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))
	color_hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(color_hint)

	# アニメ選択
	var an_row := HBoxContainer.new()
	var an_lb := Label.new()
	an_lb.text = "アニメ"
	an_lb.custom_minimum_size = Vector2(120, 0)
	an_row.add_child(an_lb)
	var an_opt := OptionButton.new()
	an_opt.custom_minimum_size = Vector2(230, 0)
	for c: String in PREVIEW_CLIPS:
		an_opt.add_item(c)
	an_opt.selected = PREVIEW_CLIPS.find(default_clip)
	an_opt.item_selected.connect(_on_anim_changed)
	an_row.add_child(an_opt)
	vb.add_child(an_row)

	# 下バー
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 480.0
	bottom.offset_top = -70.0
	layer.add_child(bottom)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	bottom.add_child(hb)
	var export_btn := Button.new()
	export_btn.text = "この見た目を書き出す"
	export_btn.pressed.connect(_on_export_pressed)
	hb.add_child(export_btn)
	_name_lbl = Label.new()
	_name_lbl.text = "左ドラッグでキャラ回転 / ESCで終了"
	_name_lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.82))
	hb.add_child(_name_lbl)

# ── バンドUI ───────────────────────────────────────────────
## スロットの検出色域が変わるたび、スウォッチ行の中身を作り直す。
func _refresh_band_ui(slot: String) -> void:
	var row: HBoxContainer = _band_rows.get(slot)
	if not row:
		return
	for c in row.get_children():
		c.queue_free()
	var bands: Array = _bands.get(slot, [])
	var overrides: Dictionary = _band_tint.get(slot, {})
	for i in bands.size():
		var band: Dictionary = bands[i]
		var btn := ColorPickerButton.new()
		btn.custom_minimum_size = Vector2(30, 22)
		btn.color = overrides[i] if overrides.has(i) else (band["color"] as Color)
		btn.color_changed.connect(_on_band_tint_changed.bind(slot, i))
		row.add_child(btn)

# ── ハンドラ ───────────────────────────────────────────────
func _on_slot_changed(idx: int, slot: String, options: Array) -> void:
	_selection[slot] = options[idx]
	_band_tint[slot] = {}  # 別パーツになるとバンド構成が変わるため上書きをリセット
	_rebuild_character()

func _on_band_tint_changed(color: Color, slot: String, band_idx: int) -> void:
	(_band_tint[slot] as Dictionary)[band_idx] = color
	var mi := _find_mesh_for_slot(slot)
	if mi:
		recolor_part(mi, _bands[slot], _band_tint[slot])

## 現在の見た目（各スロットの選択パーツ＋色域上書き）をJSONへ書き出す。
## Claudeが読める場所（プロジェクト内）に置くため globalize_path を使う。
func _on_export_pressed() -> void:
	var out := {"selection": {}, "band_tint": {}, "bands_reference": {}}
	for slot: String in _slot_order:
		out["selection"][slot] = _selection[slot]
		var bands: Array = _bands.get(slot, [])
		var ref: Array = []
		for band: Dictionary in bands:
			ref.append((band["color"] as Color).to_html(true))
		out["bands_reference"][slot] = ref
		var overrides: Dictionary = _band_tint.get(slot, {})
		if not overrides.is_empty():
			var ov_out := {}
			for band_idx: int in overrides:
				ov_out[str(band_idx)] = (overrides[band_idx] as Color).to_html(true)
			out["band_tint"][slot] = ov_out
	var path := "res://tools/customizer_export.json"
	var abs_path := ProjectSettings.globalize_path(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	_name_lbl.text = "書き出し完了: %s" % abs_path

func _on_anim_changed(idx: int) -> void:
	_current_clip = PREVIEW_CLIPS[idx]
	if _anim and _anim.has_animation(_current_clip):
		_anim.play(_current_clip)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging and _char_root:
		_char_root.rotate_y(-event.relative.x * rotate_speed)
