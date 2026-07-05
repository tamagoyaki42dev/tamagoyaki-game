class_name CharacterData
extends Resource

@export var id: String = ""
@export var char_name: String = ""
@export var job: CharacterJob.Type = CharacterJob.Type.WARRIOR
@export var age: int = 20
@export var lifespan: int = 40  # この年齢に達したら引退

# 戦闘ステータス（unit_spec.md 準拠）
@export var hp_max: int = 20
@export var attack: int = 10
@export var speed: int = 10
@export var indirect_attack: int = 0  # 間接攻撃力（アーチャー・ヴァルキリーのみ）
@export var atk_bonus: int = 0           # 攻撃補助力
@export var def_bonus: int = 0           # 防御補助力
@export var self_regen: int = 0       # 自回復
@export var row_regen: int = 0        # 列回復

# 世代・継承管理
@export var generation: int = 1
@export var parent_id: String = ""
@export var battles_fought: int = 0  # 12戦 = 1年

var is_retired: bool:
	get: return age >= lifespan

var current_year: int:
	get: return battles_fought / 12

# 職業ベース値 [hp, atk, spd, iatk, ab, db, sr, rr]
const BASE: Dictionary = {
	0:  [44, 13, 13,  0,  0,  0,  0,  0],  # WARRIOR
	1:  [26, 10,  8,  0,  0, 18,  8,  0],  # KNIGHT
	2:  [28, 22,  5,  0, 12,  0,  0,  0],  # GLADIATOR
	3:  [28, 13, 12,  0,  0,  0, 16,  0],  # ILLUSIONIST
	4:  [26, 12, 10,  0,  8,  8,  6,  0],  # ADVENTURER
	5:  [30, 10,  8,  0, 10,  0,  0, 16],  # MONK
	6:  [18,  8,  6,  0,  0, 20,  0, 15],  # CLERIC
	7:  [20,  8,  5,  0, 20,  6,  0, 10],  # MAGE
	8:  [22, 10, 16,  0, 13, 13,  0,  0],  # WITCH
	9:  [28, 12, 12, 19,  0,  0,  0,  0],  # ARCHER
	10: [20, 10, 18, 24,  0,  0,  8,  0],  # VALKYRIE
	11: [24, 14,  5,  0,  0, 10,  8,  0],  # SHAMAN
	12: [20,  6, 18,  0,  0,  0,  0, 14],  # SHRINE_MAIDEN
	13: [24, 24, 28,  0,  0,  0,  0,  0],  # SAMURAI
	14: [22, 12, 22,  0,  0,  0,  7,  0],  # NINJA
	15: [40, 22, 12,  0,  0,  6,  0, 10],  # DARK_KNIGHT
	16: [28, 10, 10,  0, 22, 18,  0, 18],  # HOLY_KNIGHT
}

# unit_spec.md「キャラ総合ポイント重みテーブル」準拠（[hp, atk, spd, iatk, ab, db, sr, rr]）
const STAT_WEIGHTS: Array[float] = [1.5, 1.5, 0.3, 1.0, 1.2, 1.5, 1.0, 0.7]
# unit_spec.md「ステータス上限・下限（設計ガードレール）」準拠
const STAT_MIN: Array[int] = [16,  6,  3,  8,  6,  6,  5,  8]
const STAT_MAX: Array[int] = [50, 28, 34, 26, 24, 22, 18, 20]

const INDIVIDUAL_VARIANCE := 0.2
const OUTLIER_CHANCE := 0.15
const OUTLIER_VARIANCE := 0.5

# 個体値＋偏差（総量保存の再配分）。proto2_design.md「個体値＋偏差」準拠。
# アクティブな8ステータスを独立ロール（15%の確率で1つだけ±50%の裾）した後、
# 重み付き合計が職のベース総量と一致するよう全ステに同率スケール補正をかけ、最後にガードレールでクランプする。
# ※まだ from_job() には接続していない（proto2の生成・継承画面ができてから差し替える）
static func roll_individual_stats(type: CharacterJob.Type) -> Array:
	var b: Array = BASE[int(type)]
	var active: Array[int] = []
	for i in range(8):
		if b[i] > 0:
			active.append(i)
	var outlier_index := -1
	if randf() < OUTLIER_CHANCE:
		outlier_index = active[randi() % active.size()]
	var rolled: Array = b.duplicate()
	for i in active:
		var variance: float = OUTLIER_VARIANCE if i == outlier_index else INDIVIDUAL_VARIANCE
		rolled[i] = b[i] * randf_range(1.0 - variance, 1.0 + variance)
	var base_total := 0.0
	var rolled_total := 0.0
	for i in active:
		base_total += b[i] * STAT_WEIGHTS[i]
		rolled_total += rolled[i] * STAT_WEIGHTS[i]
	var scale: float = base_total / rolled_total if rolled_total > 0.0 else 1.0
	var result: Array = []
	for i in range(8):
		if i in active:
			result.append(clampi(roundi(rolled[i] * scale), STAT_MIN[i], STAT_MAX[i]))
		else:
			result.append(0)
	return result

# 職業ベース値から個体差±20%付きで生成
static func from_job(type: CharacterJob.Type) -> CharacterData:
	var b: Array = BASE[int(type)]
	var data := CharacterData.new()
	data.job = type
	data.hp_max          = maxi(1, ceili(b[0] * randf_range(0.8, 1.2)))
	data.attack          = maxi(1, ceili(b[1] * randf_range(0.8, 1.2)))
	data.speed           = maxi(1, ceili(b[2] * randf_range(0.8, 1.2)))
	data.indirect_attack = maxi(0, ceili(b[3] * randf_range(0.8, 1.2))) if b[3] > 0 else 0
	data.atk_bonus       = maxi(0, ceili(b[4] * randf_range(0.8, 1.2))) if b[4] > 0 else 0
	data.def_bonus       = maxi(0, ceili(b[5] * randf_range(0.8, 1.2))) if b[5] > 0 else 0
	data.self_regen      = maxi(0, ceili(b[6] * randf_range(0.8, 1.2))) if b[6] > 0 else 0
	data.row_regen       = maxi(0, ceili(b[7] * randf_range(0.8, 1.2))) if b[7] > 0 else 0
	return data

func apply_inheritance(parent: CharacterData, rate: float = 0.3) -> void:
	hp_max          += int(parent.hp_max          * rate)
	attack          += int(parent.attack          * rate)
	speed           += int(parent.speed           * rate)
	indirect_attack += int(parent.indirect_attack * rate)
	atk_bonus       += int(parent.atk_bonus       * rate)
	def_bonus       += int(parent.def_bonus       * rate)
	self_regen      += int(parent.self_regen      * rate)
	row_regen       += int(parent.row_regen       * rate)
	generation       = parent.generation + 1
	parent_id        = parent.id
