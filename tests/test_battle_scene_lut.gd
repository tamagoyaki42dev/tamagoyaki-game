extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_lut_enabled_default() -> void:
	var scene := BattleScene.new()
	assert_true(scene.lut_enabled, "lut_enabled のデフォルトが true である")
	scene.free()

func test_lut_export_defaults() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.lut_desaturate, 0.18, 0.001, "lut_desaturate のデフォルトが 0.18 である")
	assert_eq(scene.lut_warm_mult, Vector3(1.08, 1.03, 0.90), "lut_warm_mult のデフォルト値")
	assert_eq(scene.lut_warm_add, Vector3(0.02, 0.015, 0.0), "lut_warm_add のデフォルト値")
	assert_almost_eq(scene.lut_lift_mult, 0.92, 0.001, "lut_lift_mult のデフォルトが 0.92 である")
	assert_almost_eq(scene.lut_lift_add, 0.06, 0.001, "lut_lift_add のデフォルトが 0.06 である")
	scene.free()

# _lut_grade は静的な純粋関数なのでインスタンス化せずに検証できる

func test_lut_grade_no_op_is_identity() -> void:
	# desaturate=0, warm_mult=1, warm_add=0, lift_mult=1, lift_add=0 なら入力=出力
	var c := BattleScene._lut_grade(0.3, 0.5, 0.8, 0.0, Vector3.ONE, Vector3.ZERO, 1.0, 0.0)
	assert_almost_eq(c.r, 0.3, 0.001, "無変換時はRがそのまま")
	assert_almost_eq(c.g, 0.5, 0.001, "無変換時はGがそのまま")
	assert_almost_eq(c.b, 0.8, 0.001, "無変換時はBがそのまま")

func test_lut_grade_reduces_blue_with_default_warm_mult() -> void:
	# 暖色シフト：デフォルトのwarm_multはBを0.90倍に抑える方向
	var c := BattleScene._lut_grade(0.5, 0.5, 0.5, 0.0,
		Vector3(1.08, 1.03, 0.90), Vector3.ZERO, 1.0, 0.0)
	assert_true(c.b < 0.5, "暖色寄りシフトでB成分が入力より下がる")
	assert_true(c.r > 0.5, "暖色寄りシフトでR成分が入力より上がる")

func test_lut_grade_clamps_to_valid_range() -> void:
	var c := BattleScene._lut_grade(1.0, 1.0, 1.0, 0.18,
		Vector3(1.08, 1.03, 0.90), Vector3(0.02, 0.015, 0.0), 0.92, 0.06)
	assert_true(c.r <= 1.0 and c.r >= 0.0, "R が 0..1 にクランプされている")
	assert_true(c.g <= 1.0 and c.g >= 0.0, "G が 0..1 にクランプされている")
	assert_true(c.b <= 1.0 and c.b >= 0.0, "B が 0..1 にクランプされている")

func test_build_lut_texture_has_expected_size() -> void:
	var scene := BattleScene.new()
	var tex := scene._build_lut_texture()
	assert_eq(tex.get_width(), 16, "LUTテクスチャの幅が16である")
	assert_eq(tex.get_height(), 16, "LUTテクスチャの高さが16である")
	assert_eq(tex.get_depth(), 16, "LUTテクスチャの深さが16である")
	scene.free()
