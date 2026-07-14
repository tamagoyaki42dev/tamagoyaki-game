extends GutTest
## キャラ・カスタマイザーの組み立てロジック検証（描画なし・ノード構造のみ）

const Customizer := preload("res://scripts/tools/char_customizer.gd")

func test_slot_of_parses_suffix() -> void:
	assert_eq(Customizer._slot_of("Barbarian_Head"), "Head")
	assert_eq(Customizer._slot_of("Knight_HelmetVisor"), "HelmetVisor")
	assert_eq(Customizer._slot_of("RogueHooded_ArmLeft"), "ArmLeft")
	# キャラ名自体に"_"を含む（Skeleton_Warrior等）場合は最後の"_"で分割する
	assert_eq(Customizer._slot_of("Skeleton_Warrior_Head"), "Head")
	assert_eq(Customizer._slot_of("Skeleton_Mage_Skull"), "Skull")

func test_skull_slot_aliases_to_head() -> void:
	assert_eq(Customizer.SLOT_ALIAS.get("Skull", "Skull"), "Head")

func test_assemble_mixes_parts_across_characters() -> void:
	# Barbarianの頭 + Knightの体 を1体のスケルトンに差す
	var part_meshname := {
		"Head": {"Barbarian": "Barbarian_Head"},
		"Body": {"Knight": "Knight_Body"},
	}
	var selection := {"Head": "Barbarian", "Body": "Knight"}
	var root := Customizer.assemble(selection, part_meshname)
	add_child_autofree(root)
	assert_not_null(root, "組み立て結果がnull")

	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel, "HOSTスケルトンが無い")

	var mesh_names: Array = []
	for c in skel.get_children():
		if c is MeshInstance3D:
			mesh_names.append(c.name)
	# HOST標準パーツは剥がされ、差した2枚だけが乗っている
	assert_eq(mesh_names.size(), 2, "差したパーツ数が想定外: %s" % str(mesh_names))
	assert_true(mesh_names.has("Barbarian_Head"), "Barbarianの頭が乗っていない")
	assert_true(mesh_names.has("Knight_Body"), "Knightの体が乗っていない")

func test_detect_uv_color_bands_finds_multiple_regions() -> void:
	# Barbarian_Headは肌・グレー系・黒系の少なくとも3色域を持つ（2026-07-11 実測確認）
	var part_meshname := {"Head": {"Barbarian": "Barbarian_Head"}}
	var root := Customizer.assemble({"Head": "Barbarian"}, part_meshname)
	add_child_autofree(root)
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var head: MeshInstance3D = skel.find_child("Barbarian_Head", false, false) as MeshInstance3D

	var bands := Customizer.detect_uv_color_bands(head)
	assert_true(bands.size() >= 2, "肌と髪など複数の色域が検出されるはず: %d" % bands.size())
	assert_true(bands.size() <= 6, "バンド数が想定より多すぎる: %d" % bands.size())

func test_recolor_part_replaces_near_black_band_not_just_multiplies() -> void:
	# 単純な乗算（元の色×tint）だと黒に近い色は何を掛けても黒のまま変わらない。
	# recolor_partは輝度比を使った置換方式なので、黒系バンド（髪等）も明確に染まるはず。
	var part_meshname := {"Head": {"Barbarian": "Barbarian_Head"}}
	var root := Customizer.assemble({"Head": "Barbarian"}, part_meshname)
	add_child_autofree(root)
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var head: MeshInstance3D = skel.find_child("Barbarian_Head", false, false) as MeshInstance3D

	var bands := Customizer.detect_uv_color_bands(head)
	var dark_idx := 0
	var dark_lum := INF
	for i in bands.size():
		var lum: float = Customizer._luminance((bands[i] as Dictionary)["color"])
		if lum < dark_lum:
			dark_lum = lum
			dark_idx = i
	assert_true(dark_lum < 0.3, "前提崩れ：暗いバンドが見つからない（lum=%.2f）" % dark_lum)

	# 元テクスチャで、暗いバンドに属する頂点UVを1つ特定しておく
	var base_mat := head.mesh.surface_get_material(0) as StandardMaterial3D
	var orig_img := base_mat.albedo_texture.get_image()
	orig_img.decompress()
	var w := orig_img.get_width()
	var h := orig_img.get_height()
	var arrays := (head.mesh as ArrayMesh).surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var target_uv := Vector2(-1, -1)
	var dark_color: Color = (bands[dark_idx] as Dictionary)["color"]
	for uv in uvs:
		var px := clampi(int(uv.x * w), 0, w - 1)
		var py := clampi(int(uv.y * h), 0, h - 1)
		var c := orig_img.get_pixel(px, py)
		if absf(c.r - dark_color.r) + absf(c.g - dark_color.g) + absf(c.b - dark_color.b) < 0.05:
			target_uv = uv
			break
	assert_true(target_uv.x >= 0.0, "暗いバンドに属するUVが見つからない（テストデータ前提の確認）")

	var tint := Color(1.0, 0.1, 0.1)
	Customizer.recolor_part(head, bands, {dark_idx: tint})
	assert_not_null(head.material_override, "recolor後にoverrideが付いていない")

	var new_tex: Texture2D = (head.material_override as StandardMaterial3D).albedo_texture
	var new_img := new_tex.get_image()
	new_img.decompress()
	var px := clampi(int(target_uv.x * w), 0, w - 1)
	var py := clampi(int(target_uv.y * h), 0, h - 1)
	var result := new_img.get_pixel(px, py)
	assert_true(result.r > result.g + 0.2 and result.r > result.b + 0.2,
		"乗算のままなら黒×tint=黒のはず。置換できていれば明確に赤くなる: %s" % result)

func test_recolor_part_empty_band_tint_clears_override() -> void:
	var part_meshname := {"Head": {"Barbarian": "Barbarian_Head"}}
	var root := Customizer.assemble({"Head": "Barbarian"}, part_meshname)
	add_child_autofree(root)
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var head: MeshInstance3D = skel.find_child("Barbarian_Head", false, false) as MeshInstance3D
	var bands := Customizer.detect_uv_color_bands(head)

	Customizer.recolor_part(head, bands, {0: Color.BLUE})
	assert_not_null(head.material_override)
	Customizer.recolor_part(head, bands, {})
	assert_null(head.material_override, "空のband_tintならoverrideが外れるはず")

func test_assembled_part_binds_to_host_skeleton() -> void:
	var part_meshname := {"Head": {"Barbarian": "Barbarian_Head"}}
	var root := Customizer.assemble({"Head": "Barbarian"}, part_meshname)
	add_child_autofree(root)
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var part: MeshInstance3D = skel.find_child("Barbarian_Head", false, false) as MeshInstance3D
	assert_not_null(part, "差した頭が見つからない")
	# skeleton NodePath がHOSTスケルトン（親＝".."）を指している
	assert_eq(part.skeleton, NodePath(".."), "差したパーツのskeleton参照がHOSTを指していない")
