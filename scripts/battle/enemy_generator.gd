class_name EnemyGenerator

const BUDGET_PER_LEVEL: int = 50
const DEFAULT_EXTREME_CHANCE: float = 0.05

# 通常配分の重み（合計1.0）
const BALANCED_WEIGHTS: Dictionary = {
	"hp_max":  0.40,
	"attack":  0.25,
	"defense": 0.20,
	"speed":   0.15,
}

# 統計ごとの最低値（0にならないよう保護）
const STAT_FLOOR: Dictionary = {
	"hp_max":  5,
	"attack":  1,
	"defense": 0,
	"speed":   1,
}

static var _name_pool: Array = [
	"グラディウス", "ケルベロス", "マラカイ",
	"シェイド", "ドレイク", "ヴォルフ", "イグニス",
]

static func generate(level: int, extreme_chance: float = DEFAULT_EXTREME_CHANCE) -> EnemyData:
	var data       = EnemyData.new()
	data.level     = level
	data.is_extreme = randf() < extreme_chance

	var budget: int = level * BUDGET_PER_LEVEL

	if data.is_extreme:
		_allocate_extreme(data, budget)
		data.enemy_name = "狂" + _random_name()
	else:
		_allocate_balanced(data, budget)
		data.enemy_name = _random_name()

	return data

static func _allocate_balanced(data: EnemyData, budget: int) -> void:
	var stats   = BALANCED_WEIGHTS.keys()
	var remaining = budget

	for i in stats.size():
		var stat: String = stats[i]
		var floor_val: int = STAT_FLOOR[stat]

		if i == stats.size() - 1:
			# 最後のステータスに残りを全部入れる
			data.set(stat, max(floor_val, remaining))
		else:
			var variance = budget * 0.10
			var val = int(budget * BALANCED_WEIGHTS[stat] + randf_range(-variance, variance))
			val = max(floor_val, val)
			data.set(stat, val)
			remaining -= val

static func _allocate_extreme(data: EnemyData, budget: int) -> void:
	# 全ステータスをfloorに設定してから、1つだけ残りを全投入
	var stats = STAT_FLOOR.keys()
	var floor_total = 0
	for stat in stats:
		data.set(stat, STAT_FLOOR[stat])
		floor_total += STAT_FLOOR[stat]

	var chosen: String = stats[randi() % stats.size()]
	data.set(chosen, STAT_FLOOR[chosen] + (budget - floor_total))

static func _random_name() -> String:
	return _name_pool[randi() % _name_pool.size()]
