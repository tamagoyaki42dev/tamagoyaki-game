extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_heal_shower_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.heal_shower_color, Color(0.25, 1.0, 0.45, 1.0),
		"heal_shower_color のデフォルト値が緑色である")
	scene.free()

func test_heal_shower_amount_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.heal_shower_amount, 36,
		"heal_shower_amount のデフォルト値が 36 である（視認性強化で24から増量）")
	scene.free()

func test_heal_shower_duration_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.heal_shower_duration, 0.6, 0.001,
		"heal_shower_duration のデフォルト値が 0.6 である")
	scene.free()

func test_heal_shower_particle_lifetime_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.heal_shower_particle_lifetime, 0.5, 0.001,
		"heal_shower_particle_lifetime のデフォルト値が 0.5 である")
	scene.free()

func test_heal_shower_velocity_range_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.heal_shower_velocity_min, 0.8, 0.001,
		"heal_shower_velocity_min のデフォルト値が 0.8 である（視認性強化で0.3から増）")
	assert_almost_eq(scene.heal_shower_velocity_max, 1.8, 0.001,
		"heal_shower_velocity_max のデフォルト値が 1.8 である（視認性強化で0.8から増）")
	scene.free()

func test_heal_shower_gravity_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.heal_shower_gravity, 3.0, 0.001,
		"heal_shower_gravity のデフォルト値が 3.0 である（視認性強化で1.5から増・動きが見えるように）")
	scene.free()

func test_heal_shower_scale_range_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.heal_shower_scale_min, 1.3, 0.001,
		"heal_shower_scale_min のデフォルト値が 1.3 である（視認性強化で0.4から拡大）")
	assert_almost_eq(scene.heal_shower_scale_max, 2.4, 0.001,
		"heal_shower_scale_max のデフォルト値が 2.4 である（視認性強化で0.8から拡大）")
	scene.free()

func test_heal_shower_height_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.heal_shower_height, 2.0, 0.001,
		"heal_shower_height のデフォルト値が 2.0 である（頭上スポーン・視認性強化で1.8から微増）")
	scene.free()

func test_heal_shower_area_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.heal_shower_area, Vector2(0.5, 0.5),
		"heal_shower_area のデフォルト値が Vector2(0.5, 0.5) である（視認性強化で0.35から拡大）")
	scene.free()
