extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_clay_boil_enabled_default() -> void:
	var scene := BattleScene.new()
	assert_true(scene.clay_boil_enabled,
		"clay_boil_enabled のデフォルトが true である（⑤頂点ボイル・proto2_design.md本命施策）")
	scene.free()

func test_clay_boil_amplitude_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_boil_amplitude, 0.012, 0.0001,
		"clay_boil_amplitude のデフォルト値が 0.012 である（メッシュ崩壊を避ける保守的な初期値）")
	scene.free()

func test_clay_boil_rate_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_boil_rate, 8.0, 0.001,
		"clay_boil_rate のデフォルト値が 8.0 である（ストップモーション風のコマ送り段階数/秒）")
	scene.free()

func test_clay_boil_grid_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_boil_grid, 0.12, 0.001,
		"clay_boil_grid のデフォルト値が 0.12 である（頭部/髪/武器など別メッシュの継ぎ目裂けを防ぐワールド座標の量子化セル幅）")
	scene.free()
