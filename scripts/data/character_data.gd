class_name CharacterData
extends Resource

@export var id: String = ""
@export var char_name: String = ""
@export var job: CharacterJob.Type = CharacterJob.Type.WARRIOR
@export var age: int = 20
@export var lifespan: int = 40  # この年齢に達したら引退

# 戦闘ステータス
@export var hp_max: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 10

# 世代・継承管理
@export var generation: int = 1
@export var parent_id: String = ""
@export var battles_fought: int = 0  # 12戦 = 1年

var is_retired: bool:
	get: return age >= lifespan

var current_year: int:
	get: return battles_fought / 12

func apply_inheritance(parent: CharacterData, rate: float = 0.3) -> void:
	hp_max    += int(parent.hp_max    * rate)
	attack    += int(parent.attack    * rate)
	defense   += int(parent.defense   * rate)
	speed     += int(parent.speed     * rate)
	generation = parent.generation + 1
	parent_id  = parent.id
