class_name BattleManager
extends Node

signal battle_started(player_grid: RotationGrid, enemy_grid: RotationGrid)
signal turn_started(turn_number: int, timeline: Array, enemy_action: String)
signal unit_acted(attacker: BattleUnit, target: BattleUnit, damage: int, is_crit: bool)
signal unit_died(unit: BattleUnit)
signal unit_healed(unit: BattleUnit, amount: int)
signal unit_petrified(unit: BattleUnit)
signal unit_stone_cleared(unit: BattleUnit)
signal rotated()
signal action_announced(action_name: String)
signal battle_ended(player_won: bool, loot: Array)
signal attack_support_used(supporter: BattleUnit, attacker: BattleUnit)
signal defense_support_used(supporter: BattleUnit, target: BattleUnit)

const TURN_LIMIT    = 100
const ACTION_DELAY  : float = 1.0   # アクション後の待機
const ROTATE_DELAY  : float = 0.9   # ローテーションアニメ待ち
const SUPPORT_DELAY : float = 1.0   # 補助演出→攻撃の間隔

var player_grid: RotationGrid
var enemy_grid: RotationGrid
var turn_number: int = 0
var is_over: bool = false
var _unpetrified_this_turn: Array = []

func start_battle(player_data: Array, enemy_data: Array) -> void:
	turn_number = 0
	is_over     = false
	player_grid = RotationGrid.new()
	enemy_grid  = RotationGrid.new()
	# formation経由の場合はDict。row順→col順にソートして追加することで列番号を保持
	var pd := player_data.duplicate()
	if not pd.is_empty() and pd[0] is Dictionary:
		pd.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["row"] < b["row"] if a["row"] != b["row"] else a["col"] < b["col"])
	for item in pd:
		if item is Dictionary:
			var unit := BattleUnit.from_character(item["data"])
			unit.row = item["row"]
			player_grid.add_unit(unit)
			unit.col = item["col"]  # 編成colを保持（add_unitが配列インデックスで上書きするため再設定）
		else:
			player_grid.add_unit(BattleUnit.from_character(item))
	for i in enemy_data.size():
		enemy_grid.add_unit(BattleUnit.from_enemy(enemy_data[i], 0, i))
	battle_started.emit(player_grid, enemy_grid)
	call_deferred("advance_turn", false)

func advance_turn(do_rotate: bool = false) -> void:
	if is_over:
		return
	if do_rotate:
		player_grid.rotate_forward()
		for unit: BattleUnit in player_grid.get_all_alive():
			unit.atk_support_used = false
			unit.def_support_used = false
			unit.is_petrified = false
		for unit: BattleUnit in enemy_grid.get_all_alive():
			unit.is_petrified = false
		rotated.emit()
		await get_tree().create_timer(ROTATE_DELAY).timeout
	turn_number += 1
	if turn_number > TURN_LIMIT:
		_end_battle(false)
		return
	var timeline := build_timeline()
	turn_started.emit(turn_number, timeline, _current_enemy_action_label())
	_unpetrified_this_turn = []
	var already_acted: Array = []
	for attacker: BattleUnit in timeline:
		if not attacker.is_alive or is_over or (attacker in already_acted):
			continue
		if attacker.is_petrified:
			continue
		already_acted.append(attacker)
		await _do_unit_action(attacker)
		await get_tree().create_timer(ACTION_DELAY).timeout
		if is_over:
			return
		# 石化解除されたユニットが既にターンをスキップ済みなら即行動
		for u: BattleUnit in _unpetrified_this_turn.duplicate():
			if u.is_alive and not (u in already_acted):
				already_acted.append(u)
				await _do_unit_action(u)
				await get_tree().create_timer(ACTION_DELAY).timeout
				if is_over:
					return
		_unpetrified_this_turn.clear()
	if enemy_grid.is_wiped():
		_end_battle(true)
		return
	_apply_back_row_healing(player_grid)
	_apply_enemy_healing()
	_emit_action_announcement(turn_number + 1)

func _do_unit_action(attacker: BattleUnit) -> void:
	if attacker.side == BattleUnit.Side.ENEMY:
		await _execute_enemy_action(attacker)
	else:
		await _execute_player_action(attacker)

# ──────────────────── プレイヤー行動 ────────────────────

func _execute_player_action(attacker: BattleUnit) -> void:
	# 間接攻撃（中列ユニットで同縦マスの前列が空いている場合）
	if attacker.row == 1 and attacker.indirect_attack > 0 and _front_col_empty(player_grid, attacker.col):
		var target := _pick_target(attacker)
		if target:
			await _do_hits(attacker, target, attacker.indirect_attack, 1, false, false)
		return

	# 攻撃補助チェック
	var mid := _get_mid_atk_support(player_grid, attacker.col)
	var bonus := 0
	var is_row_attack := false
	if mid:
		attack_support_used.emit(mid, attacker)
		await get_tree().create_timer(SUPPORT_DELAY).timeout
		bonus         = mid.atk_bonus
		is_row_attack = mid.atk_bonus_is_row
		mid.atk_support_used = true
	var base_atk := attacker.attack + bonus

	if is_row_attack:
		# 攻補(列): 前列の攻撃が全敵を対象に。ダメージは敵数で除算
		var enemies := _get_opp_front(enemy_grid)
		if enemies.is_empty():
			return
		var per_atk := ceili(float(base_atk) / float(enemies.size()))
		var had_charge := attacker.charge_excess >= 2 * attacker.hp_max
		for i in attacker.attack_hits:
			for target in enemies.duplicate():
				if is_over or not target.is_alive:
					continue
				await _do_single_hit(attacker, target, per_atk, i == 0,
					attacker.is_stone_attack, false, had_charge and i == 0)
		if had_charge:
			attacker.charge_excess = 0
	else:
		var target := _pick_target(attacker)
		if target:
			await _do_hits(attacker, target, base_atk, attacker.attack_hits, attacker.is_stone_attack, false)

# ──────────────────── 敵行動 ────────────────────

func _execute_enemy_action(attacker: BattleUnit) -> void:
	var enemy_data := attacker.source_data as EnemyData
	var action: int = EnemyData.ActionType.NORMAL
	if enemy_data and not enemy_data.action_cycle.is_empty():
		action = enemy_data.action_cycle[(turn_number - 1) % enemy_data.action_cycle.size()]

	if action == EnemyData.ActionType.CHARGE:
		attacker.charge_multiplier = 2.0
		return

	var eff_atk := ceili(float(attacker.attack) * attacker.charge_multiplier)
	attacker.charge_multiplier = 1.0

	match action:
		EnemyData.ActionType.DOUBLE, EnemyData.ActionType.TRIPLE, EnemyData.ActionType.QUAD:
			var hits := 2
			if action == EnemyData.ActionType.TRIPLE: hits = 3
			elif action == EnemyData.ActionType.QUAD:  hits = 4
			var target := _pick_target(attacker)
			if target:
				for i in hits:
					if is_over or not target.is_alive: break
					# 力を溜めるの倍率は最初の1撃のみ、2撃目以降は素のATK
					var atk := eff_atk if i == 0 else attacker.attack
					await _do_single_hit(attacker, target, atk, i == 0, false, false, false)

		EnemyData.ActionType.ROW:
			for target in player_grid.get_front_row().duplicate():
				if is_over: break
				await _do_single_hit(attacker, target, eff_atk, true, false, false, false)

		EnemyData.ActionType.STONE:
			var target := _pick_target(attacker)
			if target:
				await _do_hits(attacker, target, eff_atk, 1, true, false)

		EnemyData.ActionType.ABSORB:
			var target := _pick_target(attacker)
			if target:
				await _do_hits(attacker, target, eff_atk, 1, false, true)

		_:  # NORMAL
			var target := _pick_target(attacker)
			if target:
				await _do_hits(attacker, target, eff_atk, 1, false, false)

# ──────────────────── ヒット処理 ────────────────────

# N回攻撃をまとめて処理。チャージは最初の1撃のみ適用
func _do_hits(attacker: BattleUnit, target: BattleUnit, base_atk: int,
			hits: int, apply_stone: bool, apply_absorb: bool) -> void:
	var had_charge := attacker.charge_excess >= 2 * attacker.hp_max
	for i in hits:
		if is_over or not target.is_alive:
			break
		await _do_single_hit(attacker, target, base_atk, i == 0, apply_stone, apply_absorb, had_charge and i == 0)
	if had_charge:
		attacker.charge_excess = 0

# 1回のヒット処理（クリティカル・チャージ・石化・前列空き・防御補助・HP吸収）
func _do_single_hit(attacker: BattleUnit, target: BattleUnit, base_atk: int,
					is_first: bool, apply_stone: bool, apply_absorb: bool,
					had_charge: bool) -> void:
	if is_over or not target.is_alive:
		return

	# 倍率計算（全て乗算、端数は最後に切り上げ）
	var mult := 1.0
	var is_crit := randf() < attacker.crit_rate
	if is_crit:
		mult *= 1.5
	if is_first and had_charge:
		var cm := minf(4.0, float(attacker.hp_max + attacker.charge_excess) / float(attacker.hp_max) / 2.0)
		mult *= cm
	if target.is_petrified:
		mult *= 1.5
	var raw := ceili(float(base_atk) * mult)

	# 前列空きによる2倍ダメージ（敵→味方のみ）
	if attacker.side == BattleUnit.Side.ENEMY and target.side == BattleUnit.Side.PLAYER:
		if target.row == 1 and player_grid.get_front_row().is_empty():
			raw *= 2
		elif target.row == 2 and player_grid.get_front_row().is_empty() and player_grid.get_row(1).is_empty():
			raw *= 2

	# 防御補助（最初のヒットのみ）→ 演出後に攻撃
	var def_support := 0
	if is_first and attacker.side == BattleUnit.Side.ENEMY and target.side == BattleUnit.Side.PLAYER:
		var mid := _get_mid_def_support(player_grid, target.col)
		if mid:
			defense_support_used.emit(mid, target)
			def_support = mid.def_bonus
			mid.def_support_used = true
			await get_tree().create_timer(SUPPORT_DELAY).timeout

	var actual: int = max(0, raw - def_support)

	# 石化判定（ダメージ0なら発動しない）
	if apply_stone and actual > 0:
		if target.is_petrified:
			target.is_petrified = false
			unit_stone_cleared.emit(target)
			_unpetrified_this_turn.append(target)
		else:
			target.is_petrified = true
			unit_petrified.emit(target)

	# クリティカルチャージ蓄積をリセット（ダメージを受けたとき・味方のみ）
	if actual > 0 and target.side == BattleUnit.Side.PLAYER:
		target.charge_excess = 0

	target.hp = max(0, target.hp - actual)
	unit_acted.emit(attacker, target, actual, is_crit)

	# HP吸収（実ダメージの50%を回復）
	if apply_absorb and actual > 0:
		var absorb := ceili(float(actual) * 0.5)
		attacker.hp = min(attacker.hp_max, attacker.hp + absorb)
		unit_healed.emit(attacker, absorb)

	if not target.is_alive:
		unit_died.emit(target)
		if target.side == BattleUnit.Side.PLAYER:
			_end_battle(false)

# ──────────────────── 後列回復 ────────────────────

func _apply_back_row_healing(grid: RotationGrid) -> void:
	for unit: BattleUnit in grid.get_row(2):
		if not unit.is_alive:
			continue
		if unit.self_regen > 0:
			_apply_healing(unit, unit.self_regen)
		if unit.row_regen > 0:
			for other: BattleUnit in grid.get_row(unit.row):
				if other != unit:
					_apply_healing(other, unit.row_regen)

func _apply_enemy_healing() -> void:
	for unit: BattleUnit in enemy_grid.get_all_alive():
		if unit.self_regen > 0:
			var old_hp := unit.hp
			unit.hp = mini(unit.hp_max, unit.hp + unit.self_regen)
			if unit.hp > old_hp:
				unit_healed.emit(unit, unit.hp - old_hp)

# 回復処理。満タン以上の回復量はクリティカルチャージ蓄積へ
func _apply_healing(unit: BattleUnit, amount: int) -> void:
	if not unit.is_alive or amount <= 0:
		return
	var old_hp := unit.hp
	unit.hp = mini(unit.hp_max, unit.hp + amount)
	var healed := unit.hp - old_hp
	var overheal := amount - healed
	unit_healed.emit(unit, healed)  # HP満タンでも発火（healed=0 = MAX表示用）
	if overheal > 0:
		unit.charge_excess += overheal

# ──────────────────── タイムライン ────────────────────

func build_timeline() -> Array:
	var all: Array = []
	all += player_grid.get_front_row()
	all += enemy_grid.get_front_row()
	for unit: BattleUnit in player_grid.get_row(1):
		if unit.indirect_attack > 0 and _front_col_empty(player_grid, unit.col):
			all.append(unit)
	for unit: BattleUnit in enemy_grid.get_row(1):
		if unit.indirect_attack > 0 and _front_col_empty(enemy_grid, unit.col):
			all.append(unit)
	var rng_map: Dictionary = {}
	for unit: BattleUnit in all:
		rng_map[unit] = randf()
	all.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		if a.side == b.side:
			return a.col < b.col
		return rng_map[a] < rng_map[b]
	)
	return all

func _front_col_empty(grid: RotationGrid, col: int) -> bool:
	for unit: BattleUnit in grid.get_front_row():
		if unit.col == col:
			return false
	return true

# ──────────────────── ターゲット選択 ────────────────────

func _pick_target(attacker: BattleUnit) -> BattleUnit:
	var opp_grid: RotationGrid = enemy_grid if attacker.side == BattleUnit.Side.PLAYER else player_grid
	var candidates := _get_opp_front(opp_grid)
	if candidates.is_empty():
		return null
	if attacker.side == BattleUnit.Side.PLAYER:
		return candidates[randi() % candidates.size()]
	# 敵の思考タイプに従ってターゲット選択
	var enemy_data := attacker.source_data as EnemyData
	var thought := EnemyData.ThoughtType.RANDOM
	if enemy_data:
		thought = enemy_data.thought_type
	match thought:
		EnemyData.ThoughtType.WEAK_TARGET:
			candidates.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp < b.hp)
			return candidates[0]
		EnemyData.ThoughtType.STRONG_TARGET:
			candidates.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp > b.hp)
			return candidates[0]
		EnemyData.ThoughtType.CENTER_TARGET:
			var center := candidates.filter(func(u: BattleUnit) -> bool: return u.col == 1 or u.col == 2)
			return _weighted_pick(center if not center.is_empty() else candidates)
		EnemyData.ThoughtType.SUPPORT_TARGET:
			var support := candidates.filter(func(u: BattleUnit) -> bool: return u.atk_bonus > 0 or u.def_bonus > 0)
			return _weighted_pick(support if not support.is_empty() else candidates)
		EnemyData.ThoughtType.DYING_TARGET:
			var dying := candidates.filter(func(u: BattleUnit) -> bool: return u.hp * 2 <= u.hp_max)
			return _weighted_pick(dying if not dying.is_empty() else candidates)
		EnemyData.ThoughtType.FEMALE_TARGET:
			var females := candidates.filter(func(u: BattleUnit) -> bool:
				var cd := u.source_data as CharacterData
				return cd != null and CharacterJob.is_female(cd.job)
			)
			return _weighted_pick(females if not females.is_empty() else candidates)
		EnemyData.ThoughtType.MALE_TARGET:
			var males := candidates.filter(func(u: BattleUnit) -> bool:
				var cd := u.source_data as CharacterData
				return cd != null and not CharacterJob.is_female(cd.job)
			)
			return _weighted_pick(males if not males.is_empty() else candidates)
		_:  # RANDOM
			return _weighted_pick(candidates)

func _weighted_pick(candidates: Array) -> BattleUnit:
	if candidates.size() == 1:
		return candidates[0]
	var pool: Array = []
	for unit: BattleUnit in candidates:
		pool.append(unit)
		if unit.col == 1 or unit.col == 2:
			pool.append(unit)  # マス2/3を2倍の重みに
	return pool[randi() % pool.size()]

func _get_opp_front(grid: RotationGrid) -> Array:
	var candidates := grid.get_front_row()
	if candidates.is_empty(): candidates = grid.get_row(1)
	if candidates.is_empty(): candidates = grid.get_all_alive()
	return candidates

# ──────────────────── 補助サポート ────────────────────

# 攻撃補助: 同縦マスのみ（攻補(列)も同縦マスがトリガー。効果だけが列攻撃化）
func _get_mid_atk_support(grid: RotationGrid, attacker_col: int) -> BattleUnit:
	for unit: BattleUnit in grid.get_row(1):
		if not unit.atk_support_used and unit.atk_bonus > 0 and unit.col == attacker_col:
			return unit
	return null

# 防御補助: 同縦マスのみ
func _get_mid_def_support(grid: RotationGrid, target_col: int) -> BattleUnit:
	for unit: BattleUnit in grid.get_row(1):
		if not unit.def_support_used and unit.def_bonus > 0 and unit.col == target_col:
			return unit
	return null

# ──────────────────── ユーティリティ ────────────────────

func _emit_action_announcement(for_turn: int) -> void:
	action_announced.emit(_action_label_for_turn(for_turn))

func _current_enemy_action_label() -> String:
	return _action_label_for_turn(turn_number)

func _action_label_for_turn(for_turn: int) -> String:
	var enemies := enemy_grid.get_front_row()
	if enemies.is_empty():
		enemies = enemy_grid.get_all_alive()
	if enemies.is_empty():
		return ""
	var enemy_data := (enemies[0] as BattleUnit).source_data as EnemyData
	if enemy_data == null or enemy_data.action_cycle.is_empty():
		return "攻撃"
	var cycle_pos: int = (for_turn - 1) % enemy_data.action_cycle.size()
	return EnemyData.get_action_label(enemy_data.action_cycle[cycle_pos])

func _end_battle(player_won: bool) -> void:
	is_over = true
	battle_ended.emit(player_won, [])
