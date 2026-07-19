extends GutTest

# A/B画風プリセット・フェーズ1で新規追加した効果の @export 既定値と公開APIの存在を検証する
# （dev_tooling_design.md「A/B画風プリセット」実装順(a)〜(h)）。
# BattleScene をシーンツリーに追加せず .new() のみ呼び出す（既存 battle_scene テストと同じ流儀）
# → _ready() は実行されないため @export デフォルト値と has_method のみを検証する。
# 見た目（実際にぼける/影が落ちる等）はGUTで守れないため実機目視が別途必要。

func test_shadow_soft_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.shadow_soft_enabled, "shadow_soft_enabled の既定はfalse（現状=影無し）")
	assert_almost_eq(scene.shadow_blur, 1.0, 0.001, "shadow_blur の既定値")
	scene.free()

func test_glow_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.glow_enabled, "glow_enabled の既定はfalse（現状=glow無し）")
	assert_almost_eq(scene.glow_intensity, 0.25, 0.001, "glow_intensity の既定値")
	scene.free()

func test_msaa_default() -> void:
	var scene := BattleScene.new()
	assert_false(scene.msaa_enabled, "msaa_enabled の既定はfalse（回帰なし）")
	scene.free()

func test_tonemap_filmic_default() -> void:
	var scene := BattleScene.new()
	assert_false(scene.tonemap_filmic,
		"tonemap_filmic の既定はfalse＝Reinhardt（2026-07-12踏襲・現状のまま）")
	scene.free()

func test_clay_light_softness_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_light_softness, 0.04, 0.001,
		"clay_light_softness の既定値0.04（旧実装がシェーダー内に直書きしていた値と一致＝回帰なし）")
	scene.free()

func test_clay_outline_softness_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.clay_outline_softness, 0.0, 0.001,
		"clay_outline_softness の既定は0（旧来のハードstep相当＝回帰なし）")
	scene.free()

func test_tilt_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.tilt_enabled, "tilt_enabled の既定はfalse（現状=tilt無し）")
	assert_almost_eq(scene.tilt_center, 0.5, 0.001, "tilt_center の既定値")
	assert_almost_eq(scene.tilt_sharp_band, 0.18, 0.001, "tilt_sharp_band の既定値")
	assert_almost_eq(scene.tilt_blur, 2.5, 0.001, "tilt_blur の既定値")
	scene.free()

func test_contact_shadow_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.contact_shadow_enabled, "contact_shadow_enabled の既定はfalse（現状=接地影無し）")
	assert_almost_eq(scene.contact_shadow_radius, 0.6, 0.001, "contact_shadow_radius の既定値")
	assert_almost_eq(scene.contact_shadow_opacity, 0.4, 0.001, "contact_shadow_opacity の既定値")
	assert_eq(scene.contact_shadow_color, Color(0.0, 0.0, 0.0, 1.0), "contact_shadow_color の既定は黒")
	scene.free()

func test_lut_desaturate_range_allows_negative() -> void:
	var scene := BattleScene.new()
	scene.lut_desaturate = -0.2
	assert_almost_eq(scene.lut_desaturate, -0.2, 0.001,
		"lut_desaturateへ負値を代入できる（Aプリセットの彩度ブースト用）")
	scene.free()

func test_new_setter_api_exists() -> void:
	var scene := BattleScene.new()
	var methods := ["set_shadow_soft_enabled", "set_shadow_blur", "set_glow_enabled", "set_glow_intensity",
		"set_tonemap_filmic", "set_msaa_enabled", "set_tilt_enabled", "set_tilt_sharp_band", "set_tilt_blur",
		"set_clay_outline_softness", "set_clay_hatch_strength", "set_clay_rim_strength",
		"set_clay_light_softness", "set_clay_light_threshold", "set_clay_shadow_tint",
		"set_contact_shadow_enabled", "set_contact_shadow_radius", "set_contact_shadow_opacity",
		"set_contact_shadow_color", "set_lut_desaturate", "apply_style_preset"]
	for m: String in methods:
		assert_true(scene.has_method(m), "stage_composerが呼ぶ公開API %s が存在する" % m)
	scene.free()

# onready ノード（_env_node/_light/_characters/_canvas）が未接続でもクラッシュしないこと
# （ツリー未接続のGUT単体テストからでも安全に呼べる＝実装のnullガード確認）
func test_new_setters_are_safe_when_out_of_tree() -> void:
	var scene := BattleScene.new()
	scene.set_shadow_soft_enabled(true)
	scene.set_shadow_blur(2.0)
	scene.set_glow_enabled(true)
	scene.set_glow_intensity(0.5)
	scene.set_tonemap_filmic(true)
	scene.set_msaa_enabled(true)
	scene.set_tilt_enabled(true)
	scene.set_tilt_sharp_band(0.2)
	scene.set_tilt_blur(3.0)
	scene.set_clay_outline_softness(0.1)
	scene.set_clay_hatch_strength(0.5)
	scene.set_clay_rim_strength(0.5)
	scene.set_clay_light_softness(0.1)
	scene.set_clay_light_threshold(0.5)
	scene.set_clay_shadow_tint(Color.RED)
	scene.set_lut_desaturate(-0.1)
	assert_true(scene.shadow_soft_enabled, "@exportへの書き戻しはツリー未接続でも行われる")
	assert_true(scene.tilt_enabled, "@exportへの書き戻しはツリー未接続でも行われる")
	scene.free()
