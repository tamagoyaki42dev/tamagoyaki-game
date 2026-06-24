extends GutTest

var _bm: BattleManager

func after_each() -> void:
	if _bm:
		_bm.queue_free()

func _setup_basic() -> void:
	_bm = BattleManager.new()
	add_child(_bm)
	_bm.player_grid = RotationGrid.new()
	_bm.enemy_grid = RotationGrid.new()

func _make_unit(side: BattleUnit.Side, row: int, col: int, hp: int = 100) -> BattleUnit:
	var u := BattleUnit.new()
	u.side = side
	u.row = row
	u.col = col
	u.hp_max = hp
	u.hp = hp
	u.speed = 5
	u.attack = 5
	u.attack_hits = 1
	return u

# _do_single_hit が対象死亡時に false を返す（初撃前死亡）
func test_do_single_hit_returns_false_when_target_dead() -> void:
	_setup_basic()
	var attacker := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var target   := _make_unit(BattleUnit.Side.ENEMY,  0, 0)
	target.hp = 0
	_bm.player_grid.grid[0].append(attacker)
	_bm.enemy_grid.grid[0].append(target)

	var result: bool = await _bm._do_single_hit(attacker, target, 10, true, false, false, false)
	assert_false(result, "対象 hp=0 のとき false を返す")

# _do_single_hit がヒット時に true を返す
func test_do_single_hit_returns_true_when_hits() -> void:
	_setup_basic()
	var attacker := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var target   := _make_unit(BattleUnit.Side.ENEMY,  0, 0)
	_bm.player_grid.grid[0].append(attacker)
	_bm.enemy_grid.grid[0].append(target)

	var result: bool = await _bm._do_single_hit(attacker, target, 5, true, false, false, false)
	assert_true(result, "ヒット時は true を返す")

# ×3攻撃で unit_acted が3回 emit される（対象生存時）
func test_multi_hit_emits_unit_acted_n_times() -> void:
	_setup_basic()
	var attacker := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var target   := _make_unit(BattleUnit.Side.ENEMY,  0, 0, 1000)
	_bm.player_grid.grid[0].append(attacker)
	_bm.enemy_grid.grid[0].append(target)

	# ラムダはプリミティブを値コピーでキャプチャするため、参照型(配列)で数える
	var emit_count: Array[int] = [0]
	_bm.unit_acted.connect(func(_a: BattleUnit, _t: BattleUnit, _d: int, _c: bool) -> void:
		emit_count[0] += 1
		_bm.unit_action_anim_done.emit.call_deferred())

	await _bm._do_hits(attacker, target, 5, 3, false, false)
	assert_eq(emit_count[0], 3, "×3攻撃で unit_acted が3回 emit される")

# 途中で対象が死亡したとき残りヒットは発生しない
func test_multi_hit_stops_when_target_dies() -> void:
	_setup_basic()
	var attacker := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var target   := _make_unit(BattleUnit.Side.ENEMY,  0, 0, 1)  # 1発で死ぬ
	_bm.player_grid.grid[0].append(attacker)
	_bm.enemy_grid.grid[0].append(target)

	# ラムダはプリミティブを値コピーでキャプチャするため、参照型(配列)で数える
	var emit_count: Array[int] = [0]
	_bm.unit_acted.connect(func(_a: BattleUnit, _t: BattleUnit, _d: int, _c: bool) -> void:
		emit_count[0] += 1
		_bm.unit_action_anim_done.emit.call_deferred())

	await _bm._do_hits(attacker, target, 100, 3, false, false)
	assert_eq(emit_count[0], 1, "1撃で対象が死亡したとき残り2撃は発生しない")
