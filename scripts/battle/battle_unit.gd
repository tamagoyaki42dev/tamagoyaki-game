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
var indirect_attack: int = 0  # 間接攻撃力（アーチャー・ヴァルキリーのみ）
var atk_bonus: int = 0        # 攻撃補助力
var def_bonus: int = 0        # 防御補助力
var self_regen: int = 0       # 自回復
var row_regen: int = 0        # 列回復
var source_data: Resource

var is_alive: bool:
	get: return hp > 0

static func from_character(data: CharacterData, col: int = 0) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_name       = data.char_name
	unit.side            = Side.PLAYER
	unit.row             = CharacterJob.preferred_row(data.job)
	unit.col             = col
	unit.hp_max          = data.hp_max
	unit.hp              = data.hp_max
	unit.attack          = data.attack
	unit.speed           = data.speed
	unit.indirect_attack = data.indirect_attack
	unit.atk_bonus       = data.atk_bonus
	unit.def_bonus       = data.def_bonus
	unit.self_regen      = data.self_regen
	unit.row_regen       = data.row_regen
	unit.source_data     = data
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
	unit.source_data = data
	return unit

# 防御補助なし: damage = raw_attack / 防御補助あり: damage = max(0, raw_attack - def_support)
func take_damage(raw_attack: int, def_support: int = 0) -> int:
	var actual: int = max(0, raw_attack - def_support)
	hp = max(0, hp - actual)
	return actual
