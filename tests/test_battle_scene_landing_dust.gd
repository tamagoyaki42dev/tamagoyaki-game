extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_landing_dust_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.landing_dust_color, Color(0.72, 0.58, 0.38, 1.0),
		"landing_dust_color のデフォルト値が Color(0.72, 0.58, 0.38, 1.0)（土色・視認性強化で全開不透明）である")
	scene.free()

func test_landing_dust_scale_range_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_dust_scale_min, 1.3, 0.001,
		"landing_dust_scale_min のデフォルト値が 1.3 である（視認性強化で0.6から拡大）")
	assert_almost_eq(scene.landing_dust_scale_max, 2.6, 0.001,
		"landing_dust_scale_max のデフォルト値が 2.6 である（視認性強化で1.4から拡大）")
	scene.free()

func test_landing_dust_velocity_range_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_dust_velocity_min, 3.0, 0.001,
		"landing_dust_velocity_min のデフォルト値が 3.0 である（体感速度アップの指示で2.0から増）")
	assert_almost_eq(scene.landing_dust_velocity_max, 6.0, 0.001,
		"landing_dust_velocity_max のデフォルト値が 6.0 である（体感速度アップの指示で4.5から増）")
	scene.free()

func test_landing_dust_lifetime_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_dust_lifetime, 0.6, 0.001,
		"landing_dust_lifetime のデフォルト値が 0.6 である（表示時間短縮の指示で0.8から短縮）")
	scene.free()

func test_landing_dust_amount_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.landing_dust_amount, 26,
		"landing_dust_amount のデフォルト値が 26 である（視認性強化で14から増量）")
	scene.free()

func test_landing_dust_y_offset_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_dust_y_offset, 0.05, 0.001,
		"landing_dust_y_offset のデフォルト値が 0.05 である")
	scene.free()

func test_landing_dust_rotate_scale_mult_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.landing_dust_rotate_scale_mult, 0.5, 0.001,
		"landing_dust_rotate_scale_mult のデフォルト値が 0.5 である（一斉着地のため近接接近版より小さめ）")
	scene.free()
