extends GutTest

# 識別UI Phase 4：3D ホバーで unit_3d_hovered シグナルが発火するかを検証。
#
# BattleScene は _ready で @onready ノードを参照するためツリーに add_child せず new() のみ使用。
# _on_unit_area_entered / _on_unit_area_exited は _unit_rings 等に触れないため new() で検証可能。

func _make_scene() -> BattleScene:
	return BattleScene.new()

func _make_unit() -> BattleUnit:
	var cd := CharacterData.from_job(CharacterJob.Type.WARRIOR)
	cd.char_name = "テスト"
	return BattleUnit.from_character(cd, 0)

func test_area_entered_emits_hovered_true() -> void:
	var scene := _make_scene()
	var unit := _make_unit()
	watch_signals(scene)

	scene._on_unit_area_entered(unit)

	assert_signal_emitted(scene, "unit_3d_hovered", "Area3D 入場で発火")
	var params: Array = get_signal_parameters(scene, "unit_3d_hovered")
	assert_eq(params[0], unit, "第1引数が当該 unit")
	assert_eq(params[1], true, "第2引数が true")
	scene.free()

func test_area_exited_emits_hovered_false() -> void:
	var scene := _make_scene()
	var unit := _make_unit()
	watch_signals(scene)

	scene._on_unit_area_exited(unit)

	assert_signal_emitted(scene, "unit_3d_hovered", "Area3D 退場で発火")
	var params: Array = get_signal_parameters(scene, "unit_3d_hovered")
	assert_eq(params[0], unit, "第1引数が当該 unit")
	assert_eq(params[1], false, "第2引数が false")
	scene.free()

func test_hover_collider_export_defaults_are_set() -> void:
	var scene := _make_scene()
	assert_gt(scene.hover_collider_radius, 0.0, "カプセル半径が正の値")
	assert_gt(scene.hover_collider_height, 0.0, "カプセル高さが正の値")
	assert_gt(scene.hover_collider_y, 0.0, "カプセル中心 y が正の値")
	scene.free()
