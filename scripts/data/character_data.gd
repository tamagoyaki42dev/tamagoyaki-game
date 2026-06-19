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
@export var atk_bonus_is_row: bool = false  # true = 攻補(列)タイプ（剣闘士・冒険者・僧侶・聖騎士）
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

# 職業ベース値から個体差±20%付きで生成
static func from_job(type: CharacterJob.Type) -> CharacterData:
	# [hp, atk, spd, iatk, ab, ab_row, db, sr, rr]
	const BASE: Dictionary = {
		0:  [35, 20, 15,  0,  0, false,  0,  0,  0],  # WARRIOR
		1:  [30, 12,  8,  0,  0, false, 12,  8,  0],  # KNIGHT
		2:  [28, 22,  5,  0, 12,  true,  0,  0,  0],  # GLADIATOR
		3:  [22, 18, 22,  0,  0, false,  0,  6,  0],  # ILLUSIONIST
		4:  [26, 12, 10,  0,  8,  true,  8,  6,  0],  # ADVENTURER
		5:  [32, 10,  8,  0, 10,  true,  0,  0, 12],  # MONK
		6:  [18,  8,  6,  0,  0, false, 20,  0, 15],  # CLERIC
		7:  [20,  8,  5,  0, 20, false,  0,  0, 10],  # MAGE
		8:  [22, 10, 16,  0, 14, false, 12,  0,  0],  # WITCH
		9:  [24, 16, 12, 12,  0, false,  0,  0,  0],  # ARCHER
		10: [18, 12, 18, 15,  0, false,  0,  8,  0],  # VALKYRIE
		11: [24, 14,  5,  0,  0, false, 10,  8,  0],  # SHAMAN
		12: [20,  6, 18,  0,  0, false,  0,  0, 14],  # SHRINE_MAIDEN
		13: [28, 24, 28,  0,  0, false,  0,  0,  0],  # SAMURAI
		14: [32, 18, 22,  0,  0, false,  0, 10,  0],  # NINJA
		15: [40, 22, 12,  0,  0, false,  6,  0, 10],  # DARK_KNIGHT
		16: [28, 10, 10,  0, 22,  true, 18,  0, 18],  # HOLY_KNIGHT
	}
	var b: Array = BASE[int(type)]
	var data := CharacterData.new()
	data.job = type
	data.hp_max          = maxi(1, ceili(b[0] * randf_range(0.8, 1.2)))
	data.attack          = maxi(1, ceili(b[1] * randf_range(0.8, 1.2)))
	data.speed           = maxi(1, ceili(b[2] * randf_range(0.8, 1.2)))
	data.indirect_attack = maxi(0, ceili(b[3] * randf_range(0.8, 1.2))) if b[3] > 0 else 0
	data.atk_bonus       = maxi(0, ceili(b[4] * randf_range(0.8, 1.2))) if b[4] > 0 else 0
	data.atk_bonus_is_row = b[5]
	data.def_bonus       = maxi(0, ceili(b[6] * randf_range(0.8, 1.2))) if b[6] > 0 else 0
	data.self_regen      = maxi(0, ceili(b[7] * randf_range(0.8, 1.2))) if b[7] > 0 else 0
	data.row_regen       = maxi(0, ceili(b[8] * randf_range(0.8, 1.2))) if b[8] > 0 else 0
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
