extends SceneTree
# メッシュを実際にスキニングして変形量を測る。辺の長さが保たれていれば正常、
# 大きく伸縮していればメッシュが潰れている＝画面の「原形をとどめない」の正体。
const MESH_FBX := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const ANIM := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer/idle01.fbx"

func _initialize() -> void:
	var ch: Node3D = (load(MESH_FBX) as PackedScene).instantiate()
	root.add_child(ch)
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per_vert: int = bones.size() / verts.size()
	print("頂点=", verts.size(), " 三角形=", idx.size() / 3, " 1頂点あたりの影響ボーン数=", per_vert)

	for basis_mode: String in ["global_pose基準(裏の実装)", "global_rest基準(今回の修正)"]:
		var skin := Skin.new()
		var src_skin: Skin = mi.skin
		for b: int in range(src_skin.get_bind_count()):
			var bi: int = src_skin.get_bind_bone(b)
			if bi == -1:
				bi = sk.find_bone(src_skin.get_bind_name(b))
			if bi == -1:
				continue
			var t: Transform3D = (sk.get_bone_global_pose(bi) if basis_mode.begins_with("global_pose")
				else sk.get_bone_global_rest(bi))
			skin.add_bind(bi, t.affine_inverse())
		print("\n########## ", basis_mode, " ##########")
		_measure(sk, skin, verts, bones, weights, idx, per_vert, "アニメなし(rest)", null, 0.0)
		var a: Animation = _load_anim()
		_measure(sk, skin, verts, bones, weights, idx, per_vert, "idle01 t=0.5", a, 0.5)
	quit()

func _load_anim() -> Animation:
	var src: Node3D = (load(ANIM) as PackedScene).instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
	for i: int in range(a.get_track_count()):
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		for k: int in range(a.track_get_key_count(i)):
			a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * 0.01)
	return a

func _measure(sk: Skeleton3D, skin: Skin, verts: PackedVector3Array, bones: PackedInt32Array,
		weights: PackedFloat32Array, idx: PackedInt32Array, per_vert: int,
		label: String, a: Animation, t: float) -> void:
	sk.reset_bone_poses()
	if a:
		for i: int in range(a.get_track_count()):
			var p: NodePath = a.track_get_path(i)
			if p.get_subname_count() == 0:
				continue
			var bi: int = sk.find_bone(p.get_subname(0))
			if bi == -1:
				continue
			match a.track_get_type(i):
				Animation.TYPE_POSITION_3D:
					sk.set_bone_pose_position(bi, a.position_track_interpolate(i, t))
				Animation.TYPE_ROTATION_3D:
					sk.set_bone_pose_rotation(bi, a.rotation_track_interpolate(i, t))
				Animation.TYPE_SCALE_3D:
					sk.set_bone_pose_scale(bi, a.scale_track_interpolate(i, t))
	# スキニング行列
	var mats: Dictionary = {}
	for b: int in range(skin.get_bind_count()):
		var bi2: int = skin.get_bind_bone(b)
		mats[bi2] = sk.get_bone_global_pose(bi2) * skin.get_bind_pose(b)
	# 頂点変形
	var out := PackedVector3Array()
	out.resize(verts.size())
	for v: int in range(verts.size()):
		var acc := Vector3.ZERO
		var wsum := 0.0
		for k: int in range(per_vert):
			var w: float = weights[v * per_vert + k]
			if w <= 0.0:
				continue
			var bi3: int = bones[v * per_vert + k]
			if not mats.has(bi3):
				continue
			acc += (mats[bi3] as Transform3D) * verts[v] * w
			wsum += w
		out[v] = acc / wsum if wsum > 0.0 else verts[v]
	# 辺の長さ比を測る
	var ratios: Array[float] = []
	var step: int = max(3, (idx.size() / 3 / 800) * 3)
	for i: int in range(0, idx.size() - 2, step):
		for e: Array in [[0, 1], [1, 2], [2, 0]]:
			var v0: int = idx[i + (e[0] as int)]
			var v1: int = idx[i + (e[1] as int)]
			var l0: float = (verts[v0] - verts[v1]).length()
			var l1: float = (out[v0] - out[v1]).length()
			if l0 > 0.0001:
				ratios.append(l1 / l0)
	ratios.sort()
	var mean := 0.0
	for r: float in ratios:
		mean += r
	mean /= max(1, ratios.size())
	print("[%s] 辺長比: 中央値=%.4f 平均=%.4f 最小=%.4f 最大=%.4f  (1.0が無変形)"
		% [label, ratios[ratios.size() / 2], mean, ratios[0], ratios[ratios.size() - 1]])
	var broken := 0
	for r2: float in ratios:
		if r2 < 0.5 or r2 > 2.0:
			broken += 1
	print("        半分以下/2倍以上に伸縮した辺 = %d / %d (%.1f%%)"
		% [broken, ratios.size(), 100.0 * broken / max(1, ratios.size())])
