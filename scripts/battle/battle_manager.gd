class_name BattleManager
extends Node

signal battle_started(player_grid: RotationGrid, enemy_grid: RotationGrid)
signal turn_started(turn_number: int, timeline: Array, enemy_action: String)
signal unit_acted(attacker: BattleUnit, target: BattleUnit, damage: int)
signal unit_died(unit: BattleUnit)
signal unit_healed(unit: BattleUnit, amount: int)
signal rotated()
signal action_announced(action_name: String)
signal battle_ended(player_won: bool, loot: Array)

var player_grid: RotationGrid
var enemy_grid: RotationGrid
var turn_number: int = 0
var is_over: bool = false

func start_battle(player_data: Array, enemy_data: Array) -> void:
	turn_number = 0
	is_over     = false

	player_grid = RotationGrid.new()
	enemy_grid  = RotationGrid.new()

	for data in player_data:
		player_grid.add_unit(BattleUnit.from_character(data))

	for i in enemy_data.size():
		# 敵はグリッドなし。row=0固定、col=i で横並び表示用
		enemy_grid.add_unit(BattleUnit.from_enemy(enemy_data[i], 0, i))

	battle_started.emit(player_grid, enemy_grid)
	# Turn 1 は自動実行（次フレームで開始、プレイヤー入力なし）
	call_deferred("advance_turn", false)

# do_rotate=true でローテーション、false でステイ（仕様: デフォルトはステイ）
# ターン構成: step2 ローテーション確定 → step3 戦闘 → step4 後列回復 → step1 次ターン告知
func advance_turn(do_rotate: bool = false) -> void:
	if is_over:
		return

	# step2: ローテーション確定（戦闘前に列を入れ替える）
	if do_rotate:
		player_grid.rotate_forward()
		for unit: BattleUnit in player_grid.get_all_alive():
			unit.support_used = false
		rotated.emit()

	turn_number += 1
	var timeline := build_timeline()
	turn_started.emit(turn_number, timeline, _current_enemy_action_label())

	# step3: 戦闘フェーズ
	for attacker: BattleUnit in timeline:
		if not attacker.is_alive or is_over:
			continue

		if attacker.side == BattleUnit.Side.ENEMY:
			_execute_enemy_action(attacker)
		else:
			var target := _pick_target(attacker)
			if target:
				var is_indirect := attacker.row == 1 and attacker.indirect_attack > 0
				if is_indirect:
					# 間接攻撃には補助は乗らない
					_apply_hit(attacker, target, attacker.indirect_attack)
				else:
					var mid := _get_mid_support(player_grid, attacker.col)
					var bonus := 0
					if mid and mid.atk_bonus > 0:
						bonus = mid.atk_bonus
						mid.support_used = true
					_apply_hit(attacker, target, attacker.attack + bonus)

		if is_over:
			return

	if enemy_grid.is_wiped():
		_end_battle(true)
		return

	# step4: 後列回復フェーズ
	_apply_back_row_healing(player_grid)
	_apply_enemy_healing()

	# 次ターン step1: 敵行動を告知
	_emit_action_announcement(turn_number + 1)

# ──────────────────── 敵行動 ────────────────────

func _execute_enemy_action(attacker: BattleUnit) -> void:
	var enemy_data := attacker.source_data as EnemyData
	var action: int = EnemyData.ActionType.NORMAL
	if enemy_data and not enemy_data.action_cycle.is_empty():
		action = enemy_data.action_cycle[(turn_number - 1) % enemy_data.action_cycle.size()]

	# 力を溜める: 攻撃せず、次ターンのATKを2倍に
	if action == EnemyData.ActionType.CHARGE:
		attacker.charge_multiplier = 2.0
		return

	var eff_atk: int = int(float(attacker.attack) * attacker.charge_multiplier)
	attacker.charge_multiplier = 1.0

	match action:
		EnemyData.ActionType.DOUBLE, EnemyData.ActionType.TRIPLE, EnemyData.ActionType.QUAD:
			var hits: int = 2
			if action == EnemyData.ActionType.TRIPLE: hits = 3
			elif action == EnemyData.ActionType.QUAD:  hits = 4
			var target := _pick_target(attacker)
			if target:
				for i in hits:
					if is_over or not target.is_alive:
						break
					_apply_hit(attacker, target, eff_atk if i == 0 else attacker.attack)

		EnemyData.ActionType.ROW:
			for target in player_grid.get_front_row():
				if is_over:
					break
				_apply_hit(attacker, target, eff_atk)

		_:  # NORMAL / STONE / ABSORB（石化・吸収は未実装: 通常攻撃として処理）
			var target := _pick_target(attacker)
			if target:
				_apply_hit(attacker, target, eff_atk)

func _apply_hit(attacker: BattleUnit, target: BattleUnit, atk: int) -> void:
	if is_over or not target.is_alive:
		return
	var def_support := 0
	if attacker.side == BattleUnit.Side.ENEMY and target.side == BattleUnit.Side.PLAYER:
		var mid := _get_mid_support(player_grid, target.col)
		if mid and mid.def_bonus > 0:
			def_support = mid.def_bonus
			mid.support_used = true
	var damage := target.take_damage(atk, def_support)
	unit_acted.emit(attacker, target, damage)
	if not target.is_alive:
		unit_died.emit(target)
		if target.side == BattleUnit.Side.PLAYER:
			_end_battle(false)

# ──────────────────── タイムライン ────────────────────

# 前列ユニット + 中列の間接攻撃持ち（同縦マスの前列が空きの場合）
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
	# 同速の味方 vs 敵はランダムに先攻を決定するため乱数値を事前生成
	var rng_map: Dictionary = {}
	for unit: BattleUnit in all:
		rng_map[unit] = randf()
	all.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		# 同側同速: マス番号順（col 0→3）
		if a.side == b.side:
			return a.col < b.col
		# 異側同速: ランダム
		return rng_map[a] < rng_map[b]
	)
	return all

func _front_col_empty(grid: RotationGrid, col: int) -> bool:
	for unit: BattleUnit in grid.get_front_row():
		if unit.col == col:
			return false
	return true

# ──────────────────── 後列回復 ────────────────────

func _apply_back_row_healing(grid: RotationGrid) -> void:
	for unit: BattleUnit in grid.get_row(2):
		if not unit.is_alive:
			continue
		if unit.self_regen > 0:
			var old_hp := unit.hp
			unit.hp = min(unit.hp_max, unit.hp + unit.self_regen)
			if unit.hp > old_hp:
				unit_healed.emit(unit, unit.hp - old_hp)
		if unit.row_regen > 0:
			for other: BattleUnit in grid.get_all_alive():
				if other != unit and other.col == unit.col:
					var old_hp := other.hp
					other.hp = min(other.hp_max, other.hp + unit.row_regen)
					if other.hp > old_hp:
						unit_healed.emit(other, other.hp - old_hp)

func _apply_enemy_healing() -> void:
	for unit: BattleUnit in enemy_grid.get_all_alive():
		if unit.self_regen > 0:
			var old_hp := unit.hp
			unit.hp = min(unit.hp_max, unit.hp + unit.self_regen)
			if unit.hp > old_hp:
				unit_healed.emit(unit, unit.hp - old_hp)

# ──────────────────── ターゲット選択 ────────────────────

func _pick_target(attacker: BattleUnit) -> BattleUnit:
	var opp_grid: RotationGrid = enemy_grid if attacker.side == BattleUnit.Side.PLAYER else player_grid
	# 前列 → 中列 → 後列 の優先順で候補を決定
	var candidates: Array = opp_grid.get_front_row()
	if candidates.is_empty():
		candidates = opp_grid.get_row(1)
	if candidates.is_empty():
		candidates = opp_grid.get_all_alive()
	if candidates.is_empty():
		return null

	# プレイヤーの攻撃は敵が1体なので単純にランダム
	if attacker.side == BattleUnit.Side.PLAYER:
		return candidates[randi() % candidates.size()]

	# 敵の攻撃: 思考タイプに従ってターゲット選択
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

# マス2/3（col 1/2）を高確率で選ぶ重み付きランダム選択
func _weighted_pick(candidates: Array) -> BattleUnit:
	if candidates.size() == 1:
		return candidates[0]
	var pool: Array = []
	for unit: BattleUnit in candidates:
		pool.append(unit)
		if unit.col == 1 or unit.col == 2:
			pool.append(unit)  # 中央マスを2倍の重みに
	return pool[randi() % pool.size()]

func _get_mid_support(grid: RotationGrid, col: int) -> BattleUnit:
	for unit: BattleUnit in grid.get_row(1):
		if unit.col == col and not unit.support_used:
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
