extends GutTest

# 接地ブロブ影（dev_tooling_design.md「A/B画風プリセット」新規ノード・2026-07-16）。
# _spawn_contact_shadow/set_contact_shadow_* は _unit_nodes 経由でキャラroot直下に
# ContactShadowという名のMeshInstance3Dを足す/消すだけなのでツリー未接続でも検証できる
# （test_battle_scene_head_assembly.gdと同じ流儀：ch は素のNode3Dを手動構築）

func test_spawn_contact_shadow_adds_mesh_instance_child() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child_autofree(ch)

	scene._spawn_contact_shadow(ch)

	var node := ch.find_child("ContactShadow", false, false)
	assert_not_null(node, "ContactShadowという名の子ノードが足される")
	assert_is(node, MeshInstance3D, "MeshInstance3D型")
	scene.free()

func test_spawn_contact_shadow_lies_flat_on_ground() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child_autofree(ch)

	scene._spawn_contact_shadow(ch)

	var node := ch.find_child("ContactShadow", false, false) as Node3D
	assert_almost_eq(node.rotation_degrees.x, -90.0, 0.001, "床に寝かせるX-90°回転")
	assert_almost_eq(node.position.y, 0.01, 0.001, "床すれすれの高さ")
	scene.free()

func test_spawn_contact_shadow_uses_radius_export() -> void:
	var scene := BattleScene.new()
	scene.contact_shadow_radius = 0.9
	var ch := Node3D.new()
	add_child_autofree(ch)

	scene._spawn_contact_shadow(ch)

	var node := ch.find_child("ContactShadow", false, false) as MeshInstance3D
	assert_eq((node.mesh as QuadMesh).size, Vector2.ONE * 1.8, "半径0.9→直径1.8のQuadMesh")
	scene.free()

func test_set_contact_shadow_enabled_true_spawns_for_each_unit() -> void:
	var scene := BattleScene.new()
	var ch1 := Node3D.new()
	var ch2 := Node3D.new()
	add_child_autofree(ch1)
	add_child_autofree(ch2)
	scene._unit_nodes = {"unit1": ch1, "unit2": ch2}

	scene.set_contact_shadow_enabled(true)

	assert_not_null(ch1.find_child("ContactShadow", false, false), "各キャラへブロブ子が付く(1)")
	assert_not_null(ch2.find_child("ContactShadow", false, false), "各キャラへブロブ子が付く(2)")
	assert_true(scene.contact_shadow_enabled)
	scene.free()

func test_set_contact_shadow_enabled_false_removes_existing() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child_autofree(ch)
	scene._unit_nodes = {"unit1": ch}
	scene.set_contact_shadow_enabled(true)
	assert_not_null(ch.find_child("ContactShadow", false, false))

	scene.set_contact_shadow_enabled(false)

	assert_null(ch.find_child("ContactShadow", false, false), "OFFにするとブロブが消える")
	assert_false(scene.contact_shadow_enabled)
	scene.free()

func test_set_contact_shadow_radius_updates_existing_blob() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child_autofree(ch)
	scene._unit_nodes = {"unit1": ch}
	scene.set_contact_shadow_enabled(true)

	scene.set_contact_shadow_radius(1.2)

	var node := ch.find_child("ContactShadow", false, false) as MeshInstance3D
	assert_eq((node.mesh as QuadMesh).size, Vector2.ONE * 2.4, "半径変更が既存ブロブへ反映される")
	scene.free()

func test_set_contact_shadow_opacity_updates_shader_param() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child_autofree(ch)
	scene._unit_nodes = {"unit1": ch}
	scene.set_contact_shadow_enabled(true)

	scene.set_contact_shadow_opacity(0.9)

	var node := ch.find_child("ContactShadow", false, false) as MeshInstance3D
	var mat := node.material_override as ShaderMaterial
	assert_almost_eq(float(mat.get_shader_parameter("shadow_opacity")), 0.9, 0.001)
	scene.free()

func test_set_contact_shadow_color_updates_shader_param() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child_autofree(ch)
	scene._unit_nodes = {"unit1": ch}
	scene.set_contact_shadow_enabled(true)

	scene.set_contact_shadow_color(Color.RED)

	var node := ch.find_child("ContactShadow", false, false) as MeshInstance3D
	var mat := node.material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("shadow_color"), Color.RED)
	scene.free()
