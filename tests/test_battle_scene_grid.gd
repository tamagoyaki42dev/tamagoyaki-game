extends GutTest

# _make_grid_cell / _make_row_label は static func なので BattleScene インスタンス不要
# Marker3D 座標は battle.tscn 定義値（col間隔2m / row間隔2m）に基づく

const _CELL_SIZE  := Vector2(1.85, 1.85)
const _CELL_COLOR := Color(0.35, 0.55, 1.0, 0.12)

# ── 列ラベル ────────────────────────────────────────────────

func test_row_label_front_text() -> void:
	var lbl := BattleScene._make_row_label("前", Vector3.ZERO, 48, 0.015, Color.WHITE)
	assert_eq(lbl.text, "前", "前ラベルのテキスト")
	lbl.free()

func test_row_label_mid_text() -> void:
	var lbl := BattleScene._make_row_label("中", Vector3.ZERO, 48, 0.015, Color.WHITE)
	assert_eq(lbl.text, "中", "中ラベルのテキスト")
	lbl.free()

func test_row_label_back_text() -> void:
	var lbl := BattleScene._make_row_label("後", Vector3.ZERO, 48, 0.015, Color.WHITE)
	assert_eq(lbl.text, "後", "後ラベルのテキスト")
	lbl.free()

func test_row_label_billboard_enabled() -> void:
	var lbl := BattleScene._make_row_label("前", Vector3.ZERO, 48, 0.015, Color.WHITE)
	assert_eq(lbl.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "ビルボード有効")
	lbl.free()

func test_row_label_position() -> void:
	# Slot_r0_c0=(0,0,0) に grid_label_offset=(-1.3,0.8,0) を加えた位置
	var pos := Vector3(-1.3, 0.8, 0.0)
	var lbl := BattleScene._make_row_label("前", pos, 48, 0.015, Color.WHITE)
	assert_almost_eq(lbl.position.x, -1.3, 0.001, "X（左オフセット）")
	assert_almost_eq(lbl.position.y,  0.8, 0.001, "Y（高さ）")
	assert_almost_eq(lbl.position.z,  0.0, 0.001, "Z（前列z=0）")
	lbl.free()

# ── セルタイル ──────────────────────────────────────────────

func test_grid_cell_is_mesh_instance() -> void:
	var tile := BattleScene._make_grid_cell(Vector3.ZERO, _CELL_SIZE, _CELL_COLOR)
	assert_is(tile, MeshInstance3D, "MeshInstance3D 型")
	tile.free()

func test_grid_cell_has_plane_mesh() -> void:
	var tile := BattleScene._make_grid_cell(Vector3.ZERO, _CELL_SIZE, _CELL_COLOR)
	assert_is(tile.mesh, PlaneMesh, "メッシュが PlaneMesh")
	tile.free()

func test_grid_cell_position_row0_col0() -> void:
	# Slot_r0_c0 の global_position = (0,0,0)
	var pos := Vector3(0.0, 0.0, 0.0)
	var tile := BattleScene._make_grid_cell(pos, _CELL_SIZE, _CELL_COLOR)
	assert_almost_eq(tile.position.x, 0.0, 0.001, "X = col0")
	assert_almost_eq(tile.position.z, 0.0, 0.001, "Z = row0")
	tile.free()

func test_grid_cell_position_row1_col2() -> void:
	# Slot_r1_c2 の global_position = (4,0,2)
	var pos := Vector3(4.0, 0.0, 2.0)
	var tile := BattleScene._make_grid_cell(pos, _CELL_SIZE, _CELL_COLOR)
	assert_almost_eq(tile.position.x, 4.0, 0.001, "X = col2（4m）")
	assert_almost_eq(tile.position.z, 2.0, 0.001, "Z = row1（2m）")
	tile.free()

func test_grid_cell_position_row2_col3() -> void:
	# Slot_r2_c3 の global_position = (6,0,4)（グリッド右奥端）
	var pos := Vector3(6.0, 0.0, 4.0)
	var tile := BattleScene._make_grid_cell(pos, _CELL_SIZE, _CELL_COLOR)
	assert_almost_eq(tile.position.x, 6.0, 0.001, "X = col3（6m）")
	assert_almost_eq(tile.position.z, 4.0, 0.001, "Z = row2（4m）")
	tile.free()
