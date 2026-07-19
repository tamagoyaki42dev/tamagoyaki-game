extends GutTest

# Kuwahara筆致フィルタ（B後者=塗り極め 2-2・2026-07-16 ユーザーGO）。
# 全画面Kuwahara矩形→BackBufferCopy→既存_POST_CODE矩形の順で描画されること
# （既存ポストが筆致化"後"の色を読むための中継）をヘッドレスで検証する。
# _canvas は @onready だが _ready() を実行しなければ null のままなので、テストから
# 手動のCanvasLayerを差し込んで _setup_post_effects() の実際の組み立てを直接検証できる
# （test_battle_scene_contact_shadow.gdの_characters差し替えと同じ流儀）。
# 見た目（実際に筆致に見えるか・フレームレート）はGUTで守れないため実機目視が別途必要。

func test_kuwahara_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.kuwahara_enabled, "kuwahara_enabled の既定はfalse（回帰なし）")
	assert_almost_eq(scene.kuwahara_radius, 3.0, 0.001, "kuwahara_radius の既定値（控えめ）")
	scene.free()

func test_kuwahara_setter_api_exists() -> void:
	var scene := BattleScene.new()
	for m: String in ["set_kuwahara_enabled", "set_kuwahara_radius"]:
		assert_true(scene.has_method(m), "stage_composerが呼ぶ公開API %s が存在する" % m)
	scene.free()

func test_kuwahara_setters_safe_when_out_of_tree() -> void:
	var scene := BattleScene.new()
	scene.set_kuwahara_enabled(true)
	scene.set_kuwahara_radius(5.0)
	assert_true(scene.kuwahara_enabled, "@exportへの書き戻しはツリー未接続でも行われる")
	assert_almost_eq(scene.kuwahara_radius, 5.0, 0.001)
	scene.free()

# ── _setup_post_effects()：実際のノード組み立て順を _canvas 手動差し替えで検証 ──

func _build_scene_with_manual_canvas() -> Dictionary:
	var scene := BattleScene.new()
	var canvas := CanvasLayer.new()
	add_child_autofree(canvas)
	scene._canvas = canvas
	return {"scene": scene, "canvas": canvas}

func test_kuwahara_disabled_leaves_only_post_rect_no_regression() -> void:
	var d := _build_scene_with_manual_canvas()
	var scene: BattleScene = d["scene"]
	var canvas: CanvasLayer = d["canvas"]
	scene.kuwahara_enabled = false
	scene.clay_outline_enabled = true

	scene._setup_post_effects()

	assert_eq(canvas.get_child_count(), 1,
		"kuwahara無効時はpost_rectのみ（既存の描画順のまま＝回帰なし）")
	assert_is(canvas.get_child(0), ColorRect)
	scene.free()

func test_kuwahara_enabled_inserts_rect_then_backbuffercopy_then_post_rect() -> void:
	var d := _build_scene_with_manual_canvas()
	var scene: BattleScene = d["scene"]
	var canvas: CanvasLayer = d["canvas"]
	scene.kuwahara_enabled = true
	scene.kuwahara_radius = 4.0
	scene.clay_outline_enabled = true  # post_rectも生成される状態にする

	scene._setup_post_effects()

	assert_eq(canvas.get_child_count(), 3,
		"Kuwahara矩形＋BackBufferCopy＋既存postの3ノードが構築される")
	assert_is(canvas.get_child(0), ColorRect, "先頭＝Kuwaharaの全画面矩形（描画順で最初＝奥）")
	assert_is(canvas.get_child(1), BackBufferCopy,
		"2番目＝BackBufferCopy（筆致化後の色を次のポストへ渡す中継）")
	assert_eq((canvas.get_child(1) as BackBufferCopy).copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT,
		"画面全体をコピーするモード")
	assert_is(canvas.get_child(2), ColorRect, "3番目＝既存の輪郭/紙/tiltポスト矩形")

	var kw_mat := (canvas.get_child(0) as ColorRect).material as ShaderMaterial
	assert_true(bool(kw_mat.get_shader_parameter("kuwahara_enabled")), "paramがマテリアルへ渡る")
	assert_almost_eq(float(kw_mat.get_shader_parameter("kuwahara_radius")), 4.0, 0.001,
		"kuwahara_radiusがマテリアルへ渡る")
	scene.free()

func test_kuwahara_enabled_without_any_post_layer_effect_still_builds_kuwahara_only() -> void:
	# outline/paper/tiltが全部OFFでもkuwaharaは独立して構築される（post_rectだけ作られない）
	var d := _build_scene_with_manual_canvas()
	var scene: BattleScene = d["scene"]
	var canvas: CanvasLayer = d["canvas"]
	scene.kuwahara_enabled = true
	scene.clay_outline_enabled = false
	scene.clay_paper_enabled = false
	scene.tilt_enabled = false

	scene._setup_post_effects()

	assert_eq(canvas.get_child_count(), 2, "Kuwahara矩形＋BackBufferCopyのみ（post_rectは作られない）")
	assert_is(canvas.get_child(0), ColorRect)
	assert_is(canvas.get_child(1), BackBufferCopy)
	scene.free()

func test_set_kuwahara_enabled_toggles_node_presence() -> void:
	var d := _build_scene_with_manual_canvas()
	var scene: BattleScene = d["scene"]
	var canvas: CanvasLayer = d["canvas"]
	scene.clay_outline_enabled = true

	scene.set_kuwahara_enabled(true)
	assert_eq(canvas.get_child_count(), 3)

	scene.set_kuwahara_enabled(false)
	assert_eq(canvas.get_child_count(), 1)
	scene.free()

func test_set_kuwahara_radius_updates_material_param() -> void:
	var d := _build_scene_with_manual_canvas()
	var scene: BattleScene = d["scene"]
	var canvas: CanvasLayer = d["canvas"]
	scene.clay_outline_enabled = true
	scene.set_kuwahara_enabled(true)

	scene.set_kuwahara_radius(6.0)

	var kw_mat := (canvas.get_child(0) as ColorRect).material as ShaderMaterial
	assert_almost_eq(float(kw_mat.get_shader_parameter("kuwahara_radius")), 6.0, 0.001)
	scene.free()
