extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_attack_impact_delay_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.attack_impact_delay, 0.2, 0.001,
		"attack_impact_delay のデフォルト値が 0.2 である")
	scene.free()
