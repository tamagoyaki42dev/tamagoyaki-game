extends GutTest

# 絵具/紙テクスチャ注入（B後者=塗り極め・2026-07-16 ユーザーGO・2-1のみ）。
# _CLAY_CODEのalbedoへ手続きノイズ2系統（fbm＝広い筆致むら／value_noise＝紙の繊維目）を
# 合成する。paint_tex_enabled/strength/scaleがShaderMaterialへ正しく渡ることをここで検証する
# （dev_tooling_design.md「B後者＝塗り極め」節「GUT＝paramがShaderMaterialへ渡る値検証」）。
# 見た目（実際に塗りムラに見えるか）はGUTで守れないため実機目視が別途必要。

func test_paint_tex_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.paint_tex_enabled, "paint_tex_enabled の既定はfalse（回帰なし）")
	assert_almost_eq(scene.paint_tex_strength, 0.35, 0.001, "paint_tex_strength の既定値")
	assert_almost_eq(scene.paint_tex_scale, 6.0, 0.001, "paint_tex_scale の既定値")
	scene.free()

func test_paint_tex_setter_api_exists() -> void:
	var scene := BattleScene.new()
	for m: String in ["set_paint_tex_enabled", "set_paint_tex_strength", "set_paint_tex_scale"]:
		assert_true(scene.has_method(m), "stage_composerが呼ぶ公開API %s が存在する" % m)
	scene.free()

func test_paint_tex_setters_are_safe_when_out_of_tree() -> void:
	var scene := BattleScene.new()
	scene.set_paint_tex_enabled(true)
	scene.set_paint_tex_strength(0.8)
	scene.set_paint_tex_scale(10.0)
	assert_true(scene.paint_tex_enabled, "@exportへの書き戻しはツリー未接続でも行われる")
	assert_almost_eq(scene.paint_tex_strength, 0.8, 0.001)
	assert_almost_eq(scene.paint_tex_scale, 10.0, 0.001)
	scene.free()

# ── _apply_clay_shader：新規マテリアル生成時にparamが乗るか（test_battle_scene_head_assembly.gdと
# 同じ流儀＝chは素のNode3Dを手動構築。_clay_shaderは_ready()未実行なので手動で用意する）──

func test_apply_clay_shader_sets_paint_tex_params_on_new_material() -> void:
	var scene := BattleScene.new()
	scene._clay_shader = Shader.new()
	scene._clay_shader.code = BattleScene._CLAY_CODE
	scene.paint_tex_enabled = true
	scene.paint_tex_strength = 0.6
	scene.paint_tex_scale = 8.0
	var ch := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	ch.add_child(mesh)
	add_child_autofree(ch)

	scene._apply_clay_shader(ch)

	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	assert_not_null(mat, "clayシェーダーマテリアルが生成される")
	assert_true(bool(mat.get_shader_parameter("paint_tex_enabled")), "paint_tex_enabledがマテリアルへ渡る")
	assert_almost_eq(float(mat.get_shader_parameter("paint_tex_strength")), 0.6, 0.001,
		"paint_tex_strengthがマテリアルへ渡る")
	assert_almost_eq(float(mat.get_shader_parameter("paint_tex_scale")), 8.0, 0.001,
		"paint_tex_scaleがマテリアルへ渡る")
	scene.free()

# ── set_paint_tex_*：既存マテリアルへのライブ反映（_characters onreadyを手動で差し替えて
# ツリー未接続でも_for_each_clay_materialの実挙動を検証する）──

func _build_scene_with_one_clay_material() -> Dictionary:
	var scene := BattleScene.new()
	scene._clay_shader = Shader.new()
	scene._clay_shader.code = BattleScene._CLAY_CODE
	var characters := Node3D.new()
	add_child_autofree(characters)
	scene._characters = characters
	var ch := Node3D.new()
	characters.add_child(ch)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = scene._clay_shader
	mesh.set_surface_override_material(0, mat)
	ch.add_child(mesh)
	return {"scene": scene, "mat": mat}

func test_set_paint_tex_enabled_updates_existing_material() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]

	scene.set_paint_tex_enabled(true)

	assert_true(bool(mat.get_shader_parameter("paint_tex_enabled")))
	assert_true(scene.paint_tex_enabled)
	scene.free()

func test_set_paint_tex_strength_updates_existing_material() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]

	scene.set_paint_tex_strength(0.9)

	assert_almost_eq(float(mat.get_shader_parameter("paint_tex_strength")), 0.9, 0.001)
	scene.free()

func test_set_paint_tex_scale_updates_existing_material() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]

	scene.set_paint_tex_scale(15.0)

	assert_almost_eq(float(mat.get_shader_parameter("paint_tex_scale")), 15.0, 0.001)
	scene.free()
