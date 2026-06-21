extends GutTest

var _bm: BattleManager

func after_each() -> void:
	if _bm:
		_bm.queue_free()

func _make_unit(side: BattleUnit.Side, row: int, col: int) -> BattleUnit:
	var u := BattleUnit.new()
	u.side = side
	u.row = row
	u.col = col
	u.hp_max = 100
	u.hp = 100
	u.speed = 5
	u.attack = 1
	u.attack_hits = 1
	return u

# ローテーション→回復→行動の順でフェーズが流れることを検証
# turn_number=1 の状態で advance_turn(true) を呼ぶと turn_number=2 になり回復フェーズが走る
func test_turn_phase_order_is_rotation_recovery_action() -> void:
	_bm = BattleManager.new()
	add_child(_bm)

	_bm.player_grid = RotationGrid.new()
	_bm.enemy_grid = RotationGrid.new()

	var player_unit := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var enemy_unit := _make_unit(BattleUnit.Side.ENEMY, 0, 0)
	_bm.player_grid.grid[0].append(player_unit)
	_bm.enemy_grid.grid[0].append(enemy_unit)

	_bm.turn_number = 1

	var log: Array[StringName] = []
	_bm.rotated.connect(func() -> void:
		log.append(&"rotated")
		_bm.rotate_anim_done.emit.call_deferred())
	_bm.phase_started.connect(func(p: StringName) -> void:
		log.append(p)
		if p == &"recovery":
			_bm.self_heal_anim_done.emit.call_deferred())

	_bm.advance_turn(true)
	# action_announced はターン末尾に発火 → これを待てば両 phase_started は確実に記録済み
	await wait_for_signal(_bm.action_announced, 5.0)

	assert_eq(log[0], &"rotated",   "1番目: ローテーション")
	assert_eq(log[1], &"recovery",  "2番目: 回復フェーズ")
	assert_eq(log[2], &"action",    "3番目: 行動フェーズ")

# 1ターン目（turn_number=0 → 1）は回復フェーズをスキップすることを検証
func test_first_turn_skips_recovery_phase() -> void:
	_bm = BattleManager.new()
	add_child(_bm)

	_bm.player_grid = RotationGrid.new()
	_bm.enemy_grid = RotationGrid.new()

	var player_unit := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var enemy_unit := _make_unit(BattleUnit.Side.ENEMY, 0, 0)
	_bm.player_grid.grid[0].append(player_unit)
	_bm.enemy_grid.grid[0].append(enemy_unit)

	var log: Array[StringName] = []
	_bm.phase_started.connect(func(p: StringName) -> void: log.append(p))

	_bm.advance_turn(false)
	await wait_for_signal(_bm.action_announced, 5.0)

	assert_eq(log.size(), 1,          "1ターン目は phase_started が1回だけ")
	assert_eq(log[0], &"action",      "1ターン目は行動フェーズのみ")
