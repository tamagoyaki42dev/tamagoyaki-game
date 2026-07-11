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

# 列＝[きまぐれ,弱者,高HP,中央,補助,瀕死,女性,男性,高攻撃力]（ThoughtType定義順・HIGH_ATK_TARGETは末尾追加）
const THOUGHT_WEIGHTS: Array = [
	[3, 1, 1, 2, 1, 1, 1, 1, 1],  # BALANCE
	[2, 3, 1, 1, 1, 3, 1, 1, 2],  # BERSERKER
	[2, 1, 1, 1, 1, 1, 2, 2, 1],  # SPEED_STAR
	[1, 1, 2, 3, 1, 1, 1, 1, 2],  # TANK
	[1, 2, 1, 1, 3, 2, 1, 1, 2],  # ENHANCED_BALANCE
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

# ── proto1 固定3体（proto1_3battle_design.md §2 確定値） ─────────────────

const _MONSTER_DIR := "res://assets/quaternius-ultimate-monsters/"

# 第1戦：マッシュナブ（Mushnub / Blob）― バランス・きまぐれ・通常攻撃のみ
static func make_battle1() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name  = "マッシュナブ"
	e.hp_max      = 280
	e.attack      = 14
	e.speed       = 10
	e.self_regen  = 0
	e.stat_type   = EnemyData.StatType.BALANCE
	e.thought_type = EnemyData.ThoughtType.RANDOM
	# 消耗死は維持。4ターンに1回だけ列攻撃＝「前列を広げすぎるな」を軽く教える
	e.action_cycle = [EnemyData.ActionType.NORMAL,
		EnemyData.ActionType.NORMAL, EnemyData.ActionType.ROW, EnemyData.ActionType.NORMAL]
	e.model_path   = _MONSTER_DIR + "Blob/glTF/Mushnub.gltf"
	e.idle_anim    = "Idle"
	e.attack_anim  = "Bite_Front"
	e.death_anim   = "Death"
	e.model_scale        = 0.55  # Quaternius は Kenney より元スケールが大きいため逆に下げる
	e.initial_defense      = 5
	e.initial_attack_bonus = 0
	e.notes = "浅い澱みが寄り集まって、かろうじて獣の形をとったもの。\n滅んだ者たちの残響をわずかに宿すだけで、明確な意思はない。\n狙いは定まらず、時おり身を震わせて周囲へ泥を撒き散らす。\nひとつの打撃は重くないが、崩してもまた寄り集まり、その芯は存外に厚い。"
	return e

# 第2戦：トライバル（Tribal / Big）― タンク・高HP狙い・自己回復
static func make_battle2() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name  = "トライバル"
	# 敵自己回復がdo_rotate（プレイヤーのローテ操作）連動でなく毎ターン無条件発動していたバグを
	# 2026-07-04に修正。STAY戦略は一切ローテしないため、修正後はregenがSTAY中は永久に発動しない
	# （＝Stay戦略下ではregen42は実質無風）。regen42はRotateチート潰し用として維持し、
	# 「壁」の主表現をHPへ移し110→150→350へ再格上げ（HP350/ATK8/regen42でB2-S 100%@6T収束）
	e.hp_max      = 350
	e.attack      = 8
	e.speed       = 5
	e.self_regen  = 42
	e.stat_type   = EnemyData.StatType.TANK
	# 旧STRONG_TARGET(HP基準)は表示文言と食い違うバグだったため2026-07-02に高HP狙い/高攻撃力狙いへ分離。
	# 高攻撃力狙い(常に同じ最強火力を専任で狙う)は「一生STAYで押し切る」B2の設計と衝突する
	# （防御補助/シールドはローテでしか復活せずSTAY中は1回のみ→固定標的は必ずいつか死ぬ）と判明。
	# B2は高HP狙いのまま（狙いが自然に揺れ動きダメージが分散＝STAY可能な壁の像を保つ）
	e.thought_type = EnemyData.ThoughtType.HIGH_HP_TARGET
	# DPS壁は維持しつつ多様化＝単体集中の枠内でパターンを増やす。
	# 列攻撃(ROW)はNG＝前列に自己回復が無くAoEは恒久チップで壁の像が壊れる（2026-07-02判明）。
	# 単体系（連続攻撃・HP吸収）なら同じ標的1人に集中するため像を保てる
	e.action_cycle = [EnemyData.ActionType.NORMAL,
		EnemyData.ActionType.DOUBLE, EnemyData.ActionType.NORMAL, EnemyData.ActionType.ABSORB]
	e.model_path   = _MONSTER_DIR + "Big/glTF/Tribal.gltf"
	e.idle_anim    = "Idle"
	e.death_anim   = "Death"
	e.model_scale        = 0.7
	e.model_offset       = Vector3(0.0, -0.2, 0.0)
	e.initial_defense      = 8
	e.initial_attack_bonus = 4
	e.notes = "幾度の巡りをくぐり、頑健さだけを研ぎ澄ました古き土着種。\n並外れて分厚い体躯を持ち、動きは鈍い。\n浅い傷を意に介さず、奪った活力で己の傷を繕いながら、\n最も手強いと見た者へ、まっすぐ退かず向かってくる。"
	return e

# 第3戦：ドラゴン（Dragon_Evolved / Flying）― 強化バランス・補助狙い・溜め→通常×3
static func make_battle3() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name  = "ドラゴン"
	e.hp_max      = 225
	e.attack      = 11
	e.speed       = 14
	e.self_regen  = 6
	e.stat_type   = EnemyData.StatType.ENHANCED_BALANCE
	e.thought_type = EnemyData.ThoughtType.SUPPORT_TARGET
	# ラスボス＝複合試験。溜め→通常1発の2倍スパイク（補助狙いが刺さる＝補助役は危険ターンに前へ出すな）
	# ／石化で1体無力化／列は素のチップ
	e.action_cycle = [EnemyData.ActionType.CHARGE,
		EnemyData.ActionType.NORMAL, EnemyData.ActionType.STONE, EnemyData.ActionType.ROW]
	e.model_path   = _MONSTER_DIR + "Flying/glTF/Dragon_Evolved.gltf"
	e.idle_anim    = "Flying_Idle"
	e.death_anim   = "Death"
	e.model_scale        = 0.9
	e.battle_model_scale = 0.56
	e.model_offset       = Vector3(0.0, -0.6, 0.0)
	e.impact_height_mult = 2.2  # 要目視調整：巨躯のため被弾エフェクト/着弾を胴体中心付近まで引き上げ
	e.initial_defense      = 10
	e.initial_attack_bonus = 0  # ローテ直後の攻撃が溜めの×2と二重取りしスパイクが過剰になるため0（詳細 devlog/2026-07-02）
	e.notes = "濃い澱みを喰らい、獣の域を踏み越えた飛竜。\nただ荒ぶるのではなく、間合いを計り、息を溜め、\n群れを支える者から先に喰らう狡知を備えている。\n溜めた一撃はそのぶん深く穿ち、時に相手の動きを縛る。\n速く、聡く、この巡りの澱みが生んだ頂き。"
	return e
