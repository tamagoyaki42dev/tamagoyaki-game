extends SceneTree
# 検証済みハーネスで「どのボーンが壊しているか」を特定する。
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer/"
const CLIPS: Array[String] = ["Basic Attack", "FlyIdle", "idle02", "idle01"]
var sk: Skeleton3D
var verts: PackedVector3Array
var bones: PackedInt32Array
var weights: PackedFloat32Array
var idx: PackedInt32Array
var pv: int
var dloc: Array[Transform3D] = []
var bind: Array[Transform3D] = []

func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	sk = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	verts = arr[Mesh.ARRAY_VERTEX]; bones = arr[Mesh.ARRAY_BONES]
	weights = arr[Mesh.ARRAY_WEIGHTS]; idx = arr[Mesh.ARRAY_INDEX]
	pv = bones.size() / verts.size()
	for i: int in range(sk.get_bone_count()):
		dloc.append(sk.get_bone_pose(i))
	var dg: Array[Transform3D] = _globals(dloc)
	for i: int in range(sk.get_bone_count()):
		bind.append(dg[i].affine_inverse())

	for clip: String in CLIPS:
		var s: PackedScene = load(DIR + clip + ".fbx") as PackedScene
		if not s: continue
		var ap: AnimationPlayer = s.instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
		for i: int in range(a.get_track_count()):
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for k: int in range(a.track_get_key_count(i)):
					a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * 0.01)
		_analyze(clip, a, a.length * 0.35)
	quit()

func _analyze(clip: String, a: Animation, t: float) -> void:
	var loc: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		loc.append(sk.get_bone_rest(i))
	for i: int in range(a.get_track_count()):
		var p: NodePath = a.track_get_path(i)
		if p.get_subname_count() == 0: continue
		var b: int = sk.find_bone(p.get_subname(0))
		if b == -1: continue
		var tr: Transform3D = loc[b]
		match a.track_get_type(i):
			Animation.TYPE_POSITION_3D: tr.origin = a.position_track_interpolate(i, t)
			Animation.TYPE_ROTATION_3D:
				tr.basis = Basis(a.rotation_track_interpolate(i, t)).scaled(tr.basis.get_scale())
			Animation.TYPE_SCALE_3D:
				tr.basis = Basis(tr.basis.get_rotation_quaternion()).scaled(a.scale_track_interpolate(i, t))
		loc[b] = tr
	var glob: Array[Transform3D] = _globals(loc)
	# 頂点変形
	var out := PackedVector3Array(); out.resize(verts.size())
	var dom := PackedInt32Array(); dom.resize(verts.size())
	for v: int in range(verts.size()):
		var acc := Vector3.ZERO; var ws := 0.0; var bw := -1.0; var bb := 0
		for k: int in range(pv):
			var w: float = weights[v * pv + k]
			if w <= 0.0: continue
			var b2: int = bones[v * pv + k]
			acc += (glob[b2] * bind[b2]) * verts[v] * w; ws += w
			if w > bw: bw = w; bb = b2
		out[v] = acc / ws if ws > 0.0 else verts[v]
		dom[v] = bb
	# 破綻辺を支配ボーンへ集計
	var tally: Dictionary = {}
	var total_bad := 0
	for i: int in range(0, idx.size() - 2, 3):
		for e: Array in [[0, 1], [1, 2], [2, 0]]:
			var a0: int = idx[i + (e[0] as int)]; var a1: int = idx[i + (e[1] as int)]
			var l0: float = (verts[a0] - verts[a1]).length()
			if l0 <= 0.0001: continue
			var ratio: float = (out[a0] - out[a1]).length() / l0
			if ratio < 0.5 or ratio > 2.0:
				total_bad += 1
				for vv: int in [a0, a1]:
					var bn: String = sk.get_bone_name(dom[vv])
					tally[bn] = (tally.get(bn, 0) as int) + 1
	var ranked: Array = tally.keys()
	ranked.sort_custom(func(x, y): return (tally[x] as int) > (tally[y] as int))
	print("\n##### %s (t=%.2f)  破綻辺=%d #####" % [clip, t, total_bad])
	for i: int in range(min(8, ranked.size())):
		var bn2: String = ranked[i]
		var bi: int = sk.find_bone(bn2)
		var par: String = sk.get_bone_name(sk.get_bone_parent(bi)) if sk.get_bone_parent(bi) >= 0 else "-"
		var has_track := false
		for j: int in range(a.get_track_count()):
			var pp: NodePath = a.track_get_path(j)
			if pp.get_subname_count() > 0 and pp.get_subname(0) == bn2:
				has_track = true; break
		print("   %-20s 件数=%5d  親=%-16s トラック=%s  ポーズ倍率=%.4f"
			% [bn2, tally[bn2], par, "有" if has_track else "無",
			   (glob[bi] * bind[bi]).basis.get_scale().length() / sqrt(3.0)])

func _globals(local: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []; g.resize(sk.get_bone_count())
	for i: int in range(sk.get_bone_count()):
		var p: int = sk.get_bone_parent(i)
		g[i] = local[i] if p == -1 else g[p] * local[i]
	return g
