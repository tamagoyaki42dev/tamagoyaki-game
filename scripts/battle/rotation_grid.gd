class_name RotationGrid

const ROW_COUNT: int = 3      # 前列/中列/後列
const MAX_PER_ROW: int = 4    # 1行あたり最大ユニット数

# grid[row_index] = Array[BattleUnit]
var grid: Array = []

func _init() -> void:
	grid.resize(ROW_COUNT)
	for i in ROW_COUNT:
		grid[i] = []

func add_unit(unit: BattleUnit) -> bool:
	var row = clampi(unit.row, 0, ROW_COUNT - 1)
	if grid[row].size() >= MAX_PER_ROW:
		return false
	unit.row = row
	unit.col = grid[row].size()
	grid[row].append(unit)
	return true

# 前列→後列へ：前 ← 中 ← 後 ← 前（全員が前進する）
func rotate_forward() -> void:
	var temp = grid[0]
	grid[0]  = grid[1]
	grid[1]  = grid[2]
	grid[2]  = temp
	_sync_row_indices()

func _sync_row_indices() -> void:
	for row_idx in ROW_COUNT:
		for col_idx in grid[row_idx].size():
			var unit: BattleUnit = grid[row_idx][col_idx]
			unit.row = row_idx
			unit.col = col_idx

func get_front_row() -> Array:
	return grid[0].filter(func(u: BattleUnit) -> bool: return u.is_alive)

func get_row(row_idx: int) -> Array:
	if row_idx < 0 or row_idx >= ROW_COUNT:
		return []
	return grid[row_idx].filter(func(u: BattleUnit) -> bool: return u.is_alive)

func get_all_alive() -> Array:
	var result: Array = []
	for row in grid:
		for unit in row:
			if (unit as BattleUnit).is_alive:
				result.append(unit)
	return result

func is_wiped() -> bool:
	return get_all_alive().is_empty()
