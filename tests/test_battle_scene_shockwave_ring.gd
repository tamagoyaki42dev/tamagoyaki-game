extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_shockwave_ring_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.shockwave_ring_color, Color(1.0, 0.8, 0.2, 1.0),
		"shockwave_ring_color のデフォルト値が Color(1.0, 0.8, 0.2, 1.0)（濃い金）である")
	scene.free()

func test_shockwave_ring_crit_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.shockwave_ring_crit_color, Color(1.0, 0.35, 0.05, 1.0),
		"shockwave_ring_crit_color のデフォルト値が Color(1.0, 0.35, 0.05, 1.0)（濃いオレンジ赤）である")
	scene.free()

func test_shockwave_ring_band_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shockwave_ring_band, 0.35, 0.001,
		"shockwave_ring_band のデフォルト値が 0.35 である")
	scene.free()

func test_shockwave_ring_start_size_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shockwave_ring_start_size, 0.3, 0.001,
		"shockwave_ring_start_size のデフォルト値が 0.3 である")
	scene.free()

func test_shockwave_ring_end_size_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shockwave_ring_end_size, 2.6, 0.001,
		"shockwave_ring_end_size のデフォルト値が 2.6 である")
	scene.free()

func test_shockwave_ring_crit_end_size_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shockwave_ring_crit_end_size, 3.4, 0.001,
		"shockwave_ring_crit_end_size のデフォルト値が 3.4 である（通常より大きく広がる）")
	scene.free()

func test_shockwave_ring_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shockwave_ring_duration, 0.35, 0.001,
		"shockwave_ring_duration のデフォルト値が 0.35 である")
	scene.free()

func test_shockwave_ring_alpha_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shockwave_ring_alpha, 1.0, 0.001,
		"shockwave_ring_alpha のデフォルト値が 1.0 である")
	scene.free()
