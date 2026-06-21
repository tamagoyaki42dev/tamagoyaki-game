extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_front_row_flash_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.front_row_flash_color, Color(1.0, 0.85, 0.3),
		"front_row_flash_color のデフォルト値が Color(1.0, 0.85, 0.3) である")
	scene.free()

func test_front_row_flash_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.front_row_flash_duration, 0.45, 0.001,
		"front_row_flash_duration のデフォルト値が 0.45 である")
	scene.free()

func test_front_row_flash_delay_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.front_row_flash_delay, 0.15, 0.001,
		"front_row_flash_delay のデフォルト値が 0.15 である")
	scene.free()
