class_name BattleUnit

enum Side { PLAYER, ENEMY }

var unit_name: String = ""
var side: int = Side.PLAYER
var row: int = 0
var col: int = 0
var hp_max: int = 1
var hp: int = 1
var attack: int = 0
var speed: int = 0
var indirect_attack: int = 0   # 間接攻撃力（アーチャー・ヴァルキリーのみ）
var atk_bonus: int = 0         # 攻撃補助力
var atk_bonus_is_row: bool = false  # true = 攻補(列)タイプ
var def_bonus: int = 0         # 防御補助力
var self_regen: int = 0        # 自回復
var row_regen: int = 0         # 列回復
var attack_hits: int = 1       # 攻撃回数（巫女×4、ニンジャ×2）
var crit_rate: float = 0.05    # クリティカル率
var is_stone_attack: bool = false  # 石化攻撃か（祈祷師）
var charge_multiplier: float = 1.0  # 力を溜める: 次の攻撃のATK倍率
var atk_support_used: bool = false  # 攻撃補助使用済み（ローテーションでリセット）
var def_support_used: bool = false  # 防御補助使用済み（ローテーションでリセット）
var shield_active: bool = false     # 敵の初回防御が有効か（ローテーションで復活）
var first_attack_active: bool = false  # 敵の初回攻撃ボーナスが有効か（ローテーションで復活）
var is_petrified: bool = false      # 石化状態
var charge_excess: int = 0          # クリティカルチャージ余剰回復量
var source_data: Resource

var is_alive: bool:
	get: return hp > 0

static func from_character(data: CharacterData, col: int = 0) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_name        = data.char_name
	unit.side             = Side.PLAYER
	unit.row              = CharacterJob.preferred_row(data.job)
	unit.col              = col
	unit.hp_max           = data.hp_max
	unit.hp               = data.hp_max
	unit.attack           = data.attack
	unit.speed            = data.speed
	unit.indirect_attack  = data.indirect_attack
	unit.atk_bonus        = data.atk_bonus
	unit.atk_bonus_is_row = data.atk_bonus_is_row
	unit.def_bonus        = data.def_bonus
	unit.self_regen       = data.self_regen
	unit.row_regen        = data.row_regen
	unit.crit_rate        = CharacterJob.crit_rate(data.job)
	unit.attack_hits      = CharacterJob.attack_hits(data.job)
	unit.is_stone_attack  = CharacterJob.is_stone_attack(data.job)
	unit.source_data      = data
	return unit

static func from_enemy(data: EnemyData, row: int = 0, col: int = 0) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_name   = data.enemy_name
	unit.side        = Side.ENEMY
	unit.row         = row
	unit.col         = col
	unit.hp_max      = data.hp_max
	unit.hp          = data.hp_max
	unit.attack      = data.attack
	unit.speed       = data.speed
	unit.self_regen  = data.self_regen
	unit.crit_rate           = 0.0  # 敵はクリティカルなし
	unit.shield_active       = data.initial_defense > 0
	unit.first_attack_active = data.initial_attack_mult > 1.0
	unit.source_data         = data
	return unit

# 防御補助なし: damage = raw_attack / 防御補助あり: damage = max(0, raw_attack - def_support)
func take_damage(raw_attack: int, def_support: int = 0) -> int:
	var actual: int = max(0, raw_attack - def_support)
	hp = max(0, hp - actual)
	return actual
