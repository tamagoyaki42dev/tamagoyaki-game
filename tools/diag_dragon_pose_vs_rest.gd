extends SceneTree
# 診断その4：_fix_dragon_skin が使っている get_bone_global_pose と、
# 正しい基準である get_bone_global_rest が、スポーン直後にどれだけ食い違うかを測る。
#   実行: godot --headless --path . -s tools/diag_dragon_pose_vs_rest.gd

const MESH_FBX := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"

func _initialize() -> void:
	var ch: Node3D = (load(MESH_FBX) as PackedScene).instantiate()
	root.add_child(ch)  # battle_scene と同じく「ツリーに入れた直後」に測る
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D

	var diff := 0
	var worst_pos := 0.0
	var worst_scale := 0.0
	var samples: Array[String] = []
	for i: int in range(sk.get_bone_count()):
		var p: Transform3D = sk.get_bone_global_pose(i)
		var r: Transform3D = sk.get_bone_global_rest(i)
		var dp: float = (p.origin - r.origin).length()
		var ds: float = (p.basis.get_scale() - r.basis.get_scale()).length()
		worst_pos = max(worst_pos, dp)
		worst_scale = max(worst_scale, ds)
		if dp > 0.0001 or ds > 0.0001:
			diff += 1
			if samples.size() < 5:
				samples.append("%s: pose.origin=%s rest.origin=%s / pose.scale=%s rest.scale=%s"
					% [sk.get_bone_name(i), p.origin, r.origin, p.basis.get_scale(), r.basis.get_scale()])

	print("=========== global_pose vs global_rest（スポーン直後） ===========")
	print("食い違うボーン = ", diff, " / ", sk.get_bone_count())
	print("最大の位置差 = %.5f  /  最大のスケール差 = %.5f" % [worst_pos, worst_scale])
	for s: String in samples:
		print("   ", s)
	print("")
	print("→ 0本なら現行コードでも結果は同じ（別に原因がある）")
	print("→ 食い違うなら _fix_dragon_skin が誤った基準でバインド姿勢を作っている＝これが原因")

	print("\n=========== 現行コードと修正版を並べて検算 ===========")
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var src: Skin = mi.skin
	for mode: String in ["現行(global_pose基準)", "修正(global_rest基準)"]:
		var s := Skin.new()
		for b: int in range(src.get_bind_count()):
			var bi: int = src.get_bind_bone(b)
			if bi == -1:
				bi = sk.find_bone(src.get_bind_name(b))
			if bi == -1:
				continue
			var basis_t: Transform3D = (sk.get_bone_global_pose(bi) if mode.begins_with("現行")
				else sk.get_bone_global_rest(bi))
			s.add_bind(bi, basis_t.affine_inverse())
		var bad := 0
		var worst := 0.0
		for b: int in range(s.get_bind_count()):
			var bi2: int = s.get_bind_bone(b)
			var m: Transform3D = sk.get_bone_global_rest(bi2) * s.get_bind_pose(b)
			var d: float = m.origin.length() + (m.basis.get_scale() - Vector3.ONE).length()
			worst = max(worst, d)
			if d > 0.001:
				bad += 1
		print("[%s] rest時に単位行列から外れる = %d / %d  最大ズレ = %.5f"
			% [mode, bad, s.get_bind_count(), worst])
	quit()
