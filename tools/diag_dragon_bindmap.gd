extends SceneTree
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var skin: Skin = mi.skin
	print("skin.bind_count = ", skin.get_bind_count(), " / skeleton.bone_count = ", sk.get_bone_count())
	var identity := true
	var shown := 0
	for b: int in range(skin.get_bind_count()):
		var bi: int = skin.get_bind_bone(b)
		var bn: String = skin.get_bind_name(b)
		var by_name: int = sk.find_bone(bn) if not bn.is_empty() else -1
		if bi != b or (by_name != -1 and by_name != b):
			identity = false
			if shown < 8:
				print("  bind[%d] → get_bind_bone=%d  name='%s'(bone %d)" % [b, bi, bn, by_name])
				shown += 1
	print("バインド番号 == ボーン番号 か = ", identity)
	print("→ falseなら私の変形測定は誤り（番号を取り違えて計算していた）")

	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var fmt: int = (mi.mesh as ArrayMesh).surface_get_format(0)
	print("")
	print("ARRAY_BONES の最大値 = ", _maxv(bones), " / 最小値 = ", _minv(bones))
	print("8ボーンウェイトのフラグ = ", (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0)
	print("頂点あたりの影響数 = ", bones.size() / (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	# ウェイト合計の健全性
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var pv: int = bones.size() / (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var bad := 0
	var worst := 0.0
	for v: int in range((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()):
		var s := 0.0
		for k: int in range(pv):
			s += w[v * pv + k]
		if absf(s - 1.0) > 0.01:
			bad += 1
		worst = max(worst, absf(s - 1.0))
	print("ウェイト合計が1.0から外れる頂点 = ", bad, "  最大逸脱 = %.4f" % worst)
	quit()
func _maxv(a: PackedInt32Array) -> int:
	var m := -999
	for x: int in a: m = max(m, x)
	return m
func _minv(a: PackedInt32Array) -> int:
	var m := 999999
	for x: int in a: m = min(m, x)
	return m
