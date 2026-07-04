extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_unit_action_show_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.unit_action_show_duration, 0.9, 0.001,
		"unit_action_show_duration のデフォルト値が 0.9 である")
	scene.free()
