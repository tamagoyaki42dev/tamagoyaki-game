extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_weapon_trail_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.weapon_trail_color, Color(1.0, 1.0, 0.9, 1.0),
		"weapon_trail_color のデフォルト値が Color(1.0, 1.0, 0.9, 1.0)（白〜金・全開不透明）である")
	scene.free()

func test_weapon_trail_crit_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.weapon_trail_crit_color, Color(1.0, 0.4, 0.05, 1.0),
		"weapon_trail_crit_color のデフォルト値が Color(1.0, 0.4, 0.05, 1.0)（濃いオレンジ・全開不透明）である")
	scene.free()

func test_weapon_trail_blade_length_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.weapon_trail_blade_length, 1.2, 0.001,
		"weapon_trail_blade_length のデフォルト値が 1.2 である（視認性強化で0.5から拡大）")
	scene.free()

func test_weapon_trail_base_offset_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.weapon_trail_base_offset, 0.7, 0.001,
		"weapon_trail_base_offset のデフォルト値が 0.7 である（実測した刃先(Y≈1.9)に終点が合うよう調整）")
	scene.free()

func test_weapon_trail_fade_time_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.weapon_trail_fade_time, 0.35, 0.001,
		"weapon_trail_fade_time のデフォルト値が 0.35 である（視認性強化で0.15から延長）")
	scene.free()
