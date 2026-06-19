extends GutTest

func _make_unit(row: int, col: int, alive: bool = true) -> BattleUnit:
	var u := BattleUnit.new()
	u.row = row
	u.col = col
	u.hp_max = 10
	u.hp = 10 if alive else 0
	return u

# ──── rotate_forward ────

func test_rotate_front_moves_to_back():
	var grid := RotationGrid.new()
	var unit := _make_unit(0, 0)
	grid.grid[0].append(unit)
	grid.rotate_forward()
	assert_true(grid.grid[2].has(unit))

func test_rotate_mid_moves_to_front():
	var grid := RotationGrid.new()
	var unit := _make_unit(1, 0)
	grid.grid[1].append(unit)
	grid.rotate_forward()
	assert_true(grid.grid[0].has(unit))

func test_rotate_back_moves_to_mid():
	var grid := RotationGrid.new()
	var unit := _make_unit(2, 0)
	grid.grid[2].append(unit)
	grid.rotate_forward()
	assert_true(grid.grid[1].has(unit))

func test_rotate_updates_row_index():
	var grid := RotationGrid.new()
	var unit := _make_unit(0, 0)
	grid.grid[0].append(unit)
	grid.rotate_forward()
	assert_eq(unit.row, 2)

# ──── get_front_row ────

func test_get_front_row_excludes_dead():
	var grid := RotationGrid.new()
	var alive := _make_unit(0, 0, true)
	var dead  := _make_unit(0, 1, false)
	grid.grid[0] = [alive, dead]
	var front := grid.get_front_row()
	assert_eq(front.size(), 1)
	assert_true(front.has(alive))

# ──── is_wiped ────

func test_is_wiped_all_dead():
	var grid := RotationGrid.new()
	grid.grid[0] = [_make_unit(0, 0, false)]
	assert_true(grid.is_wiped())

func test_not_wiped_when_alive_exists():
	var grid := RotationGrid.new()
	grid.grid[0] = [_make_unit(0, 0, true)]
	assert_false(grid.is_wiped())

# ──── has_front_unit_at_col ────

func test_has_front_unit_at_col_true():
	var grid := RotationGrid.new()
	grid.grid[0] = [_make_unit(0, 2)]
	assert_true(grid.has_front_unit_at_col(2))

func test_has_front_unit_at_col_false_empty():
	var grid := RotationGrid.new()
	assert_false(grid.has_front_unit_at_col(2))

func test_has_front_unit_at_col_false_dead():
	var grid := RotationGrid.new()
	grid.grid[0] = [_make_unit(0, 2, false)]
	assert_false(grid.has_front_unit_at_col(2))

# ──── get_unused_atk_supporter_at_col ────

func test_atk_supporter_found():
	var grid := RotationGrid.new()
	var supporter := _make_unit(1, 1)
	supporter.atk_bonus = 5
	supporter.atk_support_used = false
	grid.grid[1] = [supporter]
	assert_eq(grid.get_unused_atk_supporter_at_col(1), supporter)

func test_atk_supporter_not_found_wrong_col():
	var grid := RotationGrid.new()
	var supporter := _make_unit(1, 2)
	supporter.atk_bonus = 5
	supporter.atk_support_used = false
	grid.grid[1] = [supporter]
	assert_null(grid.get_unused_atk_supporter_at_col(1))

func test_atk_supporter_not_found_already_used():
	var grid := RotationGrid.new()
	var supporter := _make_unit(1, 1)
	supporter.atk_bonus = 5
	supporter.atk_support_used = true
	grid.grid[1] = [supporter]
	assert_null(grid.get_unused_atk_supporter_at_col(1))

# ──── get_unused_def_supporter_at_col ────

func test_def_supporter_found():
	var grid := RotationGrid.new()
	var supporter := _make_unit(1, 0)
	supporter.def_bonus = 3
	supporter.def_support_used = false
	grid.grid[1] = [supporter]
	assert_eq(grid.get_unused_def_supporter_at_col(0), supporter)

func test_def_supporter_not_found_already_used():
	var grid := RotationGrid.new()
	var supporter := _make_unit(1, 0)
	supporter.def_bonus = 3
	supporter.def_support_used = true
	grid.grid[1] = [supporter]
	assert_null(grid.get_unused_def_supporter_at_col(0))
