class_name EnemyData
extends Resource

enum StatType {
	BALANCE,
	BERSERKER,
	SPEED_STAR,
	TANK,
	ENHANCED_BALANCE,
}

enum ThoughtType {
	RANDOM,
	WEAK_TARGET,
	STRONG_TARGET,
	CENTER_TARGET,
	SUPPORT_TARGET,
	DYING_TARGET,
	FEMALE_TARGET,
	MALE_TARGET,
}

enum ActionType {
	NORMAL,   # 通常攻撃
	DOUBLE,   # ×2連続
	TRIPLE,   # ×3連続
	QUAD,     # ×4連続
	ROW,      # 列攻撃
	STONE,    # 石化攻撃
	ABSORB,   # HP吸収（ダメージの50%を自己回復）
	CHARGE,   # 力を溜める
}

@export var enemy_name: String = ""
@export var hp_max: int = 80
@export var attack: int = 10
@export var speed: int = 8
@export var self_regen: int = 0
@export var stat_type: StatType = StatType.BALANCE
@export var thought_type: ThoughtType = ThoughtType.RANDOM
@export var action_cycle: Array[int] = []

# ビジュアル（省略時は BattleScene のデフォルト Kenney モデルにフォールバック）
@export var model_path: String = ""
@export var idle_anim: String = "idle"
@export var attack_anim: String = ""   # 空なら Tween 突進にフォールバック
@export var death_anim: String = "die"
@export var model_scale: float = 1.0

func get_label() -> String:
	return enemy_name

func get_stat_type_name() -> String:
	match stat_type:
		StatType.BALANCE:          return "バランス"
		StatType.BERSERKER:        return "バーサーカー"
		StatType.SPEED_STAR:       return "スピードスター"
		StatType.TANK:             return "タンク"
		StatType.ENHANCED_BALANCE: return "強化バランス"
	return "不明"

static func get_action_label(action: int) -> String:
	match action:
		ActionType.NORMAL:  return "攻撃"
		ActionType.DOUBLE:  return "連続攻撃"
		ActionType.TRIPLE:  return "連続攻撃"
		ActionType.QUAD:    return "連続攻撃"
		ActionType.ROW:     return "全体攻撃"
		ActionType.STONE:   return "石化攻撃"
		ActionType.ABSORB:  return "HP吸収"
		ActionType.CHARGE:  return "力を溜める"
	return "攻撃"
