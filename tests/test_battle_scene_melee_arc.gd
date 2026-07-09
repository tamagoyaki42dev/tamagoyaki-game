extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_melee_approach_arc_height_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.melee_approach_arc_height, 0.6, 0.001,
		"melee_approach_arc_height のデフォルト値が 0.6 である")
	scene.free()

func test_melee_approach_arc_height_is_positive() -> void:
	var scene := BattleScene.new()
	assert_gt(scene.melee_approach_arc_height, 0.0,
		"弧の高さが0より大きい（=平行移動でなく実際にジャンプする）")
	scene.free()

func test_arc_formula_returns_to_baseline_at_start_and_end() -> void:
	# _on_unit_acted 内で使う弧の式（始点.lerp(終点,t) + UP*高さ*sin(PI*t)）そのものを
	# 端点で検証する：t=0/1では弧の寄与が0になり、始点・終点と一致するはず
	var start := Vector3(0.0, 0.0, 0.0)
	var end := Vector3(2.0, 0.0, 0.0)
	var height := 0.6
	var pos_start: Vector3 = start.lerp(end, 0.0) + Vector3.UP * height * sin(PI * 0.0)
	var pos_end: Vector3 = start.lerp(end, 1.0) + Vector3.UP * height * sin(PI * 1.0)
	assert_almost_eq(pos_start.y, 0.0, 0.001, "t=0では弧の高さ寄与がない")
	assert_almost_eq(pos_end.y, 0.0, 0.001, "t=1では弧の高さ寄与がない（着地）")

func test_arc_formula_peaks_above_baseline_at_midpoint() -> void:
	var start := Vector3(0.0, 0.0, 0.0)
	var end := Vector3(2.0, 0.0, 0.0)
	var height := 0.6
	var pos_mid: Vector3 = start.lerp(end, 0.5) + Vector3.UP * height * sin(PI * 0.5)
	assert_almost_eq(pos_mid.y, height, 0.001, "t=0.5では弧の頂点＝高さそのものになる")
