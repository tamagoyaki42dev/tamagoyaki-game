extends GutTest

# 3戦バランス検証シミュ。stdout は集計サマリのみ（per-trial ログは verbose=true 時のみ user://sim_log.txt へ）
const K := 100

# 味方15職リバランス（2026-07-01）で旧較正勝率が無効化された。
# 敵側の再調整＋再較正が済むまで較正assertを保留し、勝率は print のみ出す。
# 敵スタット確定後に true へ戻し、_check_ok の期待値を新balanceに合わせて更新すること。
const ASSERT_BALANCE := false

@export var verbose: bool = false

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
					# B3 cycle [CHARGE(0), NORMAL2x(1), NORMAL(2), NORMAL(3)]
					# cycle_pos==1 はチャージ後の大ダメ → STAY で強列を守る / それ以外は ROTATE
					do_rotate = not (bm.turn_number % 4 == 1)
		await bm.advance_turn(do_rotate)
		first = false

	var turns := bm.turn_number
	bm.queue_free()
	return {"won": result["won"], "turns": turns}

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
		"B1-R": return win_rate >= 80
		"B1-S": return win_rate <= 30
		"B2-S": return win_rate >= 70
		"B2-R": return win_rate <= 10
		"B3-A": return win_rate >= 70
		"B3-R": return win_rate <= 30
		"B3-S": return win_rate <= 30
	return true

# ──────── テスト本体 ────────

func test_balance_check() -> void:
	# ── 敵データ（proto1_3battle_design.md §2 確定値） ──
	var b1_enemy := _make_enemy(360, 13, 10, 0,
		EnemyData.ThoughtType.RANDOM,
		[EnemyData.ActionType.NORMAL] as Array[int],
		5, 0)

	var b2_enemy := _make_enemy(110, 8, 5, 55,
		EnemyData.ThoughtType.STRONG_TARGET,
		[EnemyData.ActionType.NORMAL] as Array[int],
		8, 4)

	var b3_enemy := _make_enemy(180, 16, 14, 6,
		EnemyData.ThoughtType.SUPPORT_TARGET,
		[EnemyData.ActionType.CHARGE,
		 EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.NORMAL,
		 EnemyData.ActionType.NORMAL] as Array[int],
		10, 5)

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

	# B1-W1: B1 重攻撃型（前衛 atk=22+18+24=64）
	var b1_w1_form: Array = [
		[CharacterJob.Type.DARK_KNIGHT, 0, 0],
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

	# B2-W: B2 高DPS STAY（前衛 atk=22+24+18=64 > regen55）
	var b2_w_form: Array = [
		[CharacterJob.Type.DARK_KNIGHT, 0, 0],
		[CharacterJob.Type.SAMURAI,     0, 1],
		[CharacterJob.Type.NINJA,       0, 2],
		[CharacterJob.Type.GLADIATOR,   1, 0],
		[CharacterJob.Type.WARRIOR,     1, 1],
		[CharacterJob.Type.MONK,        2, 0],
		[CharacterJob.Type.ARCHER,      2, 1],
	]

	# B3-W: B3 タンク前衛＋後衛回復（HOLY_KNIGHT row_regen=18 / CLERIC row_regen=15）
	var b3_w_form: Array = [
		[CharacterJob.Type.DARK_KNIGHT, 0, 0],
		[CharacterJob.Type.WARRIOR,     0, 1],
		[CharacterJob.Type.SAMURAI,     0, 2],
		[CharacterJob.Type.NINJA,       1, 0],
		[CharacterJob.Type.KNIGHT,      1, 1],
		[CharacterJob.Type.HOLY_KNIGHT, 2, 0],
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
		[CharacterJob.Type.HOLY_KNIGHT,  0, 0],  # atk_bonus=22 def_bonus=18 → 最優先
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
