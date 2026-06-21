extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_spark_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.spark_color, Color(1.0, 0.7, 0.1),
		"spark_color のデフォルト値が Color(1.0, 0.7, 0.1) である")
	scene.free()

func test_spark_crit_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.spark_crit_color, Color(1.0, 0.95, 0.3),
		"spark_crit_color のデフォルト値が Color(1.0, 0.95, 0.3) である")
	scene.free()

func test_spark_scale_min_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.spark_scale_min, 0.04, 0.001,
		"spark_scale_min のデフォルト値が 0.04 である")
	scene.free()

func test_spark_scale_max_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.spark_scale_max, 0.08, 0.001,
		"spark_scale_max のデフォルト値が 0.08 である")
	scene.free()

func test_spark_lifetime_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.spark_lifetime, 0.5, 0.001,
		"spark_lifetime のデフォルト値が 0.5 である")
	scene.free()

func test_spark_amount_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.spark_amount, 16,
		"spark_amount のデフォルト値が 16 である")
	scene.free()
