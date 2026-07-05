class_name BattleScene
extends Node

# Phase 4：3D ホバーでパネル行を強調する通知。BattleUI が購読して行背景を切り替える。
signal unit_3d_hovered(unit: BattleUnit, hovered: bool)

const _ENEMY_INFO_SCENE := "res://scenes/enemy_info.tscn"
const _CLEAR_SCENE      := "res://scenes/clear.tscn"
const _BG_GRASS    := preload("res://scenes/bg_grass.tscn")
const _BG_DUNGEON  := preload("res://scenes/bg_dungeon.tscn")

# 敵は gitignore 外のコミット済みモデルを使用
const _ENEMY_CHAR_PATH := "res://assets/characters/kenney/character-male-a.glb"

const _CHAR_DIR := "res://assets/kenney-mini-characters/Models/GLB format/"
const _PORTRAIT_DIR := "res://assets/portraits/"

# KayKit移行済み職（剣闘士/騎士/魔女のみ。他はKenney内蔵アニメ方式のまま）
const _KAYKIT_CHAR_DIR := "res://assets/kaykit/characters/"
const _KAYKIT_ANIM_DIR := "res://assets/kaykit/animations/"
# 合流するアニメライブラリ（ライブラリ名 → 供給元GLB）。KayKit採用キャラ全員で共通
const _KAYKIT_ANIM_LIBS: Dictionary = {
	"general": _KAYKIT_ANIM_DIR + "Rig_Medium_General.glb",
	"melee":   _KAYKIT_ANIM_DIR + "Rig_Medium_CombatMelee.glb",
	"ranged":  _KAYKIT_ANIM_DIR + "Rig_Medium_CombatRanged.glb",
}
# 職 → {idle, attack, death} クリップ名（"ライブラリ名/クリップ名"表記）
const _KAYKIT_CLIPS: Dictionary = {
	CharacterJob.Type.GLADIATOR: {"idle": "general/Idle_A", "attack": "melee/Melee_1H_Attack_Chop", "death": "general/Death_A"},
	CharacterJob.Type.KNIGHT:    {"idle": "general/Idle_A", "attack": "melee/Melee_1H_Attack_Chop", "death": "general/Death_A"},
	CharacterJob.Type.MAGE:      {"idle": "general/Idle_A", "attack": "ranged/Ranged_Magic_Spellcasting", "death": "general/Death_A"},
}

# 職業別キャラモデル（female 6職は1:1ユニーク、male 11職は5種を共有）
const _JOB_CHAR_PATHS: Dictionary = {
	CharacterJob.Type.WARRIOR:       _CHAR_DIR + "character-male-b.glb",
	CharacterJob.Type.KNIGHT:        _KAYKIT_CHAR_DIR + "Knight.glb",
	CharacterJob.Type.GLADIATOR:     _KAYKIT_CHAR_DIR + "Barbarian.glb",
	CharacterJob.Type.ADVENTURER:    _CHAR_DIR + "character-male-f.glb",
	CharacterJob.Type.MAGE:          _KAYKIT_CHAR_DIR + "Mage.glb",
	CharacterJob.Type.MONK:          _CHAR_DIR + "character-male-b.glb",
	CharacterJob.Type.DARK_KNIGHT:   _CHAR_DIR + "character-male-c.glb",
	CharacterJob.Type.ARCHER:        _CHAR_DIR + "character-male-d.glb",
	CharacterJob.Type.ILLUSIONIST:   _CHAR_DIR + "character-male-e.glb",
	CharacterJob.Type.SAMURAI:       _CHAR_DIR + "character-male-f.glb",
	CharacterJob.Type.SHAMAN:        _CHAR_DIR + "character-male-e.glb",
	CharacterJob.Type.CLERIC:        _CHAR_DIR + "character-female-a.glb",
	CharacterJob.Type.WITCH:         _CHAR_DIR + "character-female-b.glb",
	CharacterJob.Type.VALKYRIE:      _CHAR_DIR + "character-female-c.glb",
	CharacterJob.Type.SHRINE_MAIDEN: _CHAR_DIR + "character-female-d.glb",
	CharacterJob.Type.NINJA:         _CHAR_DIR + "character-female-e.glb",
	CharacterJob.Type.HOLY_KNIGHT:   _CHAR_DIR + "character-female-f.glb",
}
# 同一モデルを共有するジョブのみ albedo_color チント
const _JOB_TINTS: Dictionary = {
	CharacterJob.Type.MONK:        Color(0.78, 0.88, 1.0),   # male-b 共有 → 水色
	CharacterJob.Type.DARK_KNIGHT: Color(0.6,  0.6,  0.75),  # male-c 共有 → 紫
	CharacterJob.Type.ARCHER:      Color(0.75, 1.0,  0.75),  # male-d 共有 → 緑
	CharacterJob.Type.ILLUSIONIST: Color(0.9,  0.75, 1.0),   # male-e 共有 → 薄紫
	CharacterJob.Type.SHAMAN:      Color(0.75, 1.0,  0.85),  # male-e 共有 → 緑青
	CharacterJob.Type.SAMURAI:     Color(1.0,  0.9,  0.65),  # male-f 共有 → ゴールド
}

const HP_YELLOW_THRESHOLD := 0.5
const HP_RED_THRESHOLD    := 0.25
const HP_COLOR_GREEN  := Color(0.15, 0.80, 0.30, 1.0)
const HP_COLOR_YELLOW := Color(0.90, 0.78, 0.05, 1.0)
const HP_COLOR_RED    := Color(0.85, 0.18, 0.10, 1.0)

const ROW_NAMES := ["前", "中", "後"]

const _CAMERA_SHAKE_NOISE_SPEED := 20.0  # ノイズサンプリング速度
const _CAMERA_SHAKE_V_PHASE     := 100.0  # V チャンネル位相オフセット
const _SPARK_SPAWN_Y            := 0.7   # 火花スポーン高さ (m)

const _WEAPON_FLOAT_AMP  := 0.05  # Mage crystal 浮遊振幅 (m)
const _WEAPON_FLOAT_TIME := 1.5   # 浮遊半周期 (s)

const _WEAPON_DIR := "res://assets/quaternius-rpg-items/"
const _WEAPON_PATHS: Dictionary = {
	CharacterJob.Type.WARRIOR:       _WEAPON_DIR + "Axe_Double.fbx",
	CharacterJob.Type.KNIGHT:        _WEAPON_DIR + "Sword.fbx",
	CharacterJob.Type.GLADIATOR:     _WEAPON_DIR + "Sword.fbx",
	CharacterJob.Type.ILLUSIONIST:   _WEAPON_DIR + "Crystal1.fbx",
	CharacterJob.Type.ADVENTURER:    _WEAPON_DIR + "Sword.fbx",
	CharacterJob.Type.MONK:          _WEAPON_DIR + "Hammer_Double.fbx",
	CharacterJob.Type.CLERIC:        _WEAPON_DIR + "Hammer_Double.fbx",
	CharacterJob.Type.MAGE:          _WEAPON_DIR + "Crystal1.fbx",
	CharacterJob.Type.WITCH:         _WEAPON_DIR + "Crystal1.fbx",
	CharacterJob.Type.ARCHER:        _WEAPON_DIR + "Bow_Wooden.fbx",
	CharacterJob.Type.VALKYRIE:      _WEAPON_DIR + "Bow_Wooden.fbx",
	CharacterJob.Type.SHAMAN:        _WEAPON_DIR + "Hammer_Double.fbx",
	CharacterJob.Type.SHRINE_MAIDEN: _WEAPON_DIR + "Crystal1.fbx",
	CharacterJob.Type.SAMURAI:       _WEAPON_DIR + "Sword.fbx",
	CharacterJob.Type.NINJA:         _WEAPON_DIR + "Sword.fbx",
	CharacterJob.Type.DARK_KNIGHT:   _WEAPON_DIR + "Sword.fbx",
	CharacterJob.Type.HOLY_KNIGHT:   _WEAPON_DIR + "Hammer_Double.fbx",
}

const ACCENT_PALETTE: Array = [
	Color(0.902, 0.333, 0.227),  # 0: #E6553A
	Color(0.902, 0.635, 0.227),  # 1: #E6A23A
	Color(0.310, 0.702, 0.416),  # 2: #4FB36A
	Color(0.227, 0.627, 0.902),  # 3: #3AA0E6
	Color(0.608, 0.435, 0.902),  # 4: #9B6FE6
	Color(0.902, 0.435, 0.690),  # 5: #E66FB0
	Color(0.275, 0.780, 0.780),  # 6: #46C7C7
	Color(0.780, 0.722, 0.227),  # 7: #C7B83A
]

static func accent_color_for(index: int) -> Color:
	return ACCENT_PALETTE[index % ACCENT_PALETTE.size()] as Color

# プレイヤー職のキャラモデルをファイル単位で重複排除した一覧
# （ポートレート・ベイクツールとパネル/テストが参照する単一ソース）
static func unique_player_model_paths() -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for path: String in _JOB_CHAR_PATHS.values():
		if not seen.has(path):
			seen[path] = true
			out.append(path)
	return out

# 職→モデルファイル→事前ベイク済みポートレート PNG のパス
static func portrait_path_for_job(job: CharacterJob.Type) -> String:
	var model: String = _JOB_CHAR_PATHS.get(job, _ENEMY_CHAR_PATH)
	return _PORTRAIT_DIR + model.get_file().get_basename() + ".png"

# 共有モデルを色分けする職の tint。対象外は白（無着色）
static func job_tint_or_white(job: CharacterJob.Type) -> Color:
	return _JOB_TINTS.get(job, Color.WHITE)

# カメラ
@export var camera_target: Vector3     = Vector3(3.0, 0.0, 2.0)
@export var camera_distance: float     = 15.0
@export var camera_ortho_size: float   = 14.0
@export var char_y_offset: float       = 0.0
@export var player_char_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var enemy_char_scale: Vector3  = Vector3(1.0, 1.0, 1.0)

# 環境光・キーライト（陰影コントラスト用。明るさ総量は上げない）
@export var ambient_energy: float    = 0.35             # 0.9から大幅減：均一なベタ明かりを抑える
@export var key_light_energy: float  = 1.3              # 0.5から増：陰影をつける主役光
@export var key_light_from: Vector3  = Vector3(6.0, 7.0, 3.0)  # 光源位置（斜め強め）
@export var fog_enabled: bool        = true
@export var fog_density: float       = 0.02             # 奥を暗く沈めて手前キャラを分離

# HP表示バー（キャラ下）
@export var hp_bar_y_offset: float     = -0.15
@export var hp_bar_width: float        = 0.8
@export var hp_bar_height: float       = 0.06

# ダメージ数字
@export var dmg_font_size: int         = 48
@export var dmg_pixel_size: float      = 0.012
@export var dmg_rise: float            = 1.2
@export var dmg_duration: float        = 0.9

# クリティカルテキスト
@export var crit_font_size: int        = 48
@export var crit_duration: float       = 0.75
@export var crit_rise: float           = 0.6

# 攻撃補助エフェクト
@export var supp_font_size: int          = 48
@export var supp_duration: float         = 0.8
@export var supp_rise: float             = 0.9
@export var supp_flash_color: Color      = Color(1.0, 0.55, 0.0)
@export var supp_flash_duration: float   = 0.45
@export var supp_label_color: Color      = Color(1.0, 0.65, 0.1)
@export var supp_label_offset: Vector3   = Vector3(0.0, 1.8, 0.0)

# 防御補助エフェクト
@export var def_font_size: int           = 48
@export var def_duration: float          = 0.8
@export var def_rise: float              = 0.9
@export var def_flash_color: Color       = Color(0.2, 0.5, 1.0)
@export var def_flash_duration: float    = 0.45
@export var def_label_color: Color       = Color(0.3, 0.7, 1.0)
@export var def_label_offset: Vector3    = Vector3(0.0, 1.8, 0.0)

# 回復エフェクト
@export var heal_flash_color: Color      = Color(0.2, 1.0, 0.4)
@export var heal_flash_duration: float   = 0.35
@export var heal_label_color: Color      = Color(0.3, 1.0, 0.55)
@export var heal_row_stagger: float      = 0.15  # 列回復の各キャラ間ディレイ（秒）
@export var heal_batch_gap: float        = 0.65  # 列回復ヒーラー間ディレイ（秒）

# 被弾
@export var hit_flash_duration: float  = 0.08
@export var hit_flash_melee_color: Color  = Color(1.0, 0.15, 0.15)
@export var hit_flash_magic_color: Color  = Color(0.7, 0.15, 1.0)
@export var hit_flash_ranged_color: Color = Color(1.0, 0.85, 0.10)
@export var hit_shake_amount: float    = 0.05   # m 揺れ幅
@export var hit_knockback_dist: float  = 0.12   # m ノックバック

# 被弾パーティクル（火花）
@export var spark_color: Color            = Color(1.0, 0.65, 0.0)  # 通常ヒット（純オレンジ）
@export var spark_crit_color: Color       = Color(1.0, 1.0, 0.5)   # クリットヒット（黄白）
@export var spark_scale_min: float        = 0.5
@export var spark_scale_max: float        = 1.5
@export var spark_crit_scale_min: float   = 0.8
@export var spark_crit_scale_max: float   = 2.5
@export var spark_velocity_min: float     = 4.0
@export var spark_velocity_max: float     = 14.0
@export var spark_lifetime: float         = 0.9
@export var spark_amount: int             = 28
@export var spark_crit_amount: int        = 48

# ヒットストップ
@export_range(0.01, 1.0, 0.01) var hitstop_time_scale: float = 0.05
@export_range(0.02, 0.3,  0.01) var hitstop_duration: float  = 0.08

# カメラシェイク
@export_range(0.0, 0.5, 0.005) var shake_intensity: float      = 0.05
@export_range(0.0, 0.5, 0.005) var shake_crit_intensity: float = 0.12
@export_range(0.05, 1.0, 0.05) var shake_duration: float       = 0.25

# 撃破
@export var death_duration: float      = 0.4    # s
@export var death_tilt_deg: float      = 45.0   # °

# ローテーション
@export var rotate_duration: float      = 0.55   # s
@export var rotate_show_duration: float = 0.6   # s アニメ完了後の見せ時間

# 着地スカッシュ
@export var landing_squash_y: float        = 0.65  # 潰れ時のY軸スケール
@export var landing_squash_xz: float       = 1.2   # 潰れ時のXZ軸スケール
@export var landing_squash_in_time: float  = 0.06  # s 潰れる時間
@export var landing_squash_out_time: float = 0.18  # s 戻る時間

# 到着フラッシュ
@export var arrive_flash_color: Color      = Color(0.7, 0.85, 1.0)  # 青白い光
@export var arrive_flash_duration: float   = 0.4   # s

# 完了時列フラッシュ（前列のみ）
@export var front_row_flash_color: Color   = Color(1.0, 0.85, 0.3)  # ゴールド
@export var front_row_flash_duration: float = 0.45  # s
@export var front_row_flash_delay: float   = 0.15   # s 到着フラッシュからのずらし

# ユニット行動
@export var attack_impact_delay: float       = 0.2  # s アニメ開始→被弾エフェクト発火までの遅延
@export var unit_action_show_duration: float = 0.9  # s アニメ完了後の見せ時間
# 敵攻撃突進フォールバック（EnemyData.attack_anim が空のとき使用）
@export var enemy_lunge_dist: float          = 0.6  # m 突進距離
@export var enemy_lunge_in_time: float       = 0.15 # s 前進時間
@export var enemy_lunge_out_time: float      = 0.25 # s 後退時間
# 味方近接キャラの接近攻撃（KayKit移行・魔法/弓職は対象外でその場攻撃のまま）
@export var melee_approach_gap: float        = 2.2  # m 接近時に対象の手前で止まる距離（対象までの直線距離ベース）
@export var melee_approach_time: float       = 0.25 # s 接近Tween時間
@export var melee_return_time: float         = 0.3  # s 帰還Tween時間

# 自己回復
@export var self_heal_show_duration: float = 1.0  # s フラッシュ・数字の見せ時間

# 列回復後の間
@export var post_row_heal_show_duration: float = 0.5  # s 列回復完了→攻撃フェーズまでの間

# 戦闘終了
@export var battle_end_delay: float    = 2.5    # s

# 武器アタッチ
@export var weapon_scale: float    = 0.3
# arm-right ボーンのローカル空間における手先位置（kenney-mini スケルトンのスキニングから実測）
@export var weapon_offset: Vector3 = Vector3(-0.18, 0.18, 0.08)
# KayKit採用職（剣闘士/騎士/魔女）用：handslot.rボーンでの武器スケール/位置（要目視調整）
@export var kaykit_weapon_scale: float    = 0.3
@export var kaykit_weapon_offset: Vector3 = Vector3(-0.18, 0.18, 0.08)
# KayKit採用職の全体スケール補正（Kenneyとの身長差吸収・要目視調整）
@export var kaykit_char_scale_mult: float = 0.6

# 番号バッジ（足元）
@export var number_badge_font_size: int    = 64
@export var number_badge_pixel_size: float = 0.004
@export var number_badge_y: float          = 0.06
@export var number_badge_outline: int      = 3

# アクセントリング（足元）
@export var accent_ring_inner: float = 0.35
@export var accent_ring_outer: float = 0.45
@export var accent_ring_y: float     = 0.02
# Phase 3：パネル行ホバー時のリング強調量
@export_range(0.0, 1.0, 0.05) var ring_hover_brighten: float       = 0.5  # 白側への lerp 量
@export_range(0.0, 6.0, 0.1)  var ring_hover_emission_energy: float = 2.0  # 発光の強さ

# Phase 4：3D ホバー判定用 Area3D カプセル
# イソメトリック視差ズレ対策：y を高くすると前列判定が後列のスクリーン座標と重なるため
# リング（y≈0.02）と同じ地面すれすれに置いて各キャラのリング上にヒットボックスを一致させる
@export var hover_collider_radius: float = 0.45  # カプセル半径 (m)
@export var hover_collider_height: float = 0.95  # カプセル高さ (m)。radius*2 に近い扁平形
@export var hover_collider_y: float      = 0.15  # カプセル中心 y（地面すれすれ・リングと同高さ）

# 戦場グリッド表示
@export var grid_cell_size: Vector2      = Vector2(1.85, 1.85)
@export var grid_cell_color: Color       = Color(0.35, 0.55, 1.0, 0.12)
@export var grid_cell_y_offset: float    = 0.0
@export var grid_label_font_size: int    = 48
@export var grid_label_pixel_size: float = 0.015
@export var grid_label_color: Color      = Color(0.85, 0.92, 1.0, 0.9)
@export var grid_label_offset: Vector3   = Vector3(-1.3, 0.8, 0.0)

# クレイ（マット粘土）作風シェーダー
@export var clay_enabled: bool = true
@export var clay_shadow_tint: Color = Color(0.55, 0.42, 0.32)
@export_range(0.0, 1.0, 0.01) var clay_light_threshold: float = 0.45
@export_range(0.0, 1.0, 0.01) var clay_rim_strength: float = 0.25
@export var clay_rim_color: Color = Color(0.92, 0.96, 1.0)
@export var clay_outline_enabled: bool = true
@export_range(0.5, 4.0, 0.5) var clay_outline_thickness: float = 1.0
@export_range(0.0, 0.5, 0.01) var clay_outline_threshold: float = 0.15
@export var clay_outline_color: Color = Color(0.1, 0.06, 0.02, 0.9)

const _FLASH_CODE := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3  flash_color  : source_color = vec3(1.0, 0.15, 0.15);
void fragment() {
	ALBEDO = flash_color;
	ALPHA  = flash_amount;
}
"""

# UV.x > health_pct の部分を透明にして右から削るHPバーシェーダー
# billboardで常にカメラを向くため親ノードの回転に依存しない
const _HP_BAR_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
uniform float health_pct : hint_range(0.0, 1.0) = 1.0;
uniform vec4  bar_color  : source_color = vec4(0.15, 0.85, 0.3, 1.0);
void vertex() {
	mat4 mv = VIEW_MATRIX * MODEL_MATRIX;
	mv[0] = vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0);
	mv[1] = vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0);
	mv[2] = vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0);
	POSITION = PROJECTION_MATRIX * mv * vec4(VERTEX, 1.0);
}
void fragment() {
	if (UV.x > health_pct) { discard; }
	ALBEDO = bar_color.rgb;
}
"""

const _HP_BAR_BG_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
uniform vec4 bg_color : source_color = vec4(0.1, 0.1, 0.1, 0.8);
void vertex() {
	mat4 mv = VIEW_MATRIX * MODEL_MATRIX;
	mv[0] = vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0);
	mv[1] = vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0);
	mv[2] = vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0);
	POSITION = PROJECTION_MATRIX * mv * vec4(VERTEX, 1.0);
}
void fragment() {
	ALBEDO = bg_color.rgb;
	ALPHA = bg_color.a;
}
"""

const _SPARK_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
void fragment() { ALBEDO = COLOR.rgb; ALPHA = COLOR.a; }
"""

const _CLAY_CODE := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D albedo_tex   : source_color, hint_default_white;
uniform vec4  albedo_color    : source_color               = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4  shadow_tint     : source_color               = vec4(0.55, 0.42, 0.32, 1.0);
uniform float light_threshold : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float rim_strength    : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform vec4  rim_color       : source_color               = vec4(0.92, 0.96, 1.0, 1.0);
void fragment() {
	vec3 base  = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	ALBEDO    = base;
	ROUGHNESS = 1.0;
	METALLIC  = 0.0;
	SPECULAR  = 0.0;
	float rim  = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.0);
	EMISSION   = rim_color.rgb * rim * rim_strength;
}
void light() {
	float NdotL  = max(0.0, dot(NORMAL, LIGHT));
	float in_lit = smoothstep(light_threshold - 0.04, light_threshold + 0.04, NdotL);
	vec3  surface = mix(ALBEDO * shadow_tint.rgb, ALBEDO, in_lit);
	DIFFUSE_LIGHT += surface * ATTENUATION * LIGHT_COLOR;
}
"""

const _OUTLINE_CODE := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float thickness : hint_range(0.5, 4.0, 0.5) = 1.0;
uniform float threshold : hint_range(0.0, 0.5, 0.01) = 0.15;
uniform vec4  line_color : source_color = vec4(0.1, 0.06, 0.02, 0.9);
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec2 d   = SCREEN_PIXEL_SIZE * thickness;
	vec4 src = texture(screen_tex, SCREEN_UV);
	float c  = luma(src.rgb);
	float r  = luma(texture(screen_tex, SCREEN_UV + vec2( d.x, 0.0)).rgb);
	float l  = luma(texture(screen_tex, SCREEN_UV + vec2(-d.x, 0.0)).rgb);
	float u  = luma(texture(screen_tex, SCREEN_UV + vec2(0.0,  d.y)).rgb);
	float dn = luma(texture(screen_tex, SCREEN_UV + vec2(0.0, -d.y)).rgb);
	float edge    = max(max(abs(c-r), abs(c-l)), max(abs(c-u), abs(c-dn)));
	float outline = step(threshold, edge);
	COLOR = mix(src, vec4(line_color.rgb, 1.0), outline * line_color.a);
}
"""

var _flash_shader: Shader
var _hp_bar_shader: Shader
var _hp_bar_bg_shader: Shader
var _spark_shader_mat: ShaderMaterial
var _spark_mesh: QuadMesh
var _clay_shader: Shader

@onready var _camera: Camera3D           = $World/Camera3D
@onready var _env_node: WorldEnvironment = $World/WorldEnvironment
@onready var _light: DirectionalLight3D  = $World/DirectionalLight3D
@onready var _player_grid: Node3D        = $World/PlayerGrid
@onready var _enemy_grid: Node3D         = $World/EnemyGrid
@onready var _characters: Node3D         = $World/Characters
@onready var _background: Node3D         = $World/Background
@onready var _canvas: CanvasLayer        = $CanvasLayer
@onready var _battle_ui: BattleUI        = $CanvasLayer/BattleUI

var _manager: BattleManager
var _unit_nodes: Dictionary = {}    # BattleUnit → Node3D
var _unit_anims: Dictionary = {}    # BattleUnit → AnimationPlayer
var _hp_bars: Dictionary = {}       # BattleUnit → ShaderMaterial (fg)
var _unit_rings: Dictionary = {}    # BattleUnit → StandardMaterial3D（アクセントリング。Phase3ホバー用）
var _ring_base_colors: Dictionary = {}  # BattleUnit → Color（リング基準色。ホバー解除時の復帰用）
var _unit_areas: Dictionary = {}    # BattleUnit → Area3D（Phase4：3Dマウスピッキング用）
var _petrified_mats: Dictionary = {}  # BattleUnit → { MeshInstance3D → Array } 石化前マテリアル退避
var _label_font: Font = null
var _row_heal_units: Dictionary = {}     # BattleUnit → bool（列回復アニメ処理中）
var _row_heal_queue: Array = []          # 待機中の列回復バッチ
var _row_heal_animating: bool = false    # _process_row_heal_queue が動いているか
var _shake_active: bool = false          # カメラシェイク二重起動防止
var _unit_action_anim_pending: bool = false  # 多段ヒット時の二重 emit 防止
var _unit_melee_hit_progress: Dictionary = {}  # BattleUnit → 現在のヒット数（近接接近攻撃の往復1回化に使用）

func _ready() -> void:
	_flash_shader = Shader.new()
	_flash_shader.code = _FLASH_CODE
	_hp_bar_shader = Shader.new()
	_hp_bar_shader.code = _HP_BAR_CODE
	_hp_bar_bg_shader = Shader.new()
	_hp_bar_bg_shader.code = _HP_BAR_BG_CODE
	var spark_shader := Shader.new()
	spark_shader.code = _SPARK_CODE
	_spark_shader_mat = ShaderMaterial.new()
	_spark_shader_mat.shader = spark_shader
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.1, 0.1)
	_spark_mesh.material = _spark_shader_mat
	if clay_enabled:
		_clay_shader = Shader.new()
		_clay_shader.code = _CLAY_CODE
	const JP := "res://assets/fonts/851CHIKARA-DZUYOKU_kanaA_004.ttf"
	const EN := "res://assets/fonts/Cinzel-Regular.ttf"
	if ResourceLoader.exists(JP):
		var jf := load(JP) as FontFile
		if jf and ResourceLoader.exists(EN):
			jf.set_fallbacks([load(EN) as Font])
		_label_font = jf
	_setup_world()
	_setup_background()
	_setup_outline()
	_start_battle()

func _setup_background() -> void:
	var is_grass: bool = GameState.battle_index < 2
	var scene: PackedScene = _BG_GRASS if is_grass else _BG_DUNGEON
	_background.add_child(scene.instantiate())
	if is_grass:
		var env: Environment = _env_node.environment
		env.background_color = Color(0.45, 0.68, 0.92)

func _setup_world() -> void:
	get_viewport().physics_object_picking = true
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = camera_ortho_size
	var cam_pos := camera_target + Vector3(1.0, 1.0, 1.0).normalized() * camera_distance
	_camera.look_at_from_position(cam_pos, camera_target, Vector3.UP)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.75)
	env.ambient_light_energy = ambient_energy
	env.fog_enabled    = fog_enabled
	env.fog_density    = fog_density
	env.fog_light_color = Color(0.05, 0.04, 0.08)
	env.tonemap_mode   = Environment.TONE_MAPPER_AGX
	_env_node.environment = env

	_light.look_at_from_position(key_light_from, Vector3.ZERO, Vector3.UP)
	_light.light_energy = key_light_energy
	_setup_grid_overlay()

func _setup_outline() -> void:
	if not clay_outline_enabled:
		return
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 全画面オーバーレイが3Dピッキング(Area3Dホバー)を吸収するのを防ぐ
	var shader := Shader.new()
	shader.code = _OUTLINE_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("thickness",  clay_outline_thickness)
	mat.set_shader_parameter("threshold",  clay_outline_threshold)
	mat.set_shader_parameter("line_color", clay_outline_color)
	rect.material = mat
	_canvas.add_child(rect)
	_canvas.move_child(rect, 0)  # UI より前（奥）に描画

func _setup_grid_overlay() -> void:
	for row: int in RotationGrid.ROW_COUNT:
		var m0: Marker3D = null
		for col: int in RotationGrid.MAX_PER_ROW:
			var m: Marker3D = _get_player_marker(row, col)
			if m:
				if col == 0:
					m0 = m
				var tile := _make_grid_cell(
					m.position + Vector3(0.0, grid_cell_y_offset, 0.0),
					grid_cell_size, grid_cell_color)
				_player_grid.add_child(tile)
		if m0:
			var lbl := _make_row_label(ROW_NAMES[row],
				m0.position + grid_label_offset,
				grid_label_font_size, grid_label_pixel_size, grid_label_color)
			if _label_font:
				lbl.font = _label_font
			_player_grid.add_child(lbl)

func _start_battle() -> void:
	var bgm := AudioManager.BGM_BATTLE3 if GameState.battle_index >= 2 else AudioManager.BGM_BATTLE12
	AudioManager.play_bgm(bgm)
	_manager = BattleManager.new()
	add_child(_manager)
	_manager.battle_started.connect(_on_battle_started)
	_manager.unit_acted.connect(_on_unit_acted)
	_manager.unit_healed.connect(_on_unit_healed)
	_manager.unit_died.connect(_on_unit_died)
	_manager.rotated.connect(_on_rotated)
	_manager.phase_started.connect(_on_phase_started)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.attack_support_used.connect(_on_attack_support_used)
	_manager.defense_support_used.connect(_on_defense_support_used)
	_manager.enemy_shield_activated.connect(_on_enemy_shield_activated)
	_manager.enemy_first_attack_activated.connect(_on_enemy_first_attack_activated)
	_manager.unit_petrified.connect(_on_unit_petrified)
	_manager.unit_stone_cleared.connect(_on_unit_stone_cleared)
	_manager.row_heal_batch.connect(_on_row_heal_batch)
	_battle_ui.setup(_manager)
	_battle_ui.unit_row_hovered.connect(_on_row_hovered)
	unit_3d_hovered.connect(_battle_ui._on_unit_3d_hovered)
	_manager.start_battle(GameState.get_battle_entries(), GameState.get_battle_enemy())

# ── ヘルパー ─────────────────────────────────────────────────────

func _get_player_marker(row: int, col: int) -> Marker3D:
	return _player_grid.get_node_or_null("Slot_r%d_c%d" % [row, col]) as Marker3D

func _get_enemy_marker(slot: int) -> Marker3D:
	return _enemy_grid.get_node_or_null("ESlot_%d" % slot) as Marker3D

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, result)

func _setup_flash(ch: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		var mat := ShaderMaterial.new()
		mat.shader = _flash_shader
		mat.set_shader_parameter("flash_amount", 0.0)
		mesh.material_overlay = mat

func _do_flash(ch: Node3D, color: Color = Color(1.0, 0.15, 0.15), duration: float = -1.0) -> void:
	var dur := duration if duration > 0.0 else hit_flash_duration
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		var mat: ShaderMaterial = mesh.material_overlay as ShaderMaterial
		if not mat:
			continue
		mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))
		mat.set_shader_parameter("flash_amount", 1.0)
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
			1.0, 0.0, dur)

func _do_hitstop() -> void:
	Engine.time_scale = hitstop_time_scale
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _do_camera_shake(intensity: float) -> void:
	if _shake_active:
		return
	_shake_active = true
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	var elapsed: float = 0.0
	while elapsed < shake_duration:
		await get_tree().process_frame
		if not is_instance_valid(_camera):
			_shake_active = false
			return
		elapsed += get_process_delta_time()
		var fade := 1.0 - clampf(elapsed / shake_duration, 0.0, 1.0)
		var s := elapsed * _CAMERA_SHAKE_NOISE_SPEED
		_camera.h_offset = noise.get_noise_1d(s) * intensity * fade
		_camera.v_offset = noise.get_noise_1d(s + _CAMERA_SHAKE_V_PHASE) * intensity * fade
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_shake_active = false

func _do_hit_effects(is_crit: bool) -> void:
	await _do_hitstop()
	_do_camera_shake(shake_crit_intensity if is_crit else shake_intensity)

# 近接接近攻撃の対象外（その場で詠唱/射撃する職）。SE・被弾フラッシュ色と同じ分類
static func _is_ranged_or_magic_job(job: CharacterJob.Type) -> bool:
	match job:
		CharacterJob.Type.ARCHER, CharacterJob.Type.VALKYRIE, \
		CharacterJob.Type.MAGE, CharacterJob.Type.WITCH, CharacterJob.Type.ILLUSIONIST, \
		CharacterJob.Type.SHAMAN, CharacterJob.Type.SHRINE_MAIDEN:
			return true
		_:
			return false

static func _resolve_attack_se(attacker: BattleUnit) -> String:
	if attacker.side == BattleUnit.Side.ENEMY:
		return AudioManager.SE_PUNCH
	var cd := attacker.source_data as CharacterData
	if not cd:
		return AudioManager.SE_PUNCH
	match cd.job:
		CharacterJob.Type.ARCHER, CharacterJob.Type.VALKYRIE:
			return AudioManager.SE_ARROW
		CharacterJob.Type.MAGE, CharacterJob.Type.WITCH, CharacterJob.Type.ILLUSIONIST, \
		CharacterJob.Type.SHAMAN, CharacterJob.Type.SHRINE_MAIDEN:
			return AudioManager.SE_MAGIC
		CharacterJob.Type.MONK, CharacterJob.Type.CLERIC, CharacterJob.Type.WARRIOR, \
		CharacterJob.Type.HOLY_KNIGHT:
			return AudioManager.SE_PUNCH
		_:
			return AudioManager.SE_SLASH

static func _resolve_hit_flash_color(attacker: BattleUnit,
		melee_color: Color, magic_color: Color, ranged_color: Color) -> Color:
	if attacker.side == BattleUnit.Side.ENEMY:
		return melee_color
	var cd := attacker.source_data as CharacterData
	if not cd:
		return melee_color
	match cd.job:
		CharacterJob.Type.ARCHER, CharacterJob.Type.VALKYRIE:
			return ranged_color
		CharacterJob.Type.MAGE, CharacterJob.Type.WITCH, CharacterJob.Type.ILLUSIONIST, CharacterJob.Type.SHAMAN, CharacterJob.Type.SHRINE_MAIDEN:
			return magic_color
	return melee_color

static func _make_grid_cell(pos: Vector3, size: Vector2, cell_color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cell_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = pos
	return mi

static func _make_label3d(text: String, font_size: int, pixel_size: float,
		label_color: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.pixel_size = pixel_size
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = label_color
	return lbl

static func _make_row_label(text: String, pos: Vector3, font_size: int,
		pixel_size: float, label_color: Color) -> Label3D:
	var lbl := _make_label3d(text, font_size, pixel_size, label_color)
	lbl.outline_size = 4
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	lbl.position = pos
	return lbl

func _spawn_floating_label(pos: Vector3, text: String, color: Color) -> void:
	var lbl := _make_label3d(text, dmg_font_size, dmg_pixel_size, color)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + Vector3(randf_range(-0.2, 0.2), 1.5, 0.0)
	lbl.scale = Vector3.ZERO
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	_animate_floating_label(lbl, dmg_rise, dmg_duration)

func _spawn_critical_label(pos: Vector3) -> void:
	var lbl := _make_label3d("Critical!", crit_font_size, dmg_pixel_size, Color(1.0, 0.75, 0.0))
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	lbl.position = pos + Vector3(0.0, 2.2, 0.0)
	lbl.scale = Vector3.ZERO
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3(1.5, 1.5, 1.5), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position",
		lbl.position + Vector3(0.0, crit_rise, 0.0), crit_duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,
		crit_duration * 0.5).set_delay(crit_duration * 0.5)
	await get_tree().create_timer(crit_duration + 0.1).timeout
	if is_instance_valid(lbl):
		lbl.queue_free()

static func _make_support_label(text: String, pos: Vector3, font_size: int,
		pixel_size: float, label_color: Color, offset: Vector3) -> Label3D:
	var lbl := _make_label3d(text, font_size, pixel_size, label_color)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + offset
	lbl.scale = Vector3.ZERO
	return lbl

func _animate_floating_label(lbl: Label3D, rise: float, duration: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position",
		lbl.position + Vector3(0.0, rise, 0.0), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,
		duration * 0.55).set_delay(duration * 0.45)
	await get_tree().create_timer(duration + 0.1).timeout
	if is_instance_valid(lbl):
		lbl.queue_free()

func _spawn_atk_support_label(pos: Vector3) -> void:
	var lbl := BattleScene._make_support_label(
		"ATK Up", pos, supp_font_size, dmg_pixel_size, supp_label_color, supp_label_offset)
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	_animate_floating_label(lbl, supp_rise, supp_duration)

func _spawn_def_support_label(pos: Vector3) -> void:
	var lbl := BattleScene._make_support_label(
		"DEF Up", pos, def_font_size, dmg_pixel_size, def_label_color, def_label_offset)
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	_animate_floating_label(lbl, def_rise, def_duration)

func _make_bg_bar() -> MeshInstance3D:
	# fg（health_pct シェーダー）と同じ自前ビルボード計算のシェーダーを使う。
	# 標準billboard_mode（Godot組込み）だとスケール反映の挙動がfgのシェーダーと食い違い、
	# model_scaleを持つ敵（等身大以外）でbgがfgより短く見えるズレが出るため統一した。
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(hp_bar_width, hp_bar_height)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _hp_bar_bg_shader
	mat.set_shader_parameter("bg_color", Color(0.1, 0.1, 0.1, 0.8))
	mat.render_priority = 1
	mi.material_override = mat
	return mi

func _spawn_hp_bar(ch: Node3D, unit: BattleUnit) -> void:
	var bg := _make_bg_bar()
	bg.position.y = hp_bar_y_offset
	ch.add_child(bg)

	var fg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(hp_bar_width, hp_bar_height)
	fg.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _hp_bar_shader
	mat.set_shader_parameter("health_pct", 1.0)
	mat.set_shader_parameter("bar_color", Color(0.15, 0.85, 0.3, 1.0))
	mat.render_priority = 2
	fg.material_override = mat
	fg.position.y = hp_bar_y_offset
	ch.add_child(fg)

	_hp_bars[unit] = mat  # ShaderMaterial を保持してパラメータを更新する

func _update_hp_bar(unit: BattleUnit) -> void:
	var mat: ShaderMaterial = _hp_bars.get(unit) as ShaderMaterial
	if not mat:
		return
	var pct := clampf(float(unit.hp) / float(unit.hp_max), 0.0, 1.0)
	mat.set_shader_parameter("health_pct", pct)
	mat.set_shader_parameter("bar_color", _get_hp_color(pct))

func _get_hp_color(pct: float) -> Color:
	if pct < HP_RED_THRESHOLD:
		return HP_COLOR_RED
	if pct < HP_YELLOW_THRESHOLD:
		return HP_COLOR_YELLOW
	return HP_COLOR_GREEN

static func _resolve_char_path(unit: BattleUnit) -> String:
	var cd := unit.source_data as CharacterData
	if not cd:
		return _ENEMY_CHAR_PATH
	return _JOB_CHAR_PATHS.get(cd.job, _ENEMY_CHAR_PATH)

# プレイヤーの idle/attack/death クリップ名。KayKit採用職は_KAYKIT_CLIPS、
# それ以外はKenney内蔵アニメの固定名（idle / attack-melee-right / die）
static func _resolve_player_anim_clip(unit: BattleUnit, kind: String) -> String:
	var cd := unit.source_data as CharacterData
	if cd and _KAYKIT_CLIPS.has(cd.job):
		return (_KAYKIT_CLIPS[cd.job] as Dictionary).get(kind, "")
	match kind:
		"attack": return "attack-melee-right"
		"death":  return "die"
		_:        return "idle"

func _tint_char(ch: Node3D, tint: Color) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		if not mesh.mesh:
			continue
		for i: int in range(mesh.mesh.get_surface_count()):
			var over: Material = mesh.get_surface_override_material(i)
			if over is ShaderMaterial:
				(over as ShaderMaterial).set_shader_parameter("albedo_color", tint)
				continue
			var base_mat: Material = over if over else mesh.mesh.surface_get_material(i)
			if base_mat is StandardMaterial3D:
				var tinted: StandardMaterial3D = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				tinted.albedo_color = tint
				mesh.set_surface_override_material(i, tinted)

func _apply_clay_shader(ch: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	for mesh: MeshInstance3D in meshes:
		if not mesh.mesh:
			continue
		for i: int in range(mesh.mesh.get_surface_count()):
			var orig_mat: Material = mesh.get_surface_override_material(i)
			if not orig_mat:
				orig_mat = mesh.mesh.surface_get_material(i)
			var base_color := Color.WHITE
			var base_tex: Texture2D = null
			if orig_mat is StandardMaterial3D:
				var sm := orig_mat as StandardMaterial3D
				base_color = sm.albedo_color
				base_tex   = sm.albedo_texture
			var mat := ShaderMaterial.new()
			mat.shader = _clay_shader
			mat.set_shader_parameter("albedo_tex",      base_tex)
			mat.set_shader_parameter("albedo_color",    base_color)
			mat.set_shader_parameter("shadow_tint",     clay_shadow_tint)
			mat.set_shader_parameter("light_threshold", clay_light_threshold)
			mat.set_shader_parameter("rim_strength",    clay_rim_strength)
			mat.set_shader_parameter("rim_color",       clay_rim_color)
			mesh.set_surface_override_material(i, mat)

func _spawn_char(marker: Marker3D, y_rot: float, scale: Vector3, char_path: String,
		idle_anim_name: String = "idle") -> Node3D:
	var res: PackedScene = load(char_path)
	if not res:
		return null
	var ch: Node3D = res.instantiate()
	ch.rotation_degrees.y = y_rot
	ch.scale = scale
	ch.position = marker.global_position + Vector3(0.0, char_y_offset, 0.0)
	_characters.add_child(ch)
	var anim: AnimationPlayer
	if char_path.begins_with(_KAYKIT_CHAR_DIR):
		anim = _build_kaykit_anim_player(ch)
	else:
		anim = ch.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation(idle_anim_name):
		anim.get_animation(idle_anim_name).loop_mode = Animation.LOOP_LINEAR
		anim.play(idle_anim_name)
	_setup_flash(ch)
	if clay_enabled:
		_apply_clay_shader(ch)
	return ch

# KayKit：本体GLBにアニメを内蔵していないため、新規AnimationPlayerをキャラルート直下に足し
# _KAYKIT_ANIM_LIBS の各GLBからライブラリを合流させる（スパイクで検証済みのレシピ）
static func _build_kaykit_anim_player(ch: Node3D) -> AnimationPlayer:
	var anim := AnimationPlayer.new()
	# add_child()はforce_readable_name省略時「@AnimationPlayer@123」のような内部名を
	# 付ける（find_child("AnimationPlayer")で見つからなくなる）ため明示的に命名する
	anim.name = "AnimationPlayer"
	ch.add_child(anim)
	anim.root_node = anim.get_path_to(ch)
	for lib_name: String in _KAYKIT_ANIM_LIBS:
		var src_scene: PackedScene = load(_KAYKIT_ANIM_LIBS[lib_name] as String)
		if not src_scene:
			continue
		var src: Node3D = src_scene.instantiate()
		var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src_ap:
			var libs: PackedStringArray = src_ap.get_animation_library_list()
			if not libs.is_empty():
				anim.add_animation_library(lib_name, src_ap.get_animation_library(libs[0]))
		src.queue_free()
	return anim

func _attach_weapon(ch: Node3D, unit: BattleUnit) -> void:
	var cd := unit.source_data as CharacterData
	if not cd:
		return
	var path: String = _WEAPON_PATHS.get(cd.job, "")
	if path.is_empty():
		return
	var is_kaykit: bool = (_JOB_CHAR_PATHS.get(cd.job, "") as String).begins_with(_KAYKIT_CHAR_DIR)
	var bone_name: String = "handslot.r" if is_kaykit else "arm-right"
	var skeleton: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton or skeleton.find_bone(bone_name) == -1:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var weapon_scene: PackedScene = load(path)
	if not weapon_scene:
		return
	var weapon: Node3D = weapon_scene.instantiate() as Node3D
	weapon.scale = Vector3.ONE * (kaykit_weapon_scale if is_kaykit else weapon_scale)
	weapon.position = kaykit_weapon_offset if is_kaykit else weapon_offset
	attachment.add_child(weapon)
	if cd.job == CharacterJob.Type.MAGE:
		var start_y := weapon.position.y
		var tw := create_tween().set_loops()
		tw.tween_property(weapon, "position:y", start_y + _WEAPON_FLOAT_AMP, _WEAPON_FLOAT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(weapon, "position:y", start_y - _WEAPON_FLOAT_AMP, _WEAPON_FLOAT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_number_badge(ch: Node3D, number: int) -> void:
	var lbl := _make_label3d(str(number), number_badge_font_size, number_badge_pixel_size, Color.WHITE)
	lbl.outline_size = number_badge_outline
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	lbl.position = Vector3(0.0, number_badge_y, 0.0)
	if _label_font:
		lbl.font = _label_font
	ch.add_child(lbl)

func _spawn_accent_ring(ch: Node3D, unit: BattleUnit, accent: Color) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = accent_ring_inner
	torus.outer_radius = accent_ring_outer
	mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(0.0, accent_ring_y, 0.0)
	ch.add_child(mi)
	_unit_rings[unit] = mat
	_ring_base_colors[unit] = accent

# Phase 4：プレイヤーキャラに Area3D を付けてマウスホバーを検出する
func _spawn_hover_area(ch: Node3D, unit: BattleUnit) -> void:
	var area := Area3D.new()
	area.position = Vector3(0.0, hover_collider_y, 0.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = hover_collider_radius
	cap.height = hover_collider_height
	col.shape = cap
	area.add_child(col)
	area.mouse_entered.connect(_on_unit_area_entered.bind(unit))
	area.mouse_exited.connect(_on_unit_area_exited.bind(unit))
	ch.add_child(area)
	_unit_areas[unit] = area

func _on_unit_area_entered(unit: BattleUnit) -> void:
	unit_3d_hovered.emit(unit, true)

func _on_unit_area_exited(unit: BattleUnit) -> void:
	unit_3d_hovered.emit(unit, false)

# Phase 3：パネル行ホバーで対応ユニットの足元リングを明るく光らせる／戻す
func _on_row_hovered(unit: BattleUnit, hovered: bool) -> void:
	var mat: StandardMaterial3D = _unit_rings.get(unit) as StandardMaterial3D
	if not mat:
		return
	var base: Color = _ring_base_colors.get(unit, mat.albedo_color)
	if hovered:
		mat.albedo_color = base.lerp(Color.WHITE, ring_hover_brighten)
		mat.emission_enabled = true
		mat.emission = base
		mat.emission_energy_multiplier = ring_hover_emission_energy
	else:
		mat.albedo_color = base
		mat.emission_enabled = false

func _spawn_hit_sparks(pos: Vector3, is_crit: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.position = pos + Vector3(0.0, _SPARK_SPAWN_Y, 0.0)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = spark_lifetime
	particles.amount = spark_crit_amount if is_crit else spark_amount

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = spark_velocity_min
	mat.initial_velocity_max = spark_velocity_max
	mat.gravity = Vector3(0.0, -8.0, 0.0)
	mat.scale_min = spark_crit_scale_min if is_crit else spark_scale_min
	mat.scale_max = spark_crit_scale_max if is_crit else spark_scale_max

	var color := spark_crit_color if is_crit else spark_color
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	particles.draw_pass_1 = _spark_mesh
	particles.process_material = mat

	_characters.add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(spark_lifetime + 0.3).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _spawn_death_particles(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.position = pos
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 1.2
	particles.amount = 24

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0.0, -4.0, 0.0)
	mat.scale_min = 0.06
	mat.scale_max = 0.12

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.5, 0.1, 1.0))
	gradient.set_color(1, Color(1.0, 0.15, 0.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = mesh
	particles.process_material = mat

	_characters.add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

# ── Signal handlers ──────────────────────────────────────────────

func _on_battle_started(pg: RotationGrid, eg: RotationGrid) -> void:
	var player_units := pg.get_all_alive()
	for i: int in player_units.size():
		var unit: BattleUnit = player_units[i]
		var m: Marker3D = _get_player_marker(unit.row, unit.col)
		if m:
			var char_path := _resolve_char_path(unit)
			var char_scale := player_char_scale * kaykit_char_scale_mult \
				if char_path.begins_with(_KAYKIT_CHAR_DIR) else player_char_scale
			var ch := _spawn_char(m, 180.0, char_scale, char_path, _resolve_player_anim_clip(unit, "idle"))
			if not ch:
				continue
			_unit_nodes[unit] = ch
			_unit_anims[unit] = ch.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_spawn_hp_bar(ch, unit)
			_attach_weapon(ch, unit)
			var cd := unit.source_data as CharacterData
			if cd and _JOB_TINTS.has(cd.job):
				_tint_char(ch, _JOB_TINTS[cd.job] as Color)
			var accent := accent_color_for(i)
			_spawn_number_badge(ch, i + 1)
			_spawn_accent_ring(ch, unit, accent)
			_spawn_hover_area(ch, unit)
	for unit: BattleUnit in eg.get_all_alive():
		var m: Marker3D = _get_enemy_marker(0)
		if m:
			var ed := unit.source_data as EnemyData
			var e_path  := ed.model_path if ed and not ed.model_path.is_empty() else _ENEMY_CHAR_PATH
			var e_idle  := ed.idle_anim  if ed else "idle"
			var _ms := ed.battle_model_scale if (ed and ed.battle_model_scale > 0.0) else (ed.model_scale if ed else 1.0)
			var e_scale := enemy_char_scale * _ms
			var ch := _spawn_char(m, 0.0, e_scale, e_path, e_idle)
			if not ch:
				continue
			_unit_nodes[unit] = ch
			_unit_anims[unit] = ch.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_spawn_hp_bar(ch, unit)

func _on_unit_acted(attacker: BattleUnit, target: BattleUnit,
		dmg: int, is_crit: bool) -> void:
	var ch_a: Node3D = _unit_nodes.get(attacker) as Node3D
	var ch_t: Node3D = _unit_nodes.get(target) as Node3D
	var anim_a: AnimationPlayer = _unit_anims.get(attacker) as AnimationPlayer
	var dir: Vector3 = Vector3(1, 0, 0) if attacker.side == BattleUnit.Side.PLAYER \
		else Vector3(-1, 0, 0)
	var origin: Vector3 = ch_a.position if ch_a else Vector3.ZERO

	# 近接接近攻撃：魔法/弓職とNPCは対象外（その場で攻撃）。多段ヒットは
	# 1ヒット目で接近・最終ヒットで帰還し、往復は1アクションにつき1回にする
	var cd_a := attacker.source_data as CharacterData
	var is_melee_approach := attacker.side == BattleUnit.Side.PLAYER and ch_a != null \
		and cd_a != null and not _is_ranged_or_magic_job(cd_a.job)
	var melee_hit_index := 0
	var melee_is_last_hit := true
	if is_melee_approach:
		melee_hit_index = _unit_melee_hit_progress.get(attacker, 0) + 1
		_unit_melee_hit_progress[attacker] = melee_hit_index
		melee_is_last_hit = melee_hit_index >= attacker.attack_hits or not target.is_alive

	# 攻撃アニメ（GLB 内蔵）または Tween 突進（敵フォールバック）
	var idle_anim: String = "idle"
	var has_atk_anim := false
	var lunge_tween: Tween = null

	if attacker.side == BattleUnit.Side.PLAYER:
		if is_melee_approach and melee_hit_index == 1 and ch_t:
			# 元の立ち位置→対象への直線上で、対象の手前 gap m の点へ向かう
			# （軸固定オフセットだと対象と同じ奥行きまで寄ってしまい、見下ろしカメラで
			#   対象の影・シルエットに隠れて攻撃が見えなくなる）
			var to_target: Vector3 = ch_t.position - origin
			var travel_dist: float = to_target.length()
			var approach_dir: Vector3 = to_target / travel_dist if travel_dist > 0.001 else dir
			var approach_point: Vector3 = origin + approach_dir * max(travel_dist - melee_approach_gap, 0.0)
			var approach_tween := create_tween()
			approach_tween.tween_property(ch_a, "position", approach_point, melee_approach_time) \
				.set_ease(Tween.EASE_OUT)
			await approach_tween.finished
		idle_anim = _resolve_player_anim_clip(attacker, "idle")
		var atk_anim := _resolve_player_anim_clip(attacker, "attack")
		if is_instance_valid(anim_a) and anim_a.has_animation(atk_anim):
			anim_a.play(atk_anim)
			has_atk_anim = true
	else:
		var ed := attacker.source_data as EnemyData
		idle_anim = ed.idle_anim if ed else "idle"
		var e_atk := ed.attack_anim if ed else ""
		if not e_atk.is_empty() and is_instance_valid(anim_a) and anim_a.has_animation(e_atk):
			anim_a.play(e_atk)
			has_atk_anim = true
		elif ch_a:
			# Tween 突進フォールバック：前進→後退
			lunge_tween = create_tween()
			lunge_tween.tween_property(ch_a, "position",
				origin + dir * enemy_lunge_dist, enemy_lunge_in_time).set_ease(Tween.EASE_OUT)
			lunge_tween.tween_property(ch_a, "position",
				origin, enemy_lunge_out_time).set_ease(Tween.EASE_IN)

	# 振り下ろしタイミングまで待機してから被弾エフェクトを発火
	if attack_impact_delay > 0.0:
		await get_tree().create_timer(attack_impact_delay).timeout

	var hit_tween: Tween = null
	# 被弾：ダメージ数字 + flash + 揺れ + ノックバック
	if ch_t:
		var dmg_text := "-%d" % dmg if dmg > 0 else "0"
		var dmg_color := Color(1.0, 0.85, 0.15) if is_crit else Color(1.0, 0.92, 0.85)
		_spawn_floating_label(ch_t.global_position, dmg_text, dmg_color)
		if is_crit:
			_spawn_critical_label(ch_t.global_position)
		_update_hp_bar(target)
		_do_flash(ch_t, _resolve_hit_flash_color(attacker,
			hit_flash_melee_color, hit_flash_magic_color, hit_flash_ranged_color))
		_do_hit_effects(is_crit)
		_spawn_hit_sparks(ch_t.global_position, is_crit)
		var _se := AudioManager.SE_CRITICAL if is_crit else _resolve_attack_se(attacker)
		AudioManager.play_se(_se, 10.0 if _se == AudioManager.SE_ARROW else 0.0)
		var t_origin := ch_t.position
		var kb_dir := -dir
		var shake := Vector3(randf_range(-hit_shake_amount, hit_shake_amount),
			0.0, randf_range(-hit_shake_amount, hit_shake_amount))
		var tw_t := create_tween()
		tw_t.tween_property(ch_t, "position",
			t_origin + kb_dir * hit_knockback_dist + shake,
			hit_flash_duration).set_ease(Tween.EASE_OUT)
		tw_t.tween_property(ch_t, "position", t_origin, 0.12).set_ease(Tween.EASE_IN)
		hit_tween = tw_t

	# 多段ヒット時は最初のコルーチンだけが emit を担当する
	if _unit_action_anim_pending:
		return
	_unit_action_anim_pending = true

	if has_atk_anim and is_instance_valid(anim_a):
		while is_instance_valid(anim_a) and anim_a.is_playing():
			await get_tree().process_frame
		if is_instance_valid(anim_a):
			anim_a.play(idle_anim)
	elif lunge_tween:
		await lunge_tween.finished
	elif hit_tween:
		await hit_tween.finished

	if is_melee_approach and melee_is_last_hit:
		_unit_melee_hit_progress.erase(attacker)
		if ch_a:
			var return_tween := create_tween()
			return_tween.tween_property(ch_a, "position", origin, melee_return_time) \
				.set_ease(Tween.EASE_IN)
			await return_tween.finished

	await get_tree().create_timer(unit_action_show_duration).timeout
	_unit_action_anim_pending = false
	if is_instance_valid(_manager):
		_manager.unit_action_anim_done.emit()

func _on_unit_died(unit: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_DIE)
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	if not ch:
		return
	_spawn_death_particles(ch.global_position)
	var anim: AnimationPlayer = _unit_anims.get(unit) as AnimationPlayer
	var death_anim_name := "die"
	if unit.side == BattleUnit.Side.ENEMY:
		var ed := unit.source_data as EnemyData
		if ed:
			death_anim_name = ed.death_anim
	else:
		death_anim_name = _resolve_player_anim_clip(unit, "death")
	if is_instance_valid(anim) and anim.has_animation(death_anim_name):
		anim.play(death_anim_name)
	else:
		# フォールバック：GLB アニメが取れない場合の Tween
		var tw := create_tween()
		tw.tween_property(ch, "scale", Vector3(1.5, 0.5, 1.5), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			var tw2 := create_tween().set_parallel(true)
			tw2.tween_property(ch, "scale", Vector3.ZERO, death_duration).set_ease(Tween.EASE_IN)
			tw2.tween_property(ch, "rotation_degrees:z", death_tilt_deg, death_duration))

func _on_unit_healed(unit: BattleUnit, amount: int) -> void:
	_update_hp_bar(unit)
	if _row_heal_units.has(unit):
		return  # 視覚・音は _on_row_heal_batch が担当
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	if ch:
		var text := "+%d" % amount if amount > 0 else "MAX"
		_spawn_floating_label(ch.global_position, text, heal_label_color)
		_do_flash(ch, heal_flash_color, heal_flash_duration)
		AudioManager.play_se(AudioManager.SE_HEAL_SELF)

func _on_rotated() -> void:
	AudioManager.play_se(AudioManager.SE_ROTATE_SELECT)
	# ローテーション時に石化ビジュアルを一括クリア（Managerは unit_stone_cleared を出さないため）
	for unit: BattleUnit in _petrified_mats.keys().duplicate():
		var ch: Node3D = _unit_nodes.get(unit) as Node3D
		_clear_stone_visual(unit, ch)
	var moves: Array[Dictionary] = []
	for unit: BattleUnit in _unit_nodes.keys():
		if unit.side == BattleUnit.Side.ENEMY:
			continue
		var ch: Node3D = _unit_nodes[unit] as Node3D
		var m: Marker3D = _get_player_marker(unit.row, unit.col)
		if ch and m:
			moves.append({"ch": ch,
				"to": m.global_position + Vector3(0.0, char_y_offset, 0.0)})
	if moves.is_empty():
		_manager.rotate_anim_done.emit()
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for entry: Dictionary in moves:
		tw.tween_property(entry["ch"], "position", entry["to"], rotate_duration)
	await tw.finished
	AudioManager.play_se(AudioManager.SE_ROTATE_STEP)
	# 到着フラッシュ（スカッシュと同時に発火）
	for entry: Dictionary in moves:
		_do_flash(entry["ch"], arrive_flash_color, arrive_flash_duration)
	# 着地スカッシュ
	var sq_in := create_tween().set_parallel(true)
	for entry: Dictionary in moves:
		sq_in.tween_property(entry["ch"], "scale",
			Vector3(landing_squash_xz, landing_squash_y, landing_squash_xz),
			landing_squash_in_time).set_ease(Tween.EASE_OUT)
	await sq_in.finished
	var sq_out := create_tween().set_parallel(true)
	for entry: Dictionary in moves:
		sq_out.tween_property(entry["ch"], "scale", player_char_scale,
			landing_squash_out_time).set_ease(Tween.EASE_OUT)
	await sq_out.finished
	# 完了時列フラッシュ（前列のみ・到着フラッシュより一拍遅れ）
	await get_tree().create_timer(front_row_flash_delay).timeout
	for unit: BattleUnit in _unit_nodes.keys():
		if unit.side != BattleUnit.Side.PLAYER or unit.row != 0:
			continue
		var ch: Node3D = _unit_nodes[unit] as Node3D
		if ch:
			_do_flash(ch, front_row_flash_color, front_row_flash_duration)
	await get_tree().create_timer(rotate_show_duration).timeout
	if is_instance_valid(_manager):
		_manager.rotate_anim_done.emit()

func _on_phase_started(phase: StringName) -> void:
	match phase:
		&"recovery":
			await get_tree().create_timer(self_heal_show_duration).timeout
			if is_instance_valid(_manager):
				_manager.self_heal_anim_done.emit()

func _on_attack_support_used(supporter: BattleUnit, attacker: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_SUPPORT)
	var ch_supp: Node3D = _unit_nodes.get(supporter) as Node3D
	var ch_atk: Node3D  = _unit_nodes.get(attacker)  as Node3D
	if ch_supp:
		_do_flash(ch_supp, supp_flash_color, supp_flash_duration)
	if ch_atk:
		_do_flash(ch_atk, supp_flash_color, supp_flash_duration)
		_spawn_atk_support_label(ch_atk.global_position)

func _on_defense_support_used(supporter: BattleUnit, target: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_SUPPORT)
	var ch_supp: Node3D = _unit_nodes.get(supporter) as Node3D
	var ch_tgt: Node3D  = _unit_nodes.get(target)    as Node3D
	if ch_supp:
		_do_flash(ch_supp, def_flash_color, def_flash_duration)
	if ch_tgt:
		_do_flash(ch_tgt, def_flash_color, def_flash_duration)
		_spawn_def_support_label(ch_tgt.global_position)

func _on_enemy_shield_activated(enemy: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_SUPPORT)
	var ch: Node3D = _unit_nodes.get(enemy) as Node3D
	if ch:
		_do_flash(ch, def_flash_color, def_flash_duration)
		_spawn_def_support_label(ch.global_position)

func _on_enemy_first_attack_activated(enemy: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_SUPPORT)
	var ch: Node3D = _unit_nodes.get(enemy) as Node3D
	if ch:
		_do_flash(ch, supp_flash_color, supp_flash_duration)
		_spawn_atk_support_label(ch.global_position)

func _on_unit_petrified(unit: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_PETRIFY)
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	if not ch:
		return
	_spawn_stone_label(ch.global_position)
	_apply_stone_tint(unit, ch)
	var anim: AnimationPlayer = _unit_anims.get(unit) as AnimationPlayer
	if anim:
		anim.pause()

func _on_unit_stone_cleared(unit: BattleUnit) -> void:
	AudioManager.play_se(AudioManager.SE_STONE_CLEAR)
	var ch: Node3D = _unit_nodes.get(unit) as Node3D
	_clear_stone_visual(unit, ch)

func _clear_stone_visual(unit: BattleUnit, ch: Node3D) -> void:
	_restore_stone_tint(unit, ch)
	var anim: AnimationPlayer = _unit_anims.get(unit) as AnimationPlayer
	if anim:
		var idle_name := "idle"
		if unit.side == BattleUnit.Side.ENEMY:
			var ed := unit.source_data as EnemyData
			if ed:
				idle_name = ed.idle_anim
		if anim.has_animation(idle_name):
			anim.play(idle_name)

func _apply_stone_tint(unit: BattleUnit, ch: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	var saved: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		if not mesh.mesh:
			continue
		var surf_count := mesh.mesh.get_surface_count()
		var orig_mats: Array = []
		for i: int in range(surf_count):
			orig_mats.append(mesh.get_surface_override_material(i))
		saved[mesh] = orig_mats
		for i: int in range(surf_count):
			var over: Material = orig_mats[i]
			var base: Material = over if over else mesh.mesh.surface_get_material(i)
			if not (over is ShaderMaterial or base is StandardMaterial3D):
				continue
			var gray := StandardMaterial3D.new()
			gray.albedo_color = Color(0.45, 0.45, 0.50, 1.0)
			mesh.set_surface_override_material(i, gray)
	_petrified_mats[unit] = saved

func _restore_stone_tint(unit: BattleUnit, ch: Node3D) -> void:
	if not _petrified_mats.has(unit):
		return
	var saved: Dictionary = _petrified_mats[unit] as Dictionary
	if ch:
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(ch, meshes)
		for mesh: MeshInstance3D in meshes:
			if not saved.has(mesh) or not mesh.mesh:
				continue
			var orig_mats: Array = saved[mesh] as Array
			for i: int in range(mini(orig_mats.size(), mesh.mesh.get_surface_count())):
				mesh.set_surface_override_material(i, orig_mats[i] as Material)
	_petrified_mats.erase(unit)

func _spawn_stone_label(pos: Vector3) -> void:
	var lbl := BattleScene._make_support_label(
		"Petrified", pos, supp_font_size, dmg_pixel_size, def_label_color, supp_label_offset)
	if _label_font:
		lbl.font = _label_font
	_characters.add_child(lbl)
	_animate_floating_label(lbl, supp_rise, supp_duration)

static func _make_heal_label(pos: Vector3, text: String, font_size: int,
		pixel_size: float, label_color: Color) -> Label3D:
	var lbl := _make_label3d(text, font_size, pixel_size, label_color)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.position = pos + Vector3(0.0, 1.5, 0.0)
	lbl.scale = Vector3.ZERO
	return lbl

func _on_row_heal_batch(entries: Array) -> void:
	for e: Dictionary in entries:
		_row_heal_units[e["unit"]] = true
	_row_heal_queue.append(entries)
	if not _row_heal_animating:
		_process_row_heal_queue()

func _process_row_heal_queue() -> void:
	_row_heal_animating = true
	while not _row_heal_queue.is_empty():
		var entries: Array = _row_heal_queue.pop_front()
		var sorted: Array = entries.duplicate()
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["unit"] as BattleUnit).col > (b["unit"] as BattleUnit).col)
		for e: Dictionary in sorted:
			var unit: BattleUnit = e["unit"] as BattleUnit
			var amount: int = e["amount"] as int
			var ch: Node3D = _unit_nodes.get(unit) as Node3D
			if ch:
				var text := "+%d" % amount if amount > 0 else "MAX"
				_spawn_floating_label(ch.global_position, text, heal_label_color)
				_do_flash(ch, heal_flash_color, heal_flash_duration)
				AudioManager.play_se(AudioManager.SE_HEAL_ROW)
			await get_tree().create_timer(heal_row_stagger).timeout
		if not _row_heal_queue.is_empty():
			await get_tree().create_timer(heal_batch_gap).timeout
	_row_heal_animating = false
	_row_heal_units.clear()
	await get_tree().create_timer(post_row_heal_show_duration).timeout
	if is_instance_valid(_manager):
		_manager.row_heal_anim_done.emit()

func _on_battle_ended(won: bool, _loot: Array) -> void:
	await get_tree().create_timer(battle_end_delay).timeout
	if won:
		GameState.advance_battle()
		if GameState.battle_index >= 3:
			get_tree().change_scene_to_file(_CLEAR_SCENE)
		else:
			get_tree().change_scene_to_file(_ENEMY_INFO_SCENE)
	else:
		GameState.reset_to_current_battle()
		get_tree().change_scene_to_file(_ENEMY_INFO_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_F12 \
			and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://tools")
		var path := "user://tools/screenshot.png"
		img.save_png(path)
		print("スクショ保存: %s" % path)
