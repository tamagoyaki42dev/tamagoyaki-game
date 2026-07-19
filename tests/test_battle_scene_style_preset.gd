extends GutTest

# 画風プリセット（dev_tooling_design.md「A/B画風プリセット」2026-07-16・フェーズ1）。
# apply_style_preset は3層すべての@exportへ値を書き戻す（ライブノード反映はツリー未接続では
# 安全にスキップされる＝各setterのnullガード）。ここでは@export値のみを検証する
# （画面効果の見た目はGUTで守れないため実機目視が別途必要・dev_tooling_design.md参照）。
# BattleScene をシーンツリーに追加せず .new() のみ呼び出す（既存 battle_scene テストと同じ流儀）

func test_style_preset_a_smooths_and_lightens() -> void:
	var scene := BattleScene.new()
	scene.apply_style_preset(BattleScene.StylePreset.A)

	assert_almost_eq(scene.clay_hatch_strength, 0.0, 0.001, "Aはハッチ無し")
	assert_false(scene.clay_boil_enabled, "Aはボイル無し")
	assert_almost_eq(scene.clay_light_softness, 0.2, 0.001, "Aは境界柔らか")
	assert_almost_eq(scene.clay_rim_strength, 0.15, 0.001, "Aのリム強さ")
	assert_false(scene.clay_outline_enabled, "Aは輪郭線OFF")
	assert_false(scene.clay_paper_enabled, "Aは紙グレインOFF")
	assert_true(scene.tilt_enabled, "Aはtilt-shift ON")
	assert_almost_eq(scene.tilt_sharp_band, 0.18, 0.001)
	assert_almost_eq(scene.tilt_blur, 2.5, 0.001)
	assert_true(scene.tonemap_filmic, "AはFilmic")
	assert_true(scene.glow_enabled, "Aはglow ON")
	assert_almost_eq(scene.fog_density, 0.015, 0.001, "Aは薄めの霧")
	assert_true(scene.lut_enabled, "AはLUT ON")
	assert_almost_eq(scene.lut_desaturate, -0.18, 0.001,
		"Aは彩度up（参照docs/imageのmarioRPGは高彩度・2026-07-16改訂で当初の-0.08からさらに彩度側へ）")
	assert_true(scene.shadow_soft_enabled, "Aはソフトシャドウ ON")
	assert_almost_eq(scene.shadow_blur, 2.0, 0.001)
	assert_almost_eq(scene.shadow_distance, 20.0, 0.001, "影のジャギー対策の距離は全プリセット共通")
	assert_true(scene.msaa_enabled, "AはMSAA ON")
	assert_true(scene.contact_shadow_enabled, "Aは接地影 ON")
	assert_almost_eq(scene.contact_shadow_radius, 0.6, 0.001)
	assert_almost_eq(scene.contact_shadow_opacity, 0.4, 0.001)
	assert_false(scene.paint_tex_enabled, "Aはクリーン開始のまま（塗り極めはB専用）")
	assert_false(scene.kuwahara_enabled, "AはKuwahara無し")
	assert_false(scene.hull_outline_enabled, "Aはinverted-hull無し（クリーン開始のまま）")
	scene.free()

func test_style_preset_b_picture_book() -> void:
	var scene := BattleScene.new()
	scene.apply_style_preset(BattleScene.StylePreset.B)

	assert_almost_eq(scene.clay_light_threshold, 0.45, 0.001)
	assert_almost_eq(scene.clay_light_softness, 0.06, 0.001, "Bは境界くっきり")
	assert_almost_eq(scene.clay_hatch_strength, 0.3, 0.001)
	assert_false(scene.clay_boil_enabled, "Bはボイル無し")
	assert_true(scene.clay_outline_enabled, "Bは輪郭線ON")
	assert_true(scene.clay_outline_thickness >= 2.0, "Bは太い輪郭線")
	assert_true(scene.clay_paper_enabled, "Bは紙グレインON")
	assert_almost_eq(scene.clay_posterize_levels, 7.0, 0.001)
	assert_false(scene.tilt_enabled, "Bはtilt-shift無し")
	assert_false(scene.tonemap_filmic, "BはReinhardt")
	assert_false(scene.glow_enabled, "Bはglow無し")
	assert_true(scene.lut_enabled, "BはLUT ON")
	assert_true(scene.lut_desaturate <= 0.0,
		"Bは鮮やか維持（参照docs/imageのYoshiは高彩度・当初の「くすませ」正値指示は2026-07-16改訂で不採用）")
	assert_true(scene.shadow_soft_enabled, "Bもソフトシャドウ ON（通常寄り）")
	assert_almost_eq(scene.shadow_distance, 20.0, 0.001, "影のジャギー対策の距離は全プリセット共通")
	assert_true(scene.msaa_enabled, "BもMSAA ON")
	assert_false(scene.contact_shadow_enabled, "Bは接地影OFF")
	assert_true(scene.paint_tex_enabled,
		"Bは塗り極めON（フェーズ2-1・2026-07-16GO：フラット塗りがA/Bの差を弱めていたため）")
	assert_true(scene.paint_tex_strength > 0.0, "Bの塗りテクスチャ強さは正値")
	assert_true(scene.kuwahara_enabled,
		"BはKuwahara筆致ON（フェーズ2-2・2026-07-16GO：2-1の塗りムラ視認OK後に着手）")
	assert_almost_eq(scene.kuwahara_radius, 3.0, 0.001, "Kuwahara半径は控えめ既定（重いシェーダのため）")
	assert_true(scene.hull_outline_enabled,
		"Bはinverted-hull ON（2026-07-17GO：luma差エッジ検出のカバー漏れをジオメトリで完全カバー）")
	assert_true(scene.hull_outline_width > 0.0, "hull_outline_widthは正値")
	scene.free()

func test_style_preset_current_matches_original_defaults() -> void:
	var scene := BattleScene.new()
	# 先にA/Bへ切り替えてから戻すことで「リセットになっている」ことを確認する
	scene.apply_style_preset(BattleScene.StylePreset.A)
	scene.apply_style_preset(BattleScene.StylePreset.CURRENT)

	assert_almost_eq(scene.clay_hatch_strength, 0.3, 0.001, "現状のハッチ強度")
	assert_true(scene.clay_boil_enabled, "現状はボイルON")
	assert_almost_eq(scene.clay_light_softness, 0.04, 0.001, "現状の境界柔らかさ")
	assert_almost_eq(scene.clay_rim_strength, 0.25, 0.001)
	assert_true(scene.clay_outline_enabled, "現状は輪郭線ON")
	assert_almost_eq(scene.clay_outline_thickness, 1.0, 0.001)
	assert_almost_eq(scene.clay_outline_softness, 0.0, 0.001)
	assert_true(scene.clay_paper_enabled, "現状は紙グレインON")
	assert_false(scene.tilt_enabled, "現状はtilt無し")
	assert_false(scene.tonemap_filmic, "現状はReinhardt")
	assert_false(scene.glow_enabled, "現状はglow無し")
	assert_false(scene.lut_enabled, "現状はLUT OFF")
	assert_false(scene.shadow_soft_enabled, "現状はソフトシャドウ無し")
	assert_almost_eq(scene.shadow_distance, 20.0, 0.001, "影のジャギー対策の距離は全プリセット共通")
	assert_false(scene.msaa_enabled, "現状はMSAA無し")
	assert_false(scene.contact_shadow_enabled, "現状は接地影無し")
	assert_false(scene.paint_tex_enabled, "現状は塗りテクスチャ無し")
	assert_false(scene.kuwahara_enabled, "現状はKuwahara無し")
	assert_false(scene.hull_outline_enabled, "現状はinverted-hull無し")
	scene.free()

func test_style_preset_a_then_b_are_mutually_exclusive_on_outline_and_tilt() -> void:
	var scene := BattleScene.new()
	scene.apply_style_preset(BattleScene.StylePreset.B)
	assert_true(scene.clay_outline_enabled)
	assert_false(scene.tilt_enabled)
	assert_true(scene.paint_tex_enabled)
	assert_true(scene.kuwahara_enabled)
	assert_true(scene.hull_outline_enabled)

	scene.apply_style_preset(BattleScene.StylePreset.A)
	assert_false(scene.clay_outline_enabled, "Aへ切り替えるとBで立てた輪郭線がOFFに戻る")
	assert_true(scene.tilt_enabled, "Aへ切り替えるとtiltがONになる")
	assert_false(scene.paint_tex_enabled, "Aへ切り替えるとBで立てた塗りテクスチャがOFFに戻る")
	assert_false(scene.kuwahara_enabled, "Aへ切り替えるとBで立てたKuwaharaがOFFに戻る")
	assert_false(scene.hull_outline_enabled, "Aへ切り替えるとBで立てたinverted-hullがOFFに戻る")
	scene.free()

# 「初期値に戻す」（2026-07-16 doc改訂・実装順2）：プリセット定義は1箇所のテーブルが真実の源で、
# 適用も reset も同じ経路（apply_style_presetの再呼び出し＝そのプリセットの定義値へ戻る）
func test_style_preset_reapply_resets_after_manual_tweaks() -> void:
	var scene := BattleScene.new()
	scene.apply_style_preset(BattleScene.StylePreset.B)
	var expected_hatch := scene.clay_hatch_strength
	var expected_thickness := scene.clay_outline_thickness
	var expected_tilt_blur := scene.tilt_blur
	var expected_desaturate := scene.lut_desaturate

	# スライダーをいじって定義値から外れさせる
	scene.clay_hatch_strength = 0.99
	scene.clay_outline_thickness = 4.0
	scene.tilt_blur = 6.0
	scene.lut_desaturate = 0.9

	# 「初期値に戻す」＝同じプリセットを再適用するだけ
	scene.apply_style_preset(BattleScene.StylePreset.B)

	assert_almost_eq(scene.clay_hatch_strength, expected_hatch, 0.001, "reset後はB定義値に一致")
	assert_almost_eq(scene.clay_outline_thickness, expected_thickness, 0.001, "reset後はB定義値に一致")
	assert_almost_eq(scene.tilt_blur, expected_tilt_blur, 0.001, "reset後はB定義値に一致")
	assert_almost_eq(scene.lut_desaturate, expected_desaturate, 0.001, "reset後はB定義値に一致")
	scene.free()

func test_style_preset_table_is_single_source_for_all_three_presets() -> void:
	# プリセット定義は1箇所（Dictionary）を真実の源にする（dev_tooling_design.md実装順2）
	for preset: int in [BattleScene.StylePreset.A, BattleScene.StylePreset.B, BattleScene.StylePreset.CURRENT]:
		assert_true(BattleScene._STYLE_PRESET_TABLE.has(preset),
			"プリセット%dの定義が_STYLE_PRESET_TABLEに存在する" % preset)
