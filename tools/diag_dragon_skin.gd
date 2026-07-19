extends SceneTree
# ドラゴンの「ボーンは動くのにメッシュが付いてこない」現象の診断用。
# 目視できない不具合を数値で出すのが目的。ヘッドレスで完結する（描画しない）。
#   実行: godot --headless --path . -s tools/diag_dragon_skin.gd

const MESH_FBX := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const ANIM_DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer"
const SAMPLE_CLIP := "idle01"

func _initialize() -> void:
	var scene: PackedScene = load(MESH_FBX)
	if not scene:
		print("!! メッシュFBXを読めない: ", MESH_FBX)
		quit()
		return
	var ch: Node3D = scene.instantiate()
	root.add_child(ch)

	print("=========== 1. ノード構成 ===========")
	_dump_tree(ch, 0)

	var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		print("!! Skeleton3D が見つからない")
		quit()
		return

	print("\n=========== 2. スケルトン ===========")
	print("bone_count = ", skel.get_bone_count())
	print("skeleton path = ", ch.get_path_to(skel))
	var rest_mag_sum := 0.0
	for i: int in range(skel.get_bone_count()):
		rest_mag_sum += skel.get_bone_rest(i).origin.length()
	print("rest原点の平均距離 = ", rest_mag_sum / max(1, skel.get_bone_count()),
		"  (メートル単位なら0.0x台 / cm単位なら数〜数十)")
	print("ルート3本のrest = ")
	for i: int in range(min(3, skel.get_bone_count())):
		print("   [", i, "] ", skel.get_bone_name(i), " rest.origin=", skel.get_bone_rest(i).origin,
			" scale=", skel.get_bone_rest(i).basis.get_scale())

	print("\n=========== 3. メッシュとスキンの結び付き ===========")
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(ch, meshes)
	print("MeshInstance3D の数 = ", meshes.size())
	for mi: MeshInstance3D in meshes:
		print("--- ", mi.name)
		print("   mi.skeleton(NodePath) = '", mi.skeleton, "'")
		var target: Node = mi.get_node_or_null(mi.skeleton)
		var points_to_skel: bool = (target == skel)
		print("   → 解決先が上のSkeleton3Dか = ", points_to_skel, "  (falseならスキンが効かない直接原因)")
		var sk: Skin = mi.skin
		if not sk:
			print("   !! skin が null（＝スキンメッシュとして扱われていない）")
			continue
		print("   bind_count = ", sk.get_bind_count())
		var name_hit := 0
		var name_miss: Array[String] = []
		var bind_scale_sum := 0.0
		for b: int in range(sk.get_bind_count()):
			var bn: String = sk.get_bind_name(b)
			var idx: int = skel.find_bone(bn) if not bn.is_empty() else sk.get_bind_bone(b)
			if idx >= 0:
				name_hit += 1
			elif name_miss.size() < 8:
				name_miss.append(bn if not bn.is_empty() else "(bone_idx=%d)" % sk.get_bind_bone(b))
			bind_scale_sum += sk.get_bind_pose(b).basis.get_scale().x
		print("   bindがスケルトンのボーンに一致 = ", name_hit, " / ", sk.get_bind_count())
		if not name_miss.is_empty():
			print("   一致しないbind名(先頭) = ", name_miss)
		print("   bind_poseの平均スケール = ", bind_scale_sum / max(1, sk.get_bind_count()),
			"  (1.0なら未スケール / 100なら1/100メッシュ用に補正済み)")
		# バインド姿勢とrestの整合（本来 bind_pose ≒ global_rest の逆行列）
		var mismatch := 0
		var worst := 0.0
		for b: int in range(sk.get_bind_count()):
			var bn2: String = sk.get_bind_name(b)
			var idx2: int = skel.find_bone(bn2) if not bn2.is_empty() else sk.get_bind_bone(b)
			if idx2 < 0:
				continue
			var expected: Transform3D = skel.get_bone_global_rest(idx2).affine_inverse()
			var d: float = (sk.get_bind_pose(b).origin - expected.origin).length()
			worst = max(worst, d)
			if d > 0.01:
				mismatch += 1
		print("   bind_pose と global_rest^-1 のズレ: 0.01超 = ", mismatch, " 本 / 最大ズレ = ", worst)
		print("      → ここが大きいと『メッシュがバインド姿勢のまま歪むだけ』になる")

	print("\n=========== 4. アニメのトラック解決 ===========")
	var anim_scene: PackedScene = load(ANIM_DIR + "/" + SAMPLE_CLIP + ".fbx")
	if not anim_scene:
		print("!! アニメFBXを読めない")
		quit()
		return
	var src: Node3D = anim_scene.instantiate()
	var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a: Animation = src_ap.get_animation(src_ap.get_animation_list()[0]).duplicate()
	print("クリップ = ", SAMPLE_CLIP, " / length = ", a.length, " / track数 = ", a.get_track_count())
	var pos_tracks := 0
	var rot_tracks := 0
	var scl_tracks := 0
	var resolved := 0
	var unresolved: Array[String] = []
	for i: int in range(a.get_track_count()):
		var t: int = a.track_get_type(i)
		if t == Animation.TYPE_POSITION_3D: pos_tracks += 1
		elif t == Animation.TYPE_ROTATION_3D: rot_tracks += 1
		elif t == Animation.TYPE_SCALE_3D: scl_tracks += 1
		var p: NodePath = a.track_get_path(i)
		var bone_name: String = p.get_subname(0) if p.get_subname_count() > 0 else ""
		if not bone_name.is_empty() and skel.find_bone(bone_name) >= 0:
			resolved += 1
		elif unresolved.size() < 10:
			unresolved.append(str(p))
	print("位置 = ", pos_tracks, " / 回転 = ", rot_tracks, " / スケール = ", scl_tracks)
	print("スケルトンのボーン名に解決できたトラック = ", resolved, " / ", a.get_track_count())
	if not unresolved.is_empty():
		print("解決できないトラック(先頭) = ", unresolved)
	print("トラックのパス例 = ", a.track_get_path(0))

	# 位置トラックの実値スケール感（cmのままか、メートルか）
	var pmag := 0.0
	var pn := 0
	for i: int in range(a.get_track_count()):
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if a.track_get_key_count(i) > 0:
			pmag += (a.track_get_key_value(i, 0) as Vector3).length()
			pn += 1
	print("位置トラック値の平均距離 = ", pmag / max(1, pn), "  (restの平均と桁が合っているかを見る)")

	print("\n=========== 5. 再生してボーンが実際に動くか ===========")
	var ap := AnimationPlayer.new()
	ap.name = "DiagAP"
	ch.add_child(ap)
	var armature: Node3D = ch.find_child("Armature", true, false) as Node3D
	print("Armatureノードが見つかったか = ", armature != null)
	ap.root_node = ap.get_path_to(armature if armature else ch)
	print("ap.root_node = '", ap.root_node, "'")
	var lib := AnimationLibrary.new()
	lib.add_animation(SAMPLE_CLIP, a)
	ap.add_animation_library("", lib)

	var rest_poses: Array[Transform3D] = []
	for i: int in range(skel.get_bone_count()):
		rest_poses.append(skel.get_bone_global_pose(i))

	ap.play(SAMPLE_CLIP)
	var times: Array[float] = [0.0, a.length * 0.25, a.length * 0.5, a.length * 0.75]
	for t: float in times:
		ap.seek(t, true)
		var moved := 0
		var max_move := 0.0
		for i: int in range(skel.get_bone_count()):
			var d: float = (skel.get_bone_global_pose(i).origin - rest_poses[i].origin).length()
			max_move = max(max_move, d)
			if d > 0.001:
				moved += 1
		print("t=%.2f  動いたボーン = %d / %d   最大移動量 = %.5f"
			% [t, moved, skel.get_bone_count(), max_move])

	print("\n=========== 診断ここまで ===========")
	quit()

func _dump_tree(n: Node, depth: int) -> void:
	if depth > 3:
		return
	var pad := ""
	for i: int in range(depth):
		pad += "  "
	print(pad, n.name, "  [", n.get_class(), "]")
	for c: Node in n.get_children():
		_dump_tree(c, depth + 1)

func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		_collect_meshes(c, out)
