class_name EnemyGenerator

# ステータスタイプの出現率（合計100）
const STAT_TYPE_WEIGHTS: Array[int] = [50, 15, 15, 10, 10]

# [hp_min, hp_max, atk_min, atk_max, spd_min, spd_max, regen_min, regen_max]
const STAT_RANGES: Array = [
	[80,  200, 8,  16, 6,  14, 0, 0],  # BALANCE
	[40,  90,  18, 28, 15, 25, 0, 0],  # BERSERKER
	[50,  120, 6,  14, 24, 35, 0, 0],  # SPEED_STAR
	[250, 450, 6,  12, 3,  8,  8, 18], # TANK
	[150, 280, 14, 22, 10, 20, 0, 8],  # ENHANCED_BALANCE
]

# 思考タイプの重みテーブル（enemy_spec.md 準拠）
# [RANDOM, WEAK, STRONG, CENTER, SUPPORT, DYING, FEMALE, MALE]
const THOUGHT_WEIGHTS: Array = [
	[3, 1, 1, 2, 1, 1, 1, 1],  # BALANCE
	[2, 3, 1, 1, 1, 3, 1, 1],  # BERSERKER
	[2, 1, 1, 1, 1, 1, 2, 2],  # SPEED_STAR
	[1, 1, 2, 3, 1, 1, 1, 1],  # TANK
	[1, 2, 1, 1, 3, 2, 1, 1],  # ENHANCED_BALANCE
]

static var _name_pool: Array = [
	"グラディウス", "ケルベロス", "マラカイ",
	"シェイド", "ドレイク", "ヴォルフ", "イグニス",
]

static func generate() -> EnemyData:
	var stat_type: int    = _weighted_choice(STAT_TYPE_WEIGHTS)
	var thought_type: int = _weighted_choice(THOUGHT_WEIGHTS[stat_type])
	var r: Array          = STAT_RANGES[stat_type]

	var data := EnemyData.new()
	data.enemy_name   = _random_name()
	data.stat_type    = stat_type    as EnemyData.StatType
	data.thought_type = thought_type as EnemyData.ThoughtType
	data.hp_max       = randi_range(r[0], r[1])
	data.attack       = randi_range(r[2], r[3])
	data.speed        = randi_range(r[4], r[5])
	data.self_regen   = randi_range(r[6], r[7])
	return data

static func _weighted_choice(weights: Array) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for i in weights.size():
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0

static func _random_name() -> String:
	return _name_pool[randi() % _name_pool.size()]
