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
@export var atk_bonus: int = 0        # 攻撃補助力
@export var def_bonus: int = 0        # 防御補助力
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
