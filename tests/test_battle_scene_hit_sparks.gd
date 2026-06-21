extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_spark_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.spark_color, Color(1.0, 0.65, 0.0),
		"spark_color のデフォルト値が Color(1.0, 0.65, 0.0) である")
	scene.free()

func test_spark_crit_color_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.spark_crit_color, Color(1.0, 1.0, 0.5),
		"spark_crit_color のデフォルト値が Color(1.0, 1.0, 0.5) である")
	scene.free()

func test_spark_scale_min_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.spark_scale_min, 0.5, 0.001,
		"spark_scale_min のデフォルト値が 0.5 である")
	scene.free()

func test_spark_scale_max_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.spark_scale_max, 1.5, 0.001,
		"spark_scale_max のデフォルト値が 1.5 である")
	scene.free()

func test_spark_lifetime_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.spark_lifetime, 0.9, 0.001,
		"spark_lifetime のデフォルト値が 0.9 である")
	scene.free()

func test_spark_amount_default() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.spark_amount, 28,
		"spark_amount のデフォルト値が 28 である")
	scene.free()
