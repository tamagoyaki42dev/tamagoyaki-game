extends GutTest

# 背景刷新（KayKit DungeonRemastered版・2026-07-13）。既存Kenney版bg_dungeon.gdは無改変のまま、
# battle_scene.gd の @export トグルで切り替える構成なので、トグルのデフォルト値とKayKit版シーンの
# 構造（実測に基づくタイル/壁の並び）を検証する。

func test_dungeon_bg_use_kaykit_defaults_to_false() -> void:
	var scene := BattleScene.new()
	assert_false(scene.dungeon_bg_use_kaykit,
		"dungeon_bg_use_kaykit のデフォルトはfalse（Kenney版）。目視確認が済むまでKayKit版を既定にしない")
	scene.free()

func test_tile_size_matches_measured_floor_footprint() -> void:
	assert_almost_eq(BackgroundDungeonKayKit._TILE_SIZE, 4.0, 0.001,
		"floor_tile_large/floor_tile_large_rocksの実測フットプリント(4.0x4.0)に合わせたグリッド間隔")

func test_floor_deco_scale_compensates_half_size_tile() -> void:
	assert_almost_eq(BackgroundDungeonKayKit._FLOOR_DECO_SCALE, 2.0, 0.001,
		"floor_tile_small_decoratedのみ実測フットプリントが2.0x2.0(他の半分)だったため2倍スケールで補正")

func test_wall_spacing_matches_measured_wall_footprint() -> void:
	assert_almost_eq(BackgroundDungeonKayKit._WALL_SPACING, 4.0, 0.001,
		"wall.gltfの実測フットプリント(X=4.0)に合わせた壁の並び間隔")

func test_bg_dungeon_kaykit_scene_instantiates_with_expected_child_count() -> void:
	var ps: PackedScene = load("res://scenes/bg_dungeon_kaykit.tscn")
	var root: Node3D = ps.instantiate()
	add_child_autofree(root)  # _ready()（_build_ground等）はツリーに入って初めて実行される
	# 地面(1) + 床タイル(6行x10列=60) + 小道具(18) + 壁/コーナー(12) = 91
	assert_eq(root.get_child_count(), 91,
		"地面1+床タイル60+小道具18+壁/コーナー12 = 91ノードが生成される")
