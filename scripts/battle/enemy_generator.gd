class_name EnemyGenerator

const STAT_TYPE_WEIGHTS: Array[int] = [50, 15, 15, 10, 10]

# [hp_min, hp_max, atk_min, atk_max, spd_min, spd_max, regen_min, regen_max]
const STAT_RANGES: Array = [
	[80,  200, 8,  16, 6,  14, 0, 0],   # BALANCE
	[40,  90,  18, 28, 15, 25, 0, 0],   # BERSERKER
	[50,  120, 6,  14, 24, 35, 0, 0],   # SPEED_STAR
	[250, 450, 6,  12, 3,  8,  8, 18],  # TANK
	[150, 280, 14, 22, 10, 20, 0, 8],   # ENHANCED_BALANCE
]

const THOUGHT_WEIGHTS: Array = [
	[3, 1, 1, 2, 1, 1, 1, 1],  # BALANCE
	[2, 3, 1, 1, 1, 3, 1, 1],  # BERSERKER
	[2, 1, 1, 1, 1, 1, 2, 2],  # SPEED_STAR
	[1, 1, 2, 3, 1, 1, 1, 1],  # TANK
	[1, 2, 1, 1, 3, 2, 1, 1],  # ENHANCED_BALANCE
]

# [NORMAL, DOUBLE, TRIPLE, QUAD, ROW, STONE, ABSORB, CHARGE]  (enemy_spec.md準拠)
const ACTION_WEIGHTS: Array = [
	[3, 2, 1, 0, 1, 1, 1, 1],  # BALANCE
	[2, 3, 3, 2, 1, 0, 0, 1],  # BERSERKER
	[3, 1, 1, 0, 1, 2, 1, 1],  # SPEED_STAR
	[2, 1, 0, 0, 2, 0, 3, 2],  # TANK
	[2, 2, 2, 1, 2, 1, 1, 2],  # ENHANCED_BALANCE
]

static var _name_pool: Array = [
	"グラディウス", "ケルベロス", "マラカイ",
	"シェイド", "ドレイク", "ヴォルフ", "イグニス",
]

# force_stat_type: 0〜4で固定、-1でランダム
static func generate(force_stat_type: int = -1) -> EnemyData:
	var stat_type: int = force_stat_type if force_stat_type >= 0 else _weighted_choice(STAT_TYPE_WEIGHTS)
	var thought_type: int = _weighted_choice(THOUGHT_WEIGHTS[stat_type])
	var r: Array = STAT_RANGES[stat_type]

	var data := EnemyData.new()
	data.enemy_name   = _random_name()
	data.stat_type    = stat_type    as EnemyData.StatType
	data.thought_type = thought_type as EnemyData.ThoughtType
	data.hp_max       = randi_range(r[0], r[1])
	data.attack       = randi_range(r[2], r[3])
	data.speed        = randi_range(r[4], r[5])
	data.self_regen   = randi_range(r[6], r[7])
	data.action_cycle = _generate_action_cycle(stat_type, data.self_regen)
	return data

# enemy_spec.mdのアクションサイクル生成アルゴリズム
static func _generate_action_cycle(stat_type: int, self_regen: int) -> Array[int]:
	var weights: Array = ACTION_WEIGHTS[stat_type].duplicate()

	# 前処理: タンクかつ自己回復 >= 10 の場合、HP吸収の重みを0にする
	if stat_type == EnemyData.StatType.TANK and self_regen >= 10:
		weights[EnemyData.ActionType.ABSORB] = 0

	var cycle_len: int = 2 + randi() % 3  # 2〜4
	var cycle: Array[int] = []
	var charge_used := false

	for i in cycle_len:
		var w: Array = weights.duplicate()

		# 力を溜めるは1サイクルに最大1回
		if charge_used:
			w[EnemyData.ActionType.CHARGE] = 0

		# 前のスロットが力を溜めるなら攻撃系を強制
		if not cycle.is_empty() and cycle[-1] == EnemyData.ActionType.CHARGE:
			w[EnemyData.ActionType.CHARGE] = 0

		var action: int = _weighted_choice(w)
		if action == EnemyData.ActionType.CHARGE:
			charge_used = true
		cycle.append(action)

	return cycle

static func _weighted_choice(weights: Array) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = randi() % max(total, 1)
	var cumulative: int = 0
	for i in weights.size():
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0

static func _random_name() -> String:
	return _name_pool[randi() % _name_pool.size()]
