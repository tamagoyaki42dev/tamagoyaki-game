extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_rotate_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.rotate_duration, 0.55, 0.001,
		"rotate_duration のデフォルト値が 0.55 である")
	scene.free()

func test_rotate_show_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.rotate_show_duration, 0.6, 0.001,
		"rotate_show_duration のデフォルト値が 0.6 である")
	scene.free()

func test_total_rotate_wait_matches_old_delay() -> void:
	var scene := BattleScene.new()
	var total := scene.rotate_duration + scene.rotate_show_duration
	assert_almost_eq(total, 1.15, 0.001,
		"rotate_duration + rotate_show_duration = 1.15s（2026-07-04 テンポ調整後）")
	scene.free()
