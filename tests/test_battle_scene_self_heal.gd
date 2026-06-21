extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_self_heal_show_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.self_heal_show_duration, 1.0, 0.001,
		"self_heal_show_duration のデフォルト値が 1.0 である")
	scene.free()
