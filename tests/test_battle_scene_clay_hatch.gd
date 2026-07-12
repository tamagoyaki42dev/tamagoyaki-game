extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_clay_hatch_spacing_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_hatch_spacing, 5.0, 0.001,
		"clay_hatch_spacing のデフォルト値が 5.0 である（7.0は「変な斜め線」で悪目立ちしたため緩和）")
	scene.free()

func test_clay_hatch_strength_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_hatch_strength, 0.3, 0.001,
		"clay_hatch_strength のデフォルト値が 0.3 である（0.7は強すぎたため控えめに緩和）")
	scene.free()
