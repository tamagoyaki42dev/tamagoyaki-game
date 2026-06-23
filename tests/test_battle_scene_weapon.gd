extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_weapon_scale_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.weapon_scale, 0.3, 0.001,
		"weapon_scale のデフォルト値が 0.3 である")
	scene.free()
