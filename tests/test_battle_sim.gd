extends GutTest

# 3戦バランス検証シミュ。stdout は集計サマリのみ（per-trial ログは verbose=true 時のみ user://sim_log.txt へ）
const K := 100

# 味方15職リバランス（2026-07-01）を受けて敵側を再調整・再較正済み（2026-07-02）。
# SMART戦略（汎用competent-player・1手先読み貪欲）でB3の勝敗を実測できるようになったのが決め手。
const ASSERT_BALANCE := true

@export var verbose: bool = false
var _variance: bool = false  # test_variance_impact 専用。true で個体差±20%切り上げを適用（character_data.gd と同式）

# ──────── CharacterData ベース値（character_data.gd の BASE dict と同値・個体差なし） ────────
const CHAR_BASE: Dictionary = {
	0:  [44, 13, 13,  0,  0,  0,  0,  0],  # WARRIOR
	1:  [26, 10,  8,  0,  0, 18,  8,  0],  # KNIGHT
	2:  [28, 22,  5,  0, 12,  0,  0,  0],  # GLADIATOR
	3:  [28, 13, 12,  0,  0,  0, 16,  0],  # ILLUSIONIST
	4:  [26, 12, 10,  0,  8,  8,  6,  0],  # ADVENTURER
	5:  [30, 10,  8,  0, 10,  0,  0, 16],  # MONK
	6:  [18,  8,  6,  0,  0, 20,  0, 15],  # CLERIC
	7:  [20,  8,  5,  0, 20,  6,  0, 10],  # MAGE
	8:  [22, 10, 16,  0, 13, 13,  0,  0],  # WITCH
	9:  [28, 12, 12, 19,  0,  0,  0,  0],  # ARCHER
	10: [20, 10, 18, 24,  0,  0,  8,  0],  # VALKYRIE
	11: [24, 14,  5,  0,  0, 10,  8,  0],  # SHAMAN
	12: [20,  6, 18,  0,  0,  0,  0, 14],  # SHRINE_MAIDEN
	13: [24, 24, 28,  0,  0,  0,  0,  0],  # SAMURAI
	14: [22, 12, 22,  0,  0,  0,  7,  0],  # NINJA
	15: [40, 22, 12,  0,  0,  6,  0, 10],  # DARK_KNIGHT
	16: [28, 10, 10,  0, 22, 18,  0, 18],  # HOLY_KNIGHT
}

# ──────── ヘルパー ────────

func _make_char(job: CharacterJob.Type) -> CharacterData:
	var b: Array = CHAR_BASE[int(job)]
	var data := CharacterData.new()
	data.job              = job
	if _variance:
		# character_data.gd from_job と同式（±20%・切り上げ・最小1／0ステはそのまま）
		data.hp_max          = maxi(1, ceili(b[0] * randf_range(0.8, 1.2)))
		data.attack          = maxi(1, ceili(b[1] * randf_range(0.8, 1.2)))
		data.speed           = maxi(1, ceili(b[2] * randf_range(0.8, 1.2)))
		data.indirect_attack = maxi(0, ceili(b[3] * randf_range(0.8, 1.2))) if b[3] > 0 else 0
		data.atk_bonus       = maxi(0, ceili(b[4] * randf_range(0.8, 1.2))) if b[4] > 0 else 0
		data.def_bonus       = maxi(0, ceili(b[5] * randf_range(0.8, 1.2))) if b[5] > 0 else 0
		data.self_regen      = maxi(0, ceili(b[6] * randf_range(0.8, 1.2))) if b[6] > 0 else 0
		data.row_regen       = maxi(0, ceili(b[7] * randf_range(0.8, 1.2))) if b[7] > 0 else 0
	else:
		data.hp_max           = b[0]
		data.attack           = b[1]
		data.speed            = b[2]
		data.indirect_attack  = b[3]
		data.atk_bonus        = b[4]
		data.def_bonus        = b[5]
		data.self_regen       = b[6]
		data.row_regen        = b[7]
	return data

func _make_enemy(hp: int, atk: int, spd: int, regen: int,
				 thought: EnemyData.ThoughtType, cycle: Array[int],
				 initial_def: int = 0, initial_atk_bonus: int = 0) -> EnemyData:
	var ed := EnemyData.new()
	ed.hp_max               = hp
	ed.attack               = atk
	ed.speed                = spd
	ed.self_regen           = regen
	ed.thought_type         = thought
	ed.action_cycle         = cycle
	ed.initial_defense      = initial_def
	ed.initial_attack_bonus = initial_atk_bonus
	return ed

# formation: Array of [CharacterJob.Type, row, col]
# strategy: "ROTATE" | "STAY" | "ADAPTIVE_B3"
# 1試行。BattleManager を内部で生成・破棄する
func _run_trial(formation: Array, enemy_data: EnemyData, strategy: String, lf: FileAccess = null) -> Dictionary:
	var bm := BattleManager.new()
	add_child(bm)
	bm.support_delay = 0.0

	bm.player_grid = RotationGrid.new()
	bm.enemy_grid  = RotationGrid.new()

	for spec: Array in formation:
		var job: CharacterJob.Type = spec[0] as CharacterJob.Type
		var row: int = spec[1]
		var col: int = spec[2]
		var unit := BattleUnit.from_character(_make_char(job))
		unit.row      = row
		unit.col      = col
		unit.crit_rate = 0.0  # シミュではクリティカルなし
		bm.player_grid.grid[row].append(unit)
		if lf:
			lf.store_line("INIT PLAYER job=%d hp=%d atk=%d side=%d row=%d col=%d" % [
				int(job), unit.hp, unit.attack, unit.side, unit.row, unit.col])

	var eu := BattleUnit.from_enemy(enemy_data, 0, 0)
	bm.enemy_grid.grid[0].append(eu)
	if lf:
		lf.store_line("INIT ENEMY hp=%d atk=%d side=%d row=%d col=%d" % [
			eu.hp, eu.attack, eu.side, eu.row, eu.col])

	# シグナル hookup: 4つ全部 deferred で即解決（実機アニメ待ちをバイパス）
	bm.rotated.connect(func() -> void:
		bm.rotate_anim_done.emit.call_deferred())
	bm.phase_started.connect(func(phase: StringName) -> void:
		if phase == &"recovery":
			bm.self_heal_anim_done.emit.call_deferred())
	bm.row_heal_batch.connect(func(_e: Array) -> void:
		bm.row_heal_anim_done.emit.call_deferred())
	bm.unit_acted.connect(func(_a: BattleUnit, _t: BattleUnit, _d: int, _c: bool) -> void:
		bm.unit_action_anim_done.emit.call_deferred())

	if lf:
		bm.unit_acted.connect(func(a: BattleUnit, t: BattleUnit, d: int, _c: bool) -> void:
			lf.store_line("  T%d ACT: [job=%s side=%d hp=%d] → [job=%s side=%d hp=%d] dmg=%d" % [
				bm.turn_number,
				str(int((a.source_data as CharacterData).job)) if a.source_data is CharacterData else "E",
				a.side, a.hp,
				str(int((t.source_data as CharacterData).job)) if t.source_data is CharacterData else "E",
				t.side, t.hp, d]))
		bm.unit_died.connect(func(u: BattleUnit) -> void:
			lf.store_line("  DIED: side=%d hp=%d row=%d col=%d" % [u.side, u.hp, u.row, u.col]))
		bm.battle_ended.connect(func(pw: bool, _l: Array) -> void:
			lf.store_line("BATTLE_ENDED player_won=%s turns=%d" % [str(pw), bm.turn_number]))

	# bool は値型コピーキャプチャになるため Dictionary で包んで参照キャプチャにする
	var result := {"won": false}
	bm.battle_ended.connect(func(player_won: bool, _loot: Array) -> void:
		result["won"] = player_won)

	var first := true
	while not bm.is_over:
		var do_rotate := false
		if not first:
			match strategy:
				"ROTATE":
					do_rotate = true
				"STAY":
					do_rotate = false
				"ADAPTIVE_B3":
					# B3 cycle [CHARGE(0), NORMAL2x(1), STONE(2), ROW(3)]
					# cycle_pos==1 はチャージ後の2倍単発 → STAY で堅い前列に受けさせる / それ以外は ROTATE
					do_rotate = not (bm.turn_number % 4 == 1)
				"SMART":
					do_rotate = _smart_should_rotate(bm)
		await bm.advance_turn(do_rotate)
		first = false

	var turns := bm.turn_number
	bm.queue_free()
	return {"won": result["won"], "turns": turns}

# ──────── 汎用 competent-player 戦略（SMART・1手先読み貪欲）────────
# AIが使う情報は「味方の各ステ/HP」＋「開示された敵の次行動」のみ（決め打ちの答えは持たない）。
# STAY/ROTATE で誰が死ぬか予測し、死なない方を選ぶ。両方安全なら傷ついた前列を後列へ回す。
func _smart_should_rotate(bm: BattleManager) -> bool:
	var enemy: BattleUnit = bm.enemy_grid.grid[0][0]
	var ed := enemy.source_data as EnemyData
	if ed == null or ed.action_cycle.is_empty():
		return false
	# 次ターン(turn_number+1)の敵行動を開示情報から引く（_execute_enemy_action と同じ添字）
	var next_turn := bm.turn_number + 1
	var action: int = ed.action_cycle[(next_turn - 1) % ed.action_cycle.size()]

	var grid: Array = bm.player_grid.grid
	# STAY: 前列=row0・防補源=row1 ／ ROTATE後: 前列=row1・防補源=row2
	var stay_deaths := _predict_deaths(enemy, ed, action, _alive(grid[0]), _alive(grid[1]))
	var rot_deaths  := _predict_deaths(enemy, ed, action, _alive(grid[1]), _alive(grid[2]))

	if stay_deaths == 0 and rot_deaths > 0:
		return false
	if rot_deaths == 0 and stay_deaths > 0:
		return true
	if stay_deaths > 0 and rot_deaths > 0:
		return rot_deaths < stay_deaths  # どちらも危険ならマシな方
	# 両方安全：傷ついた前列があれば後列へ回して治す
	for u: BattleUnit in _alive(grid[0]):
		if u.hp * 2 < u.hp_max:
			return true
	return false

func _alive(row: Array) -> Array:
	return row.filter(func(u: BattleUnit) -> bool: return u.is_alive)

# 次行動で front の何体が死ぬかを予測（mid の同列防補で軽減）
func _predict_deaths(enemy: BattleUnit, ed: EnemyData, action: int, front: Array, mid: Array) -> int:
	if action == EnemyData.ActionType.CHARGE or front.is_empty():
		return 0
	# 実効ATK：溜め倍率＋初回ボーナス（ローテで初回は復活するので保守的に加算）
	var eff_atk: int = ceili(float(enemy.attack) * enemy.charge_multiplier) + ed.initial_attack_bonus
	if action == EnemyData.ActionType.ROW:
		var deaths := 0
		for u: BattleUnit in front:
			# 石化中のユニットへの一撃は×1.5（PETRIFIED_MULT）
			var a: int = ceili(float(eff_atk) * (BattleMath.PETRIFIED_MULT if u.is_petrified else 1.0))
			if u.hp <= maxi(0, a - _def_support_for(u, mid)):
				deaths += 1
		return deaths
	# 単体系：狙い対象を予測して致死判定
	var target := _predict_target(ed.thought_type, front)
	if target == null:
		return 0
	var hits := 1
	if action == EnemyData.ActionType.DOUBLE: hits = 2
	elif action == EnemyData.ActionType.TRIPLE: hits = 3
	elif action == EnemyData.ActionType.QUAD: hits = 4
	var petrified_mult: float = BattleMath.PETRIFIED_MULT if target.is_petrified else 1.0
	# 1発目=eff_atk-防補、2発目以降=素のATK（防補・溜めは初回のみ、石化倍率は全ヒットに乗る）
	var first: int = ceili(float(eff_atk) * petrified_mult)
	var total := maxi(0, first - _def_support_for(target, mid))
	if hits > 1:
		total += (hits - 1) * ceili(float(enemy.attack) * petrified_mult)
	return 1 if target.hp <= total else 0

func _def_support_for(unit: BattleUnit, mid: Array) -> int:
	for m: BattleUnit in mid:
		if m.col == unit.col and m.def_bonus > 0:
			return m.def_bonus
	return 0

# thought_type を前列内で近似（プレイヤーが読める挙動の範囲で）
func _predict_target(thought: int, front: Array) -> BattleUnit:
	if front.is_empty():
		return null
	match thought:
		EnemyData.ThoughtType.HIGH_ATK_TARGET:
			var best_atk: BattleUnit = front[0]
			for u: BattleUnit in front:
				if u.attack > best_atk.attack: best_atk = u
			return best_atk
		EnemyData.ThoughtType.HIGH_HP_TARGET:
			var best_hp: BattleUnit = front[0]
			for u: BattleUnit in front:
				if u.hp > best_hp.hp: best_hp = u
			return best_hp
		EnemyData.ThoughtType.SUPPORT_TARGET:
			for u: BattleUnit in front:
				if u.atk_bonus > 0 or u.def_bonus > 0:
					return u
			return _lowest_hp(front)  # 補助持ちが居なければ最脆を保守的に見る
		_:
			# きまぐれ/弱者/瀕死等：最脆が死にうるか（保守的）
			return _lowest_hp(front)

func _lowest_hp(front: Array) -> BattleUnit:
	var low: BattleUnit = front[0]
	for u: BattleUnit in front:
		if u.hp < low.hp: low = u
	return low

# K試行を回して集計し stdout に1行出力
func _run_scenario(label: String, formation: Array, enemy: EnemyData,
				   strategy: String, expect: String) -> void:
	var wins     := 0
	var total_turns := 0
	var timeouts := 0

	var log_file: FileAccess = null
	if verbose:
		log_file = FileAccess.open("user://sim_log_%s.txt" % label, FileAccess.WRITE)

	for i in K:
		# 最初の1試行だけ詳細ログを渡す（verbose=true のとき）
		var detail_lf: FileAccess = log_file if (verbose and i == 0) else null
		var r: Dictionary = await _run_trial(formation, enemy, strategy, detail_lf)
		if r.won:
			wins += 1
		total_turns += r.turns
		if r.turns > BattleManager.TURN_LIMIT:
			timeouts += 1
		if log_file:
			log_file.store_line("trial%d: won=%s turns=%d" % [i, r.won, r.turns])

	if log_file:
		log_file.close()

	var win_rate  := int(float(wins) / float(K) * 100.0)
	var avg_turns := float(total_turns) / float(K)
	var deaths    := K - wins - timeouts

	var defeat_str := ""
	if timeouts > 0:
		defeat_str += "timeout×%d" % timeouts
	if deaths > 0:
		if defeat_str.length() > 0:
			defeat_str += " "
		defeat_str += "death×%d" % deaths
	if defeat_str.is_empty():
		defeat_str = "-"

	var ok := _check_ok(label, win_rate)
	var ok_mark := ("ok" if ok else "NG") if ASSERT_BALANCE else "(較正保留)"
	print("%s: 勝率%d%% 平均%.1fT 敗因:%s  [期待%s %s]" % [
		label, win_rate, avg_turns, defeat_str, expect, ok_mark])
	# 常時検証する不変条件：全試行が勝ち/death/timeout のいずれかに計上されている
	assert_eq(wins + deaths + timeouts, K, "%s 試行集計が不整合" % label)
	if ASSERT_BALANCE:
		assert_true(ok, "%s 勝率%d%% が期待範囲(%s)を外れた" % [label, win_rate, expect])

func _check_ok(label: String, win_rate: int) -> bool:
	match label:
		"B1-R": return win_rate >= 70  # 味方リバランス＋列攻撃追加で75%に微減（2026-07-02実測）
		"B1-S": return win_rate <= 30
		"B2-S": return win_rate >= 70
		"B2-R": return win_rate <= 10
		"B3-A": return win_rate >= 70
		"B3-R": return win_rate <= 30
		"B3-S": return win_rate <= 30
	return true

# ──────── テスト本体 ────────

## 個体差（±20%切り上げ）が勝率にどれだけ影響するかを測る。assert なし・参考出力のみ。
## 主要3シナリオ（B1-R / B2-S / B3-A）を「固定値 → 個体差あり」で各K回まわし勝率差を見る。
func test_variance_impact() -> void:
	var b1_enemy := _make_enemy(280, 14, 10, 0,
		EnemyData.ThoughtType.RANDOM,
		[EnemyData.ActionType.NORMAL, EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.ROW, EnemyData.ActionType.NORMAL] as Array[int], 5, 0)
	var b2_enemy := _make_enemy(350, 8, 5, 42,
		EnemyData.ThoughtType.HIGH_HP_TARGET,
		[EnemyData.ActionType.NORMAL, EnemyData.ActionType.DOUBLE,
		 EnemyData.ActionType.NORMAL, EnemyData.ActionType.ABSORB] as Array[int], 8, 4)
	var b3_enemy := _make_enemy(225, 11, 14, 6,
		EnemyData.ThoughtType.SUPPORT_TARGET,
		[EnemyData.ActionType.CHARGE, EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.STONE, EnemyData.ActionType.ROW] as Array[int], 10, 0)
	var b1_form: Array = [
		[CharacterJob.Type.WARRIOR, 0, 0], [CharacterJob.Type.ARCHER, 0, 1],
		[CharacterJob.Type.ILLUSIONIST, 0, 2], [CharacterJob.Type.WITCH, 1, 0],
		[CharacterJob.Type.CLERIC, 1, 1], [CharacterJob.Type.MONK, 2, 0],
		[CharacterJob.Type.KNIGHT, 2, 1]]
	var b2_form: Array = [
		[CharacterJob.Type.GLADIATOR, 0, 0], [CharacterJob.Type.SAMURAI, 0, 1],
		[CharacterJob.Type.WARRIOR, 0, 2], [CharacterJob.Type.ADVENTURER, 1, 0],
		[CharacterJob.Type.WITCH, 1, 1], [CharacterJob.Type.ARCHER, 2, 0],
		[CharacterJob.Type.KNIGHT, 2, 2]]
	var b3_form: Array = [
		[CharacterJob.Type.WARRIOR, 0, 0], [CharacterJob.Type.SAMURAI, 0, 1],
		[CharacterJob.Type.GLADIATOR, 0, 2], [CharacterJob.Type.CLERIC, 1, 0],
		[CharacterJob.Type.WITCH, 1, 1], [CharacterJob.Type.KNIGHT, 1, 2],
		[CharacterJob.Type.MONK, 2, 0]]

	print("=== 個体差の影響測定（各K=%d・個体差なし→あり）===" % K)
	_variance = false
	await _run_scenario("B1-R 固定  ", b1_form, b1_enemy, "ROTATE",      "参考")
	await _run_scenario("B2-S 固定  ", b2_form, b2_enemy, "STAY",        "参考")
	await _run_scenario("B3-A 固定  ", b3_form, b3_enemy, "ADAPTIVE_B3", "参考")
	_variance = true
	await _run_scenario("B1-R 個体差", b1_form, b1_enemy, "ROTATE",      "参考")
	await _run_scenario("B2-S 個体差", b2_form, b2_enemy, "STAY",        "参考")
	await _run_scenario("B3-A 個体差", b3_form, b3_enemy, "ADAPTIVE_B3", "参考")
	_variance = false

func test_balance_check() -> void:
	# ── 敵データ（proto1_3battle_design.md §2 確定値） ──
	var b1_enemy := _make_enemy(280, 14, 10, 0,
		EnemyData.ThoughtType.RANDOM,
		[EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.ROW,
		 EnemyData.ActionType.NORMAL] as Array[int],
		5, 0)

	# 旧STRONG_TARGET(HP基準)は表示文言と食い違うバグと判明しHIGH_HP_TARGET/HIGH_ATK_TARGETに分離。
	# HIGH_ATK_TARGET(固定標的)はSTAY永続前提のB2設計と衝突（防補はローテでしか復活せずSTAY中は1回のみ
	# →固定標的は必ず死ぬ）と判明・B2はHIGH_HP_TARGET（狙いが揺れダメージ分散）に据え置き（2026-07-02〜03）。
	# 敵自己回復がdo_rotate無視で毎ターン発動していたバグを2026-07-04に修正。STAY戦略は一切ローテしない
	# ため修正後はregenがSTAY中は永久に無風になる＝「壁」の主表現をHPへ完全移行しHP150→350へ再格上げ
	# （regen42はRotateチート潰し用として維持。B2-S 100%@6T・B2-R 0%@11Tで修正前と同水準に収束）
	var b2_enemy := _make_enemy(350, 8, 5, 42,
		EnemyData.ThoughtType.HIGH_HP_TARGET,
		[EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.DOUBLE,
		 EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.ABSORB] as Array[int],
		8, 4)

	var b3_enemy := _make_enemy(225, 11, 14, 6,
		EnemyData.ThoughtType.SUPPORT_TARGET,
		[EnemyData.ActionType.CHARGE,
		 EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.STONE,
		 EnemyData.ActionType.ROW] as Array[int],
		10, 0)

	# ── 編成テーブル（§5.3） ──
	# B1: (r0c0)戦士 (r0c1)弓 (r0c2)幻 | (r1c0)魔女 (r1c1)神官 | (r2c0)僧侶 (r2c1)騎士
	var b1_form: Array = [
		[CharacterJob.Type.WARRIOR,     0, 0],
		[CharacterJob.Type.ARCHER,      0, 1],
		[CharacterJob.Type.ILLUSIONIST, 0, 2],
		[CharacterJob.Type.WITCH,       1, 0],
		[CharacterJob.Type.CLERIC,      1, 1],
		[CharacterJob.Type.MONK,        2, 0],
		[CharacterJob.Type.KNIGHT,      2, 1],
	]

	# B2: (r0c0)剣 (r0c1)侍 (r0c2)戦士 | (r1c0)冒 (r1c1)魔女 | (r2c0)弓 (r2c2)騎士
	var b2_form: Array = [
		[CharacterJob.Type.GLADIATOR,  0, 0],
		[CharacterJob.Type.SAMURAI,    0, 1],
		[CharacterJob.Type.WARRIOR,    0, 2],
		[CharacterJob.Type.ADVENTURER, 1, 0],
		[CharacterJob.Type.WITCH,      1, 1],
		[CharacterJob.Type.ARCHER,     2, 0],
		[CharacterJob.Type.KNIGHT,     2, 2],
	]

	# B3: (r0c0)戦士 (r0c1)侍 (r0c2)剣 | (r1c0)神官 (r1c1)魔女 (r1c2)騎士 | (r2c0)僧侶
	var b3_form: Array = [
		[CharacterJob.Type.WARRIOR,   0, 0],
		[CharacterJob.Type.SAMURAI,   0, 1],
		[CharacterJob.Type.GLADIATOR, 0, 2],
		[CharacterJob.Type.CLERIC,    1, 0],
		[CharacterJob.Type.WITCH,     1, 1],
		[CharacterJob.Type.KNIGHT,    1, 2],
		[CharacterJob.Type.MONK,      2, 0],
	]

	# ── シナリオ実行（集計のみ stdout へ） ──
	await _run_scenario("B1-R", b1_form, b1_enemy, "ROTATE",       ">=80%")
	await _run_scenario("B1-S", b1_form, b1_enemy, "STAY",         "<=30%")
	await _run_scenario("B2-S", b2_form, b2_enemy, "STAY",         ">=70%")
	await _run_scenario("B2-R", b2_form, b2_enemy, "ROTATE",       "~=0%")
	await _run_scenario("B3-A", b3_form, b3_enemy, "ADAPTIVE_B3",  ">=70%")
	await _run_scenario("B3-R", b3_form, b3_enemy, "ROTATE",       "<=30%")
	await _run_scenario("B3-S", b3_form, b3_enemy, "STAY",         "<=30%")

	# ── DIV シナリオ（9種）──
	# _check_ok 未定義ラベル → return true → assert 無効、勝率 print のみ

	# B1-W1: B1 重攻撃型（前衛 SAMURAI24+NINJA12+SHAMAN14、mid GLADIATOR攻補12。proto1正規職）
	var b1_w1_form: Array = [
		[CharacterJob.Type.SHAMAN,      0, 0],
		[CharacterJob.Type.NINJA,       0, 1],
		[CharacterJob.Type.SAMURAI,     0, 2],
		[CharacterJob.Type.GLADIATOR,   1, 0],
		[CharacterJob.Type.WARRIOR,     1, 1],
		[CharacterJob.Type.KNIGHT,      2, 0],
		[CharacterJob.Type.MONK,        2, 1],
	]

	# B1-L: B1 唯一の負け筋＝消耗死。VALKYRIE(hp18)/ILLUSIONIST(hp22) の脆い前衛が
	#   ROTATEでも atk=13 RANDOM に削り殺される。B1は regen=0 なので火力不足では負けない＝
	#   負けるには「死ぬ」しかない（→ DIV検証で判明・devlog 2026-06-30 参照）
	var b1_l_fragile_form: Array = [
		[CharacterJob.Type.WARRIOR,     0, 0],
		[CharacterJob.Type.VALKYRIE,    0, 1],
		[CharacterJob.Type.ILLUSIONIST, 0, 2],
		[CharacterJob.Type.ADVENTURER,  1, 0],
		[CharacterJob.Type.WITCH,       1, 1],
		[CharacterJob.Type.CLERIC,      2, 0],
		[CharacterJob.Type.MONK,        2, 1],
	]

	# B2-W: B2 高DPS STAY（前衛 GLADIATOR22+SAMURAI24+NINJA12=58 > regen55、mid WITCH攻補13。proto1正規職）
	var b2_w_form: Array = [
		[CharacterJob.Type.GLADIATOR,   0, 0],
		[CharacterJob.Type.SAMURAI,     0, 1],
		[CharacterJob.Type.NINJA,       0, 2],
		[CharacterJob.Type.WITCH,       1, 0],
		[CharacterJob.Type.WARRIOR,     1, 1],
		[CharacterJob.Type.MONK,        2, 0],
		[CharacterJob.Type.ARCHER,      2, 1],
	]

	# B3-W: A編成のDPS/耐久プロファイルを踏襲（前列WARRIOR/SAMURAI/GLADIATOR=A同型）。
	#   A勝因の核心＝KNIGHT(防補18)がGLADIATORと同列(col2)にいて庇っている（防補は同列のみ有効）。
	#   これを外した初期案はGLADIATORが素で22食らい自己回復もなく詰んだ＝2026-07-02判明。
	#   差別化は中列col0/1＝非補助の間接火力、後列＝MONK/CLERIC列回復ペアを同じ行に固め相互回復
	var b3_w_form: Array = [
		[CharacterJob.Type.WARRIOR,     0, 0],
		[CharacterJob.Type.SAMURAI,     0, 1],
		[CharacterJob.Type.GLADIATOR,   0, 2],
		[CharacterJob.Type.ARCHER,      1, 0],
		[CharacterJob.Type.KNIGHT,      1, 2],
		[CharacterJob.Type.MONK,        2, 0],
		[CharacterJob.Type.CLERIC,      2, 1],
	]

	# B1-W2: B1 低火力タンク粘り型の勝ち。B1は regen=0 なので正味DPSが正なら時間で
	#   360HPを削り切れる＝低火力でも"死なない"編成は勝てる（B1=生存チェックの証拠）
	var b1_w2_tank_form: Array = [
		[CharacterJob.Type.MAGE,          0, 0],
		[CharacterJob.Type.SHAMAN,        0, 1],
		[CharacterJob.Type.SHRINE_MAIDEN, 0, 2],
		[CharacterJob.Type.CLERIC,        1, 0],
		[CharacterJob.Type.ILLUSIONIST,   1, 1],
		[CharacterJob.Type.MONK,          2, 0],
		[CharacterJob.Type.ADVENTURER,    2, 1],
	]

	# B2-L-close: B2 前衛 atk=20+16+12=48 < regen55（ギリ届かない）
	var b2_l_close_form: Array = [
		[CharacterJob.Type.WARRIOR,    0, 0],
		[CharacterJob.Type.ARCHER,     0, 1],
		[CharacterJob.Type.KNIGHT,     0, 2],
		[CharacterJob.Type.WITCH,      1, 0],
		[CharacterJob.Type.ADVENTURER, 1, 1],
		[CharacterJob.Type.CLERIC,     2, 0],
		[CharacterJob.Type.MONK,       2, 1],
	]

	# B2-L-far: B2 前衛 atk=8+14+8=30 << regen55（余裕の敗北）
	var b2_l_far_form: Array = [
		[CharacterJob.Type.MAGE,          0, 0],
		[CharacterJob.Type.SHAMAN,        0, 1],
		[CharacterJob.Type.CLERIC,        0, 2],
		[CharacterJob.Type.SHRINE_MAIDEN, 1, 0],
		[CharacterJob.Type.MONK,          1, 1],
		[CharacterJob.Type.ADVENTURER,    2, 0],
		[CharacterJob.Type.KNIGHT,        2, 1],
	]

	# B3-L-close: B3 補助ユニット前衛（SUPPORT_TARGET に狙われ崩れる）
	var b3_l_close_form: Array = [
		[CharacterJob.Type.GLADIATOR,   0, 0],  # atk_bonus=12 → ターゲット
		[CharacterJob.Type.WARRIOR,     0, 1],
		[CharacterJob.Type.KNIGHT,      0, 2],  # def_bonus=12 → ターゲット
		[CharacterJob.Type.ADVENTURER,  1, 0],
		[CharacterJob.Type.WITCH,       1, 1],
		[CharacterJob.Type.ARCHER,      2, 0],
		[CharacterJob.Type.ILLUSIONIST, 2, 1],
	]

	# B3-L-far: B3 補助高密度前衛＋STAY（CHARGE 2x で即溶ける）
	var b3_l_far_form: Array = [
		[CharacterJob.Type.WITCH,        0, 0],  # atk_bonus=13 def_bonus=13 → 補助狙いの的
		[CharacterJob.Type.CLERIC,       0, 1],  # def_bonus=20 hp=18
		[CharacterJob.Type.MAGE,         0, 2],  # atk_bonus=20 hp=20
		[CharacterJob.Type.SHAMAN,       1, 0],
		[CharacterJob.Type.MONK,         1, 1],
		[CharacterJob.Type.SHRINE_MAIDEN,2, 0],
		[CharacterJob.Type.ADVENTURER,   2, 1],
	]

	await _run_scenario("B1-W1",     b1_w1_form,        b1_enemy, "ROTATE",      ">=70%")
	await _run_scenario("B1-W2",     b1_w2_tank_form,   b1_enemy, "ROTATE",      ">=60%")
	await _run_scenario("B2-W",      b2_w_form,         b2_enemy, "STAY",        ">=60%")
	await _run_scenario("B3-W",      b3_w_form,         b3_enemy, "ADAPTIVE_B3", ">=60%")
	await _run_scenario("B1-L",      b1_l_fragile_form, b1_enemy, "ROTATE",      "<=30%")
	await _run_scenario("B2-L-close",b2_l_close_form,b2_enemy, "STAY",        "~0%")
	await _run_scenario("B2-L-far",  b2_l_far_form,  b2_enemy, "STAY",        "~0%")
	await _run_scenario("B3-L-close",b3_l_close_form,b3_enemy, "ADAPTIVE_B3", "<=30%")
	await _run_scenario("B3-L-far",  b3_l_far_form,  b3_enemy, "STAY",        "~0%")

	# ── SMART戦略（汎用competent-player）での再測定。B3の勝敗はこれで見る ──
	await _run_scenario("B3-A-SMART",   b3_form,        b3_enemy, "SMART", "勝てるか")
	await _run_scenario("B3-W-SMART",   b3_w_form,      b3_enemy, "SMART", "勝てるか")
	await _run_scenario("B3-Lc-SMART",  b3_l_close_form,b3_enemy, "SMART", "悪編成は負ける")
	await _run_scenario("B3-Lf-SMART",  b3_l_far_form,  b3_enemy, "SMART", "悪編成は負ける")
