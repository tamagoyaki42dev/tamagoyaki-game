class_name BattleManager
extends Node

# --- シグナル（UIはこれだけ見ればいい）---
signal battle_started(player_grid: RotationGrid, enemy_grid: RotationGrid)
signal turn_started(turn_number: int, timeline: Array)     # timeline = 行動順BattleUnit配列
signal unit_acted(attacker: BattleUnit, target: BattleUnit, damage: int)
signal unit_died(unit: BattleUnit)
signal rotated()
signal battle_ended(player_won: bool, loot: Array)

# ---
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
		var row  = i / RotationGrid.MAX_PER_ROW
		var col  = i % RotationGrid.MAX_PER_ROW
		enemy_grid.add_unit(BattleUnit.from_enemy(enemy_data[i], row, col))

	battle_started.emit(player_grid, enemy_grid)

# do_rotate=true でローテーション、false でステイ（仕様: デフォルトはステイ）
func advance_turn(do_rotate: bool = false) -> void:
	if is_over:
		return

	turn_number += 1
	var timeline = build_timeline()
	turn_started.emit(turn_number, timeline)

	for attacker in timeline:
		if not (attacker as BattleUnit).is_alive:
			continue

		var target: BattleUnit = _pick_target(attacker)
		if target == null:
			continue

		var damage = target.take_damage(attacker.attack)
		unit_acted.emit(attacker, target, damage)

		if not target.is_alive:
			unit_died.emit(target)
			# 味方1体でも倒れたら即撤退（battle_spec.md 勝敗条件）
			if target.side == BattleUnit.Side.PLAYER:
				_end_battle(false)
				return

	if enemy_grid.is_wiped():
		_end_battle(true)
		return

	if do_rotate:
		player_grid.rotate_forward()
		enemy_grid.rotate_forward()
		rotated.emit()

# 完全情報開示用：現在グリッドでの行動順を返す（UIが戦闘前に表示できる）
func build_timeline() -> Array:
	var all: Array = player_grid.get_all_alive() + enemy_grid.get_all_alive()
	all.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.speed > b.speed)
	return all

func _pick_target(attacker: BattleUnit) -> BattleUnit:
	var enemy_side: RotationGrid = enemy_grid if attacker.side == BattleUnit.Side.PLAYER else player_grid
	var front = enemy_side.get_front_row()
	if not front.is_empty():
		return front[randi() % front.size()]
	var alive = enemy_side.get_all_alive()
	if alive.is_empty():
		return null
	return alive[randi() % alive.size()]

func _end_battle(player_won: bool) -> void:
	is_over = true
	battle_ended.emit(player_won, [])  # lootは後で実装
