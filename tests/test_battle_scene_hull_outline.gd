extends GutTest

# 輪郭の完全化＝inverted-hull outline（2026-07-17 着手GO）。
# 既存_POST_CODEのluma差エッジ検出はカバー漏れがある（暗い帽子×暗背景等）ため、
# クレイ材質のnext_passにcull_front/法線膨張の殻を足してジオメトリで完全カバーする。
# next_passの有無そのものがON/OFF＝hull_outline_enabledでnext_passの有無を検証する。
# 見た目（実際にシルエットに線が乗るか・低ポリの継ぎ目割れ）はGUTで守れないため実機目視が別途必要。

func test_hull_outline_defaults() -> void:
	var scene := BattleScene.new()
	assert_false(scene.hull_outline_enabled, "hull_outline_enabled の既定はfalse（回帰なし）")
	assert_almost_eq(scene.hull_outline_width, 0.015, 0.001, "hull_outline_width の既定値（控えめ）")
	assert_eq(scene.hull_outline_color, Color(0.1, 0.06, 0.02, 1.0), "hull_outline_color の既定値")
	scene.free()

func test_hull_outline_setter_api_exists() -> void:
	var scene := BattleScene.new()
	for m: String in ["set_hull_outline_enabled", "set_hull_outline_width", "set_hull_outline_color"]:
		assert_true(scene.has_method(m), "stage_composerが呼ぶ公開API %s が存在する" % m)
	scene.free()

func test_hull_outline_setters_safe_when_out_of_tree() -> void:
	var scene := BattleScene.new()
	scene.set_hull_outline_enabled(true)
	scene.set_hull_outline_width(0.03)
	scene.set_hull_outline_color(Color.RED)
	assert_true(scene.hull_outline_enabled, "@exportへの書き戻しはツリー未接続でも行われる")
	assert_almost_eq(scene.hull_outline_width, 0.03, 0.001)
	assert_eq(scene.hull_outline_color, Color.RED)
	scene.free()

# ── _apply_clay_shader：新規マテリアル生成時にnext_passの有無/paramが乗るか
# （test_battle_scene_paint_texture.gdと同じ流儀＝chは素のNode3Dを手動構築。
# _clay_shaderは_ready()未実行なので手動で用意する）──

func test_apply_clay_shader_no_next_pass_when_disabled() -> void:
	var scene := BattleScene.new()
	scene._clay_shader = Shader.new()
	scene._clay_shader.code = BattleScene._CLAY_CODE
	scene.hull_outline_enabled = false
	var ch := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	ch.add_child(mesh)
	add_child_autofree(ch)

	scene._apply_clay_shader(ch)

	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	assert_not_null(mat, "clayシェーダーマテリアルが生成される")
	assert_null(mat.next_pass, "hull_outline_enabled=falseならnext_passは無い（回帰なし）")
	scene.free()

func test_apply_clay_shader_adds_next_pass_when_enabled() -> void:
	var scene := BattleScene.new()
	scene._clay_shader = Shader.new()
	scene._clay_shader.code = BattleScene._CLAY_CODE
	scene.hull_outline_enabled = true
	scene.hull_outline_width = 0.02
	scene.hull_outline_color = Color(0.5, 0.1, 0.1, 1.0)
	var ch := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	ch.add_child(mesh)
	add_child_autofree(ch)

	scene._apply_clay_shader(ch)

	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	var next_pass := mat.next_pass as ShaderMaterial
	assert_not_null(next_pass, "hull_outline_enabled=trueならnext_passが付く")
	assert_almost_eq(float(next_pass.get_shader_parameter("hull_outline_width")), 0.02, 0.001,
		"hull_outline_widthがnext_passマテリアルへ渡る")
	assert_eq(next_pass.get_shader_parameter("hull_outline_color"), Color(0.5, 0.1, 0.1, 1.0),
		"hull_outline_colorがnext_passマテリアルへ渡る")
	scene.free()

# ── set_hull_outline_*：既存マテリアルへのライブ反映（_characters onreadyを手動で差し替えて
# ツリー未接続でも_for_each_clay_materialの実挙動を検証する。paint_textureテストと同じ流儀）──

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

func test_set_hull_outline_enabled_true_adds_next_pass_to_existing_material() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]
	assert_null(mat.next_pass, "初期状態はnext_pass無し")

	scene.set_hull_outline_enabled(true)

	assert_not_null(mat.next_pass, "ONにすると既存マテリアルにnext_passが付く")
	assert_true(scene.hull_outline_enabled)
	scene.free()

func test_set_hull_outline_enabled_false_removes_next_pass() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]
	scene.set_hull_outline_enabled(true)
	assert_not_null(mat.next_pass)

	scene.set_hull_outline_enabled(false)

	assert_null(mat.next_pass, "OFFにすると既存マテリアルのnext_passが外れる")
	assert_false(scene.hull_outline_enabled)
	scene.free()

func test_set_hull_outline_width_updates_existing_next_pass() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]
	scene.set_hull_outline_enabled(true)

	scene.set_hull_outline_width(0.04)

	var next_pass := mat.next_pass as ShaderMaterial
	assert_almost_eq(float(next_pass.get_shader_parameter("hull_outline_width")), 0.04, 0.001)
	scene.free()

func test_set_hull_outline_color_updates_existing_next_pass() -> void:
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]
	scene.set_hull_outline_enabled(true)

	scene.set_hull_outline_color(Color.BLUE)

	var next_pass := mat.next_pass as ShaderMaterial
	assert_eq(next_pass.get_shader_parameter("hull_outline_color"), Color.BLUE)
	scene.free()

func test_set_hull_outline_width_before_enabling_is_noop_on_material() -> void:
	# 無効時はnext_pass自体が無いので、widthだけ変えてもマテリアルには何も起きない
	# （@exportの書き戻しだけは行われる）
	var d := _build_scene_with_one_clay_material()
	var scene: BattleScene = d["scene"]
	var mat: ShaderMaterial = d["mat"]

	scene.set_hull_outline_width(0.04)

	assert_null(mat.next_pass, "無効時はnext_passが無いまま")
	assert_almost_eq(scene.hull_outline_width, 0.04, 0.001, "@exportへの書き戻しは常に行われる")
	scene.free()
