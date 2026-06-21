extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_landing_squash_y_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_squash_y, 0.65, 0.001,
		"landing_squash_y のデフォルト値が 0.65 である")
	scene.free()

func test_landing_squash_xz_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_squash_xz, 1.2, 0.001,
		"landing_squash_xz のデフォルト値が 1.2 である")
	scene.free()

func test_landing_squash_in_time_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_squash_in_time, 0.06, 0.001,
		"landing_squash_in_time のデフォルト値が 0.06 である")
	scene.free()

func test_landing_squash_out_time_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_squash_out_time, 0.18, 0.001,
		"landing_squash_out_time のデフォルト値が 0.18 である")
	scene.free()
