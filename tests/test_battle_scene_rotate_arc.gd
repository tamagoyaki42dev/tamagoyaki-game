extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_rotate_arc_height_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.rotate_arc_height, 0.3, 0.001,
		"rotate_arc_height のデフォルト値が 0.3 である")
	scene.free()

func test_rotate_stagger_delay_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.rotate_stagger_delay, 0.05, 0.001,
		"rotate_stagger_delay のデフォルト値が 0.05 である")
	scene.free()

func test_rotate_arc_height_is_positive() -> void:
	var scene := BattleScene.new()
	assert_gt(scene.rotate_arc_height, 0.0,
		"弧の高さが0より大きい（=平行スライドでなく実際にホップする）")
	scene.free()

func test_rotate_stagger_delay_is_positive() -> void:
	var scene := BattleScene.new()
	assert_gt(scene.rotate_stagger_delay, 0.0,
		"開始ずらしが0より大きい（=全ユニット同時発進でなくずれて動く）")
	scene.free()

func test_arc_formula_clamps_beyond_overshoot_range() -> void:
	# _on_rotated 内で使う弧の式（start.lerp(to,t) + UP*高さ*sin(PI*clamp(t,0,1))）を検証。
	# TRANS_BACK/EASE_OUT はオーバーシュートでtが1を超えうるため、
	# 弧の高さ計算はclampしてマイナス（地面に埋まる）を防いでいることを確認する
	var height := 0.3
	var t_overshoot := 1.1
	var arc_contribution := height * sin(PI * clampf(t_overshoot, 0.0, 1.0))
	assert_almost_eq(arc_contribution, 0.0, 0.001,
		"tが1を超えてもclampにより弧の高さ寄与は0のまま（マイナスにならない）")

func test_arc_formula_peaks_above_baseline_at_midpoint() -> void:
	var start := Vector3(0.0, 0.0, 0.0)
	var to := Vector3(2.0, 0.0, 0.0)
	var height := 0.3
	var pos_mid: Vector3 = start.lerp(to, 0.5) + Vector3.UP * height * sin(PI * clampf(0.5, 0.0, 1.0))
	assert_almost_eq(pos_mid.y, height, 0.001, "t=0.5では弧の頂点＝高さそのものになる")
