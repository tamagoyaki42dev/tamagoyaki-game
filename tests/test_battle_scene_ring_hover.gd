extends GutTest

# 識別UI Phase 3：パネル行ホバー通知でアクセントリングを強調／復帰する _on_row_hovered の検証。
#
# BattleScene は _ready で $World/Camera3D などの @onready ノードを参照するため、
# シーンツリーに add_child せずに new() だけして検証する（_on_row_hovered は
# @onready ノードに触れず _unit_rings / _ring_base_colors のみ参照する）。

func _make_scene_with_ring(unit: BattleUnit, base: Color) -> BattleScene:
	var scene := BattleScene.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scene._unit_rings[unit] = mat
	scene._ring_base_colors[unit] = base
	return scene

func test_hover_brightens_ring_and_enables_emission() -> void:
	var unit := BattleUnit.new()
	var base := Color(0.2, 0.6, 1.0)
	var scene := _make_scene_with_ring(unit, base)

	scene._on_row_hovered(unit, true)

	var mat := scene._unit_rings[unit] as StandardMaterial3D
	assert_eq(mat.albedo_color, base.lerp(Color.WHITE, scene.ring_hover_brighten),
		"ホバーで albedo が白側へ明るくなる")
	assert_ne(mat.albedo_color, base, "基準色から変化している")
	assert_true(mat.emission_enabled, "emission が有効になる")
	assert_eq(mat.emission, base, "emission 色は基準色")
	scene.free()

func test_unhover_restores_base_and_disables_emission() -> void:
	var unit := BattleUnit.new()
	var base := Color(0.9, 0.3, 0.3)
	var scene := _make_scene_with_ring(unit, base)

	scene._on_row_hovered(unit, true)
	scene._on_row_hovered(unit, false)

	var mat := scene._unit_rings[unit] as StandardMaterial3D
	assert_eq(mat.albedo_color, base, "退出で基準色へ復帰")
	assert_false(mat.emission_enabled, "emission が無効に戻る")
	scene.free()

func test_unknown_unit_is_noop() -> void:
	var scene := BattleScene.new()
	# 登録のないユニットでもクラッシュしないこと
	scene._on_row_hovered(BattleUnit.new(), true)
	pass_test("未登録ユニットでも例外なく処理される")
	scene.free()
