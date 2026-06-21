extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_arrive_flash_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.arrive_flash_color, Color(0.7, 0.85, 1.0),
		"arrive_flash_color のデフォルト値が Color(0.7, 0.85, 1.0) である")
	scene.free()

func test_arrive_flash_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.arrive_flash_duration, 0.4, 0.001,
		"arrive_flash_duration のデフォルト値が 0.4 である")
	scene.free()
