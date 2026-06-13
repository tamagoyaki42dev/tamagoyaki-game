class_name EnemyData
extends Resource

enum StatType {
	BALANCE,           # バランス（50%）
	BERSERKER,         # バーサーカー（15%）
	SPEED_STAR,        # スピードスター（15%）
	TANK,              # タンク（10%）
	ENHANCED_BALANCE,  # 強化バランス（10%）
}

enum ThoughtType {
	RANDOM,         # きまぐれ
	WEAK_TARGET,    # 弱者狙い
	STRONG_TARGET,  # 強者狙い
	CENTER_TARGET,  # 中央狙い
	SUPPORT_TARGET, # 補助狙い
	DYING_TARGET,   # 瀕死狙い
	FEMALE_TARGET,  # 女性狙い
	MALE_TARGET,    # 男性狙い
}

@export var enemy_name: String = ""
@export var hp_max: int = 80
@export var attack: int = 10
@export var speed: int = 8
@export var self_regen: int = 0
@export var stat_type: StatType = StatType.BALANCE
@export var thought_type: ThoughtType = ThoughtType.RANDOM

func get_label() -> String:
	return enemy_name
