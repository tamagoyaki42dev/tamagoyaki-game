extends SceneTree
const MESH_FBX := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const ANIM := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer/idle01.fbx"
func _initialize() -> void:
	var ch: Node3D = (load(MESH_FBX) as PackedScene).instantiate()
	root.add_child(ch)
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var m: ArrayMesh = mi.mesh as ArrayMesh
	print("=========== LOD ===========")
	print("surface数 = ", m.get_surface_count())
	for s: int in range(m.get_surface_count()):
		print("  surface", s, " 頂点数=", m.surface_get_array_len(s),
			" 面index数=", m.surface_get_array_index_len(s))
	print("mi.lod_bias = ", mi.lod_bias)
	print("mi.custom_aabb = ", mi.custom_aabb)
	print("mesh AABB = ", m.get_aabb().size, "  ノード実効scale = ", ch.scale)

	print("\n=========== メッシュ骨格 vs アニメ骨格 の rest 比較 ===========")
	var sk_mesh: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var src: Node3D = (load(ANIM) as PackedScene).instantiate()
	var sk_anim: Skeleton3D = src.find_child("Skeleton3D", true, false) as Skeleton3D
	print("ボーン数  メッシュ=", sk_mesh.get_bone_count(), "  アニメ=", sk_anim.get_bone_count())
	var name_miss := 0
	var pos_miss := 0
	var rot_miss := 0
	var worst_pos := 0.0
	var worst_rot := 0.0
	var samples: Array[String] = []
	for i: int in range(sk_mesh.get_bone_count()):
		var bn: String = sk_mesh.get_bone_name(i)
		var j: int = sk_anim.find_bone(bn)
		if j == -1:
			name_miss += 1
			continue
		var rm: Transform3D = sk_mesh.get_bone_rest(i)
		var ra: Transform3D = sk_anim.get_bone_rest(j)
		# メッシュ側は0.01スケールが乗っているので位置は100倍して比較する
		var dp: float = (rm.origin * 100.0 - ra.origin).length()
		var dr: float = absf(rm.basis.get_rotation_quaternion().angle_to(ra.basis.get_rotation_quaternion()))
		worst_pos = max(worst_pos, dp)
		worst_rot = max(worst_rot, dr)
		if dp > 0.01:
			pos_miss += 1
		if rad_to_deg(dr) > 1.0:
			rot_miss += 1
			if samples.size() < 5:
				samples.append("%s : 回転差 %.1f度" % [bn, rad_to_deg(dr)])
	print("名前が無いボーン = ", name_miss)
	print("rest位置がズレるボーン = ", pos_miss, "  最大 %.4f" % worst_pos)
	print("rest回転がズレるボーン = ", rot_miss, "  最大 %.2f度" % rad_to_deg(worst_rot))
	for s2: String in samples:
		print("   ", s2)
	print("→ 回転ズレが多いと、合流したアニメが別姿勢を前提にしており全身が破綻する")
	quit()
