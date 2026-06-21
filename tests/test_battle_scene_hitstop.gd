extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_hitstop_time_scale_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.hitstop_time_scale, 0.05, 0.001,
		"hitstop_time_scale のデフォルト値が 0.05 である")
	scene.free()

func test_hitstop_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.hitstop_duration, 0.08, 0.001,
		"hitstop_duration のデフォルト値が 0.08 である")
	scene.free()

func test_shake_intensity_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shake_intensity, 0.05, 0.001,
		"shake_intensity のデフォルト値が 0.05 である")
	scene.free()

func test_shake_crit_intensity_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shake_crit_intensity, 0.12, 0.001,
		"shake_crit_intensity のデフォルト値が 0.12 である")
	scene.free()

func test_shake_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shake_duration, 0.25, 0.001,
		"shake_duration のデフォルト値が 0.25 である")
	scene.free()

func test_crit_intensity_larger_than_normal() -> void:
	var scene := BattleScene.new()
	assert_gt(scene.shake_crit_intensity, scene.shake_intensity,
		"クリット強度が通常強度より大きい")
	scene.free()
