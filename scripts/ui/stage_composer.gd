extends Node
## 戦闘画面構築ツール（dev_tooling_design.md B1＋A4の合流・P1〜A/B画風プリセット）。
## 実 battle.tscn を土台に起動し、背景の切替・画面効果のON/OFF・画風プリセット・戦闘の
## 開始停止/リスタートを画面UIだけで行う（エディタ往復ゼロ・dev_tooling_design.md「画面UIで全調整完結」）。
## P1＝実 battle_scene への生コントロールのみ。小物/タイルの配置とStageLayout(.tres)保存はP2。
## scenes/stage_composer.tscn から単独起動（F6）。
##
## 戦闘の開始/停止は Godot 標準の SceneTree.paused を使う（構築パネルだけ PROCESS_MODE_ALWAYS で
## 動かし、土台の戦闘だけ止める）。ポーズ中も描画は続くので効果ON/OFFの見た目はその場で反映される。

const DevControls := preload("res://scripts/tools/dev_controls.gd")
const _BATTLE_SCENE := preload("res://scenes/battle.tscn")

# 背景種別ラベル（battle_scene._resolve_bg_variant のインデックスと一致：0=草原 1=Kenney 2=KayKit）
const _BG_LABELS: PackedStringArray = ["草原", "ダンジョン(Kenney)", "ダンジョン(KayKit)"]

# 敵モデル差し替え候補（見た目確認専用・2026-07-18選定）。ラベルとres pathは対で並べる
const _ENEMY_PREVIEW_LABELS: PackedStringArray = ["なし（通常の敵）",
	"Mimic Chest", "Minataur Low Poly", "Eblan（ゴーレム）", "Venus Pie Trap", "Shark",
	"Unicorn", "Griffin", "Devil Bulldog", "Wolfboss", "Little Ghost",
	"DragonSoulEater(青)", "DragonTerrorBringer(赤)", "DragonNightmare(青)", "DragonUsurper(赤)",
	"DragonTerrorBringer(赤・アニメ入り／FBX直接方式)",
	"DragonSoulEater(青・アニメ入り／FBX直接方式)",
	"DragonNightmare(青・アニメ入り／FBX直接方式)",
	"DragonUsurper(赤・アニメ入り／FBX直接方式)"]
const _ENEMY_PREVIEW_PATHS: PackedStringArray = ["",
	"res://assets/enemy_candidates/sketchfab/mimic_chest.glb",
	"res://assets/enemy_candidates/sketchfab/minotaur_lowpoly.glb",
	"res://assets/enemy_candidates/sketchfab/eblan_golem.glb",
	"res://assets/enemy_candidates/sketchfab/venus_pie_trap.glb",
	"res://assets/enemy_candidates/sketchfab/shark.glb",
	"res://assets/enemy_candidates/sketchfab/unicorn.glb",
	"res://assets/enemy_candidates/sketchfab/griffin.glb",
	"res://assets/enemy_candidates/unity/devil_bulldog.glb",
	"res://assets/enemy_candidates/unity/wolfboss.glb",
	"res://assets/enemy_candidates/unity/little_ghost.glb",
	"res://assets/enemy_candidates/dungeon_mason/dragon_soul_eater.glb",
	"res://assets/enemy_candidates/dungeon_mason/dragon_terror_bringer.glb",
	"res://assets/enemy_candidates/dungeon_mason/dragon_nightmare.glb",
	"res://assets/enemy_candidates/dungeon_mason/dragon_usurper.glb",
	"res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx",
	"res://assets/enemy_candidates/dungeon_mason_fbx/dragon_soul_eater.fbx",
	"res://assets/enemy_candidates/dungeon_mason_fbx/dragon_nightmare.fbx",
	"res://assets/enemy_candidates/dungeon_mason_fbx/dragon_usurper.fbx"]
# 差し替えモデルごとの表示倍率（ラベル/パスと同じ並び・同じ件数）。
# dungeon_masonのドラゴン4種（静止GLB）は素のメッシュが5〜19単位＝そのままだと画面外まで
# 膨らむため、既存の第3戦ドラゴン（Dragon_Evolved×battle_model_scale 0.56＝高さ約1.6・
# 最大辺約3.1）に収まるようX/Y/Zの最大辺と高さの両方から求めた小さい方を採る。1.0＝素のまま。
# dungeon_mason_fbx（アニメ合流用のメッシュFBX）は.importのnodes/root_scale=0.01で
# ジオメトリを1/100に焼いており（合流するアニメFBXの位置トラックも
# BattleScene._DRAGON_ANIM_POS_SCALEで同じ比率だけ縮めて単位を合わせている）、結果として
# GLB版とほぼ同じ大きさになるため倍率もGLB版と同程度の値を使う。
# 注意：素のFBX（cm単位）のままNode3D.scaleだけで極小倍率（0.002前後）まで縮める方式は
# 2026-07-19に実機で「実際にGPUスキニングが描画されなくなる」不具合を踏んだため廃止した
# （ヘッドレステストでは正常に見えるが実描画でだけ消える＝ダミーレンダラーでは再現不可）
const _ENEMY_PREVIEW_SCALES: PackedFloat32Array = [1.0,
	1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0,
	0.28, 0.21, 0.25, 0.16,
	0.21, 0.28, 0.25, 0.16]
# アニメ合流フォルダ（res://.../Animations/<竜名>）。dungeon_mason_fbx（FBX直接方式）4種のみ
# 値を持つ。空＝そのモデルはアニメ合流しない（静止GLBや他候補はここが空のまま）。
# 罠：テクスチャのフォルダ名は Texture/DragonNightmare（小文字m）だが、アニメのフォルダ名は
# Animations/DragonNightMare（大文字M）で綴りが違う
const _ENEMY_PREVIEW_ANIM_DIRS: PackedStringArray = ["",
	"", "", "", "", "",
	"", "", "", "", "",
	"", "", "", "",
	"res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer",
	"res://assets/dungeon-mason-dragons/Animations/DragonSoulEater",
	"res://assets/dungeon-mason-dragons/Animations/DragonNightMare",
	"res://assets/dungeon-mason-dragons/Animations/DragonUsurper"]
# 画風プリセットラベル（BattleScene.StylePresetのインデックスと一致：0=A 1=B 2=現状）
const _STYLE_LABELS: PackedStringArray = ["A（なめらか）", "B（絵本）", "現状"]

# 画面が保持する状態（リスタート後も維持し、再生成した戦闘へ再適用する）
@export var bg_variant: int = 2          # 既定＝ダンジョンKayKit
@export var clay_enabled: bool = true    # 粘土ベース（切替はリスタート反映）
@export var battle_index: int = 2        # 敵/BGMの選択（既定＝第3戦・ダンジョン想定）
@export var style_preset_idx: int = 2    # 既定＝現状（BattleScene.StylePreset.CURRENT）
@export var enemy_preview_idx: int = 0   # 敵モデル差し替え（0=なし・見た目のみ、_ENEMY_PREVIEW_PATHS参照）
@export var enemy_idle_clip: String = "" # 差し替えモデルの待機クリップ（空=モデル既定。地上/飛行の切替用）

# 画面効果ON/OFF（既存@export既定と一致させる＝battle_sceneの「現状」プリセットと同じ値）
@export var outline_enabled: bool = true
@export var paper_enabled: bool = true
@export var boil_enabled: bool = true
@export var fog_enabled: bool = true
@export var lut_enabled: bool = false
@export var tilt_enabled: bool = false
@export var glow_enabled: bool = false
@export var shadow_soft_enabled: bool = false
@export var msaa_enabled: bool = false
@export var contact_shadow_enabled: bool = false
@export var paint_tex_enabled: bool = false
@export var kuwahara_enabled: bool = false
@export var hull_outline_enabled: bool = false

# 微調整スライダー値（既定はbattle_sceneの既存@export既定と一致）
@export var clay_hatch_strength: float = 0.3
@export var clay_rim_strength: float = 0.25
@export var clay_light_softness: float = 0.04
@export var clay_outline_thickness: float = 1.0
@export var clay_outline_softness: float = 0.0
@export var clay_grain_strength: float = 0.10
@export var clay_posterize_levels: float = 9.0
@export var tilt_sharp_band: float = 0.18
@export var tilt_blur: float = 2.5
@export var glow_intensity: float = 0.25
@export var shadow_blur: float = 1.0
@export var contact_shadow_radius: float = 0.6
@export var contact_shadow_opacity: float = 0.4
@export var lut_desaturate: float = 0.18
@export var fog_density: float = 0.02
@export var paint_tex_strength: float = 0.35
@export var paint_tex_scale: float = 6.0
@export var kuwahara_radius: float = 3.0
@export var hull_outline_width: float = 0.015
@export var shadow_distance: float = 20.0

# チェック/スライダー→反映のON/OFF系フィールド名一覧（_refresh_control_widgets用）
const _BOOL_FIELDS: PackedStringArray = ["outline_enabled", "paper_enabled", "boil_enabled",
	"fog_enabled", "lut_enabled", "tilt_enabled", "glow_enabled", "shadow_soft_enabled",
	"msaa_enabled", "contact_shadow_enabled", "paint_tex_enabled", "kuwahara_enabled",
	"hull_outline_enabled"]
const _FLOAT_FIELDS: PackedStringArray = ["clay_hatch_strength", "clay_rim_strength",
	"clay_light_softness", "clay_outline_thickness", "clay_outline_softness",
	"clay_grain_strength", "clay_posterize_levels", "tilt_sharp_band", "tilt_blur",
	"glow_intensity", "shadow_blur", "contact_shadow_radius", "contact_shadow_opacity",
	"lut_desaturate", "fog_density", "paint_tex_strength", "paint_tex_scale", "kuwahara_radius",
	"hull_outline_width", "shadow_distance"]

var _battle: BattleScene = null
var _panel_layer: CanvasLayer = null
var _run_btn: Button = null
var _running: bool = true
var _ctl: Dictionary = {}  # フィールド名 → CheckBox/HSlider（画風プリセット適用時の表示同期用）
# 差し替えモデルのアニメ操作欄。クリップ構成はモデルごとに違うので生成のたびに作り直す
var _anim_box: VBoxContainer = null
var _clip_idx: int = 0

func _ready() -> void:
	GameState.ensure_init()
	_build_panel()
	_spawn_battle()

# ── 土台の戦闘を（再）生成する。現在の画面状態を新しいインスタンスへ流し込んでから足す ──
func _spawn_battle() -> void:
	if _battle and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	get_tree().paused = false
	_running = true
	_update_run_btn()

	GameState.battle_index = battle_index
	var b: BattleScene = _BATTLE_SCENE.instantiate() as BattleScene
	b.preview_mode = true
	b.background_variant_override = bg_variant
	b.clay_enabled = clay_enabled
	b.clay_outline_enabled = outline_enabled
	b.clay_paper_enabled = paper_enabled
	b.clay_boil_enabled = boil_enabled
	b.fog_enabled = fog_enabled
	b.lut_enabled = lut_enabled
	b.tilt_enabled = tilt_enabled
	b.glow_enabled = glow_enabled
	b.shadow_soft_enabled = shadow_soft_enabled
	b.msaa_enabled = msaa_enabled
	b.contact_shadow_enabled = contact_shadow_enabled
	b.paint_tex_enabled = paint_tex_enabled
	b.kuwahara_enabled = kuwahara_enabled
	b.hull_outline_enabled = hull_outline_enabled
	b.enemy_preview_path = _ENEMY_PREVIEW_PATHS[enemy_preview_idx]
	b.enemy_preview_scale = _ENEMY_PREVIEW_SCALES[enemy_preview_idx]
	b.enemy_preview_idle = enemy_idle_clip
	b.enemy_preview_anim_dir = _ENEMY_PREVIEW_ANIM_DIRS[enemy_preview_idx]
	b.clay_hatch_strength = clay_hatch_strength
	b.clay_rim_strength = clay_rim_strength
	b.clay_light_softness = clay_light_softness
	b.clay_outline_thickness = clay_outline_thickness
	b.clay_outline_softness = clay_outline_softness
	b.clay_grain_strength = clay_grain_strength
	b.clay_posterize_levels = clay_posterize_levels
	b.tilt_sharp_band = tilt_sharp_band
	b.tilt_blur = tilt_blur
	b.glow_intensity = glow_intensity
	b.shadow_blur = shadow_blur
	b.contact_shadow_radius = contact_shadow_radius
	b.contact_shadow_opacity = contact_shadow_opacity
	b.lut_desaturate = lut_desaturate
	b.fog_density = fog_density
	b.paint_tex_strength = paint_tex_strength
	b.paint_tex_scale = paint_tex_scale
	b.kuwahara_radius = kuwahara_radius
	b.hull_outline_width = hull_outline_width
	b.shadow_distance = shadow_distance
	add_child(b)
	_battle = b
	# add_child()直後はまだ_ready()が走っていない（ユニット生成は次フレーム）ため、
	# ここで即_rebuild_anim_controls()を呼ぶと敵のAnimationPlayerが存在せずクリップ0件になる
	# （2026-07-19実測：add_child直後はclips=[]、1 process_frame待つと18件揃う）。
	# 待機アニメが一切再生されない不具合として顕在化していた
	await get_tree().process_frame
	_rebuild_anim_controls()  # クリップ一覧は生成後の敵からしか引けない

# ── 差し替えモデルのアニメ操作欄を作り直す ──
# 内蔵アニメを持たないモデル（「なし」や静止GLB）では欄を空のままにする
func _rebuild_anim_controls() -> void:
	if _anim_box == null or _battle == null:
		return
	for c: Node in _anim_box.get_children():
		_anim_box.remove_child(c)
		c.queue_free()
	var clips: PackedStringArray = _battle.preview_enemy_clip_list()
	if clips.is_empty():
		return
	# 待機候補＝名前に idle を含むもの（地上 idle01/idle02 と飛行 FlyIdle が両方入る）
	var idles: PackedStringArray = []
	for c: String in clips:
		if c.to_lower().contains("idle"):
			idles.append(c)
	if idles.is_empty():
		idles = clips
	if enemy_idle_clip.is_empty() or not idles.has(enemy_idle_clip):
		enemy_idle_clip = _default_idle(idles)
		_battle.preview_set_enemy_idle(enemy_idle_clip)

	DevControls.add_header(_anim_box, "アニメーション")
	DevControls.add_dropdown(_anim_box, "待機", idles, idles.find(enemy_idle_clip), func(i: int) -> void:
		enemy_idle_clip = idles[i]
		if _battle:
			_battle.preview_set_enemy_idle(enemy_idle_clip))
	_clip_idx = clampi(_clip_idx, 0, clips.size() - 1)
	DevControls.add_dropdown(_anim_box, "クリップ", clips, _clip_idx, func(i: int) -> void:
		_clip_idx = i)
	var play_btn := Button.new()
	play_btn.text = "再生（1回・終了後は待機へ戻る）"
	play_btn.pressed.connect(func() -> void:
		if _battle:
			_battle.preview_play_enemy_clip(clips[_clip_idx]))
	_anim_box.add_child(play_btn)

# 既定の待機＝飛行でない待機を優先する（地上に立っている見た目に合わせる）
static func _default_idle(idles: PackedStringArray) -> String:
	for c: String in idles:
		if not c.to_lower().begins_with("fly"):
			return c
	return idles[0]

# ── 構築パネル（PROCESS_MODE_ALWAYS＝ポーズ中も操作できる）──
func _build_panel() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 128  # 戦闘UI(BattleUI)より前面
	_panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_panel_layer)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 16)
	scroll.custom_minimum_size = Vector2(320, 920)
	_panel_layer.add_child(scroll)

	var panel := PanelContainer.new()
	scroll.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(280, 0)
	margin.add_child(vbox)

	DevControls.add_header(vbox, "戦闘画面構築ツール")

	DevControls.add_dropdown(vbox, "背景", _BG_LABELS, bg_variant, func(idx: int) -> void:
		bg_variant = idx
		if _battle:
			_battle.rebuild_background(idx))

	DevControls.add_header(vbox, "敵モデル差し替え（見た目確認専用）")
	DevControls.add_dropdown(vbox, "モデル", _ENEMY_PREVIEW_LABELS, enemy_preview_idx, func(idx: int) -> void:
		enemy_preview_idx = idx
		enemy_idle_clip = ""   # 待機クリップ名はモデルごとに違うので選び直しさせる
		_clip_idx = 0
		_spawn_battle())

	# アニメ操作欄（内蔵アニメを持つモデルのときだけ中身が入る）
	_anim_box = VBoxContainer.new()
	_anim_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_anim_box)

	DevControls.add_header(vbox, "画風プリセット")
	DevControls.add_dropdown(vbox, "プリセット", _STYLE_LABELS, style_preset_idx, _apply_style_preset)
	# OptionButtonは同一項目の再選択でitem_selectedが発火しないため、専用ボタンで
	# 「現在選択中のプリセットの定義値」を再適用する（dev_tooling_design.md実装順2）
	var reset_btn := Button.new()
	reset_btn.text = "初期値に戻す"
	reset_btn.pressed.connect(func() -> void: _apply_style_preset(style_preset_idx))
	vbox.add_child(reset_btn)

	DevControls.add_header(vbox, "画面効果")
	DevControls.add_checkbox(vbox, "粘土ベース（切替でリスタート）", self, "clay_enabled",
		func(_on: bool) -> void: _spawn_battle())
	_ctl["outline_enabled"] = DevControls.add_checkbox(vbox, "輪郭線", self, "outline_enabled",
		func(on: bool) -> void: if _battle: _battle.set_outline_enabled(on))
	_ctl["paper_enabled"] = DevControls.add_checkbox(vbox, "紙グレイン", self, "paper_enabled",
		func(on: bool) -> void: if _battle: _battle.set_paper_enabled(on))
	_ctl["boil_enabled"] = DevControls.add_checkbox(vbox, "頂点ボイル", self, "boil_enabled",
		func(on: bool) -> void: if _battle: _battle.set_boil_enabled(on))
	_ctl["fog_enabled"] = DevControls.add_checkbox(vbox, "霧", self, "fog_enabled",
		func(on: bool) -> void: if _battle: _battle.set_fog_enabled(on))
	_ctl["lut_enabled"] = DevControls.add_checkbox(vbox, "LUT", self, "lut_enabled",
		func(on: bool) -> void: if _battle: _battle.set_lut_enabled(on))
	_ctl["tilt_enabled"] = DevControls.add_checkbox(vbox, "tilt-shift", self, "tilt_enabled",
		func(on: bool) -> void: if _battle: _battle.set_tilt_enabled(on))
	_ctl["glow_enabled"] = DevControls.add_checkbox(vbox, "glow（弱ブルーム）", self, "glow_enabled",
		func(on: bool) -> void: if _battle: _battle.set_glow_enabled(on))
	_ctl["shadow_soft_enabled"] = DevControls.add_checkbox(vbox, "ソフトシャドウ", self, "shadow_soft_enabled",
		func(on: bool) -> void: if _battle: _battle.set_shadow_soft_enabled(on))
	_ctl["msaa_enabled"] = DevControls.add_checkbox(vbox, "MSAA 4x", self, "msaa_enabled",
		func(on: bool) -> void: if _battle: _battle.set_msaa_enabled(on))
	_ctl["contact_shadow_enabled"] = DevControls.add_checkbox(vbox, "接地ブロブ影", self, "contact_shadow_enabled",
		func(on: bool) -> void: if _battle: _battle.set_contact_shadow_enabled(on))
	_ctl["paint_tex_enabled"] = DevControls.add_checkbox(vbox, "絵具/紙テクスチャ", self, "paint_tex_enabled",
		func(on: bool) -> void: if _battle: _battle.set_paint_tex_enabled(on))
	_ctl["kuwahara_enabled"] = DevControls.add_checkbox(vbox, "Kuwahara筆致（重い）", self, "kuwahara_enabled",
		func(on: bool) -> void: if _battle: _battle.set_kuwahara_enabled(on))
	_ctl["hull_outline_enabled"] = DevControls.add_checkbox(vbox, "inverted-hull輪郭", self, "hull_outline_enabled",
		func(on: bool) -> void: if _battle: _battle.set_hull_outline_enabled(on))

	DevControls.add_header(vbox, "微調整（プリセット適用後に調整可）")
	_ctl["clay_hatch_strength"] = DevControls.add_slider(vbox, "ハッチ強さ", self, "clay_hatch_strength",
		0.0, 1.0, 0.01, func(v: float) -> void: if _battle: _battle.set_clay_hatch_strength(v))
	_ctl["clay_rim_strength"] = DevControls.add_slider(vbox, "リム強さ", self, "clay_rim_strength",
		0.0, 1.0, 0.01, func(v: float) -> void: if _battle: _battle.set_clay_rim_strength(v))
	_ctl["clay_light_softness"] = DevControls.add_slider(vbox, "陰境界の柔らかさ", self, "clay_light_softness",
		0.04, 0.25, 0.01, func(v: float) -> void: if _battle: _battle.set_clay_light_softness(v))
	_ctl["clay_outline_thickness"] = DevControls.add_slider(vbox, "輪郭太さ", self, "clay_outline_thickness",
		0.5, 4.0, 0.5, func(v: float) -> void:
			if _battle:
				_battle.clay_outline_thickness = v
				_battle.set_outline_enabled(_battle.clay_outline_enabled))
	_ctl["clay_outline_softness"] = DevControls.add_slider(vbox, "輪郭ソフト化", self, "clay_outline_softness",
		0.0, 0.3, 0.01, func(v: float) -> void: if _battle: _battle.set_clay_outline_softness(v))
	_ctl["clay_grain_strength"] = DevControls.add_slider(vbox, "紙グレイン強さ", self, "clay_grain_strength",
		0.0, 0.3, 0.01, func(v: float) -> void:
			if _battle:
				_battle.clay_grain_strength = v
				_battle.set_paper_enabled(_battle.clay_paper_enabled))
	_ctl["clay_posterize_levels"] = DevControls.add_slider(vbox, "ポスタライズ段数", self, "clay_posterize_levels",
		2.0, 32.0, 1.0, func(v: float) -> void:
			if _battle:
				_battle.clay_posterize_levels = v
				_battle.set_paper_enabled(_battle.clay_paper_enabled))
	_ctl["tilt_sharp_band"] = DevControls.add_slider(vbox, "tilt鮮明帯", self, "tilt_sharp_band",
		0.05, 0.45, 0.01, func(v: float) -> void: if _battle: _battle.set_tilt_sharp_band(v))
	_ctl["tilt_blur"] = DevControls.add_slider(vbox, "tiltぼかし量", self, "tilt_blur",
		0.0, 6.0, 0.1, func(v: float) -> void: if _battle: _battle.set_tilt_blur(v))
	_ctl["glow_intensity"] = DevControls.add_slider(vbox, "glow強さ", self, "glow_intensity",
		0.0, 1.0, 0.01, func(v: float) -> void: if _battle: _battle.set_glow_intensity(v))
	_ctl["shadow_blur"] = DevControls.add_slider(vbox, "シャドウぼかし", self, "shadow_blur",
		0.0, 3.0, 0.05, func(v: float) -> void: if _battle: _battle.set_shadow_blur(v))
	_ctl["shadow_distance"] = DevControls.add_slider(vbox, "影の距離", self, "shadow_distance",
		5.0, 60.0, 0.5, func(v: float) -> void: if _battle: _battle.set_shadow_distance(v))
	_ctl["contact_shadow_radius"] = DevControls.add_slider(vbox, "接地影半径", self, "contact_shadow_radius",
		0.3, 1.5, 0.01, func(v: float) -> void: if _battle: _battle.set_contact_shadow_radius(v))
	_ctl["contact_shadow_opacity"] = DevControls.add_slider(vbox, "接地影濃さ", self, "contact_shadow_opacity",
		0.0, 1.0, 0.01, func(v: float) -> void: if _battle: _battle.set_contact_shadow_opacity(v))
	_ctl["lut_desaturate"] = DevControls.add_slider(vbox, "LUT彩度(負で上げる)", self, "lut_desaturate",
		-0.3, 1.0, 0.01, func(v: float) -> void: if _battle: _battle.set_lut_desaturate(v))
	_ctl["fog_density"] = DevControls.add_slider(vbox, "霧の濃さ", self, "fog_density",
		0.0, 0.06, 0.001, func(v: float) -> void:
			if _battle:
				_battle.fog_density = v
				_battle.set_fog_enabled(_battle.fog_enabled))
	_ctl["paint_tex_strength"] = DevControls.add_slider(vbox, "塗りテクスチャ強さ", self, "paint_tex_strength",
		0.0, 1.0, 0.01, func(v: float) -> void: if _battle: _battle.set_paint_tex_strength(v))
	_ctl["paint_tex_scale"] = DevControls.add_slider(vbox, "塗りテクスチャ粒度", self, "paint_tex_scale",
		1.0, 20.0, 0.5, func(v: float) -> void: if _battle: _battle.set_paint_tex_scale(v))
	_ctl["kuwahara_radius"] = DevControls.add_slider(vbox, "Kuwahara半径", self, "kuwahara_radius",
		1.0, 6.0, 1.0, func(v: float) -> void: if _battle: _battle.set_kuwahara_radius(v))
	_ctl["hull_outline_width"] = DevControls.add_slider(vbox, "hull輪郭太さ", self, "hull_outline_width",
		0.0, 0.05, 0.001, func(v: float) -> void: if _battle: _battle.set_hull_outline_width(v))

	DevControls.add_header(vbox, "戦闘")
	_run_btn = Button.new()
	_run_btn.pressed.connect(_toggle_run)
	vbox.add_child(_run_btn)
	_update_run_btn()

	var restart := Button.new()
	restart.text = "リスタート"
	restart.pressed.connect(_spawn_battle)
	vbox.add_child(restart)

# 画風プリセット選択：battle_scene側でexportを一括更新させ、その結果をここへ読み戻して
# 個別スライダー/チェックの表示も揃える（「プリセットは初期値バンドラ、個別コントロールは微調整用」）
func _apply_style_preset(idx: int) -> void:
	style_preset_idx = idx
	if not _battle:
		return
	_battle.apply_style_preset(idx)
	_sync_fields_from_battle()
	_refresh_control_widgets()

func _sync_fields_from_battle() -> void:
	clay_hatch_strength = _battle.clay_hatch_strength
	clay_rim_strength = _battle.clay_rim_strength
	clay_light_softness = _battle.clay_light_softness
	boil_enabled = _battle.clay_boil_enabled
	outline_enabled = _battle.clay_outline_enabled
	clay_outline_thickness = _battle.clay_outline_thickness
	clay_outline_softness = _battle.clay_outline_softness
	paper_enabled = _battle.clay_paper_enabled
	clay_grain_strength = _battle.clay_grain_strength
	clay_posterize_levels = _battle.clay_posterize_levels
	tilt_enabled = _battle.tilt_enabled
	tilt_sharp_band = _battle.tilt_sharp_band
	tilt_blur = _battle.tilt_blur
	glow_enabled = _battle.glow_enabled
	glow_intensity = _battle.glow_intensity
	fog_enabled = _battle.fog_enabled
	fog_density = _battle.fog_density
	lut_enabled = _battle.lut_enabled
	lut_desaturate = _battle.lut_desaturate
	shadow_soft_enabled = _battle.shadow_soft_enabled
	shadow_blur = _battle.shadow_blur
	msaa_enabled = _battle.msaa_enabled
	contact_shadow_enabled = _battle.contact_shadow_enabled
	contact_shadow_radius = _battle.contact_shadow_radius
	contact_shadow_opacity = _battle.contact_shadow_opacity
	paint_tex_enabled = _battle.paint_tex_enabled
	paint_tex_strength = _battle.paint_tex_strength
	paint_tex_scale = _battle.paint_tex_scale
	kuwahara_enabled = _battle.kuwahara_enabled
	kuwahara_radius = _battle.kuwahara_radius
	hull_outline_enabled = _battle.hull_outline_enabled
	hull_outline_width = _battle.hull_outline_width
	shadow_distance = _battle.shadow_distance

# 各コントロールの表示値を現在のフィールド値へ合わせる（プリセット適用直後の同期用）
func _refresh_control_widgets() -> void:
	for f: String in _BOOL_FIELDS:
		if _ctl.has(f):
			(_ctl[f] as CheckBox).button_pressed = bool(get(f))
	for f: String in _FLOAT_FIELDS:
		if _ctl.has(f):
			(_ctl[f] as HSlider).value = float(get(f))

func _toggle_run() -> void:
	_running = not _running
	get_tree().paused = not _running
	_update_run_btn()

func _update_run_btn() -> void:
	if _run_btn:
		_run_btn.text = "停止" if _running else "再開"
