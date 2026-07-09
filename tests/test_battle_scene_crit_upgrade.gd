extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_crit_slowmo_time_scale_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.crit_slowmo_time_scale, 0.3, 0.001,
		"crit_slowmo_time_scale のデフォルト値が 0.3 である")
	scene.free()

func test_crit_slowmo_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.crit_slowmo_duration, 0.18, 0.001,
		"crit_slowmo_duration のデフォルト値が 0.18 である")
	scene.free()

func test_crit_slowmo_time_scale_is_slower_than_normal() -> void:
	var scene := BattleScene.new()
	assert_lt(scene.crit_slowmo_time_scale, 1.0,
		"クリ限定スローは通常速度(1.0)より遅い")
	scene.free()

func test_crit_zoom_amount_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.crit_zoom_amount, 2.0, 0.001,
		"crit_zoom_amount のデフォルト値が 2.0 である")
	scene.free()

func test_crit_zoom_in_time_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.crit_zoom_in_time, 0.06, 0.001,
		"crit_zoom_in_time のデフォルト値が 0.06 である")
	scene.free()

func test_crit_zoom_out_time_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.crit_zoom_out_time, 0.2, 0.001,
		"crit_zoom_out_time のデフォルト値が 0.2 である")
	scene.free()

func test_crit_zoom_amount_shrinks_below_base_ortho_size() -> void:
	var scene := BattleScene.new()
	assert_lt(scene.crit_zoom_amount, scene.camera_ortho_size,
		"ズーム量が基準の画角サイズより小さい（ズーム後も正の画角が残る）")
	scene.free()
