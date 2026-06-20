extends GutTest

var _ui: BattleUI
var _manager: BattleManager

func after_each() -> void:
	if _ui: _ui.queue_free()
	if _manager: _manager.queue_free()

func _make_unit(side: BattleUnit.Side, row: int, col: int) -> BattleUnit:
	var u := BattleUnit.new()
	u.side = side
	u.row = row
	u.col = col
	u.hp_max = 100
	u.hp = 100
	u.speed = 5
	u.attack = 10
	u.attack_hits = 1
	return u

func test_dead_unit_bar_fill_turns_gray() -> void:
	_manager = BattleManager.new()
	add_child(_manager)
	_ui = BattleUI.new()
	add_child(_ui)
	_ui.setup(_manager)

	var player_unit := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var pg := RotationGrid.new()
	pg.grid[0].append(player_unit)
	var eg := RotationGrid.new()
	eg.grid[0].append(_make_unit(BattleUnit.Side.ENEMY, 0, 0))

	_manager.battle_started.emit(pg, eg)
	_manager.unit_died.emit(player_unit)

	var fill := _ui._bar_fills[player_unit] as StyleBoxFlat
	assert_eq(fill.bg_color, Color(0.30, 0.30, 0.30),
		"死亡後 HPバーがグレーになる")

func test_dead_unit_entry_panel_turns_dark() -> void:
	_manager = BattleManager.new()
	add_child(_manager)
	_ui = BattleUI.new()
	add_child(_ui)
	_ui.setup(_manager)

	var player_unit := _make_unit(BattleUnit.Side.PLAYER, 0, 0)
	var pg := RotationGrid.new()
	pg.grid[0].append(player_unit)
	var eg := RotationGrid.new()
	eg.grid[0].append(_make_unit(BattleUnit.Side.ENEMY, 0, 0))

	_manager.battle_started.emit(pg, eg)
	_manager.unit_died.emit(player_unit)

	assert_true(_ui._party_entries.has(player_unit),
		"死亡後も _party_entries にユニットが存在する")
