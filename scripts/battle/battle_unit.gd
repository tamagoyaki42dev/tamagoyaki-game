class_name BattleUnit

enum Side { PLAYER, ENEMY }

var unit_name: String = ""
var side: int = Side.PLAYER
var row: int = 0  # 0=前列, 1=中列, 2=後列
var col: int = 0
var hp_max: int = 1
var hp: int = 1
var attack: int = 0
var defense: int = 0
var speed: int = 0
var source_data: Resource  # CharacterData or EnemyData

var is_alive: bool:
	get: return hp > 0

static func from_character(data: CharacterData, col: int = 0) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name   = data.char_name
	unit.side        = Side.PLAYER
	unit.row         = CharacterJob.preferred_row(data.job)
	unit.col         = col
	unit.hp_max      = data.hp_max
	unit.hp          = data.hp_max
	unit.attack      = data.attack
	unit.defense     = data.defense
	unit.speed       = data.speed
	unit.source_data = data
	return unit

static func from_enemy(data: EnemyData, row: int = 0, col: int = 0) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name   = data.enemy_name
	unit.side        = Side.ENEMY
	unit.row         = row
	unit.col         = col
	unit.hp_max      = data.hp_max
	unit.hp          = data.hp_max
	unit.attack      = data.attack
	unit.defense     = data.defense
	unit.speed       = data.speed
	unit.source_data = data
	return unit

# 実ダメージを返す（defense軽減・最低1保証）
func take_damage(raw_attack: int) -> int:
	var actual = max(1, raw_attack - defense)
	hp = max(0, hp - actual)
	return actual
