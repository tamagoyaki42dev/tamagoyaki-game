extends SceneTree
# 未検証の条件：FBX元来のバインド姿勢をそのまま使うと形は正しいのか。
# 一様スケール分は中央値で割って除去し、「形の破綻」だけを見る。
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer/"
var sk: Skeleton3D
var verts: PackedVector3Array
var bones: PackedInt32Array
var weights: PackedFloat32Array
var idx: PackedInt32Array
var pv: int

func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	sk = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	verts = arr[Mesh.ARRAY_VERTEX]; bones = arr[Mesh.ARRAY_BONES]
	weights = arr[Mesh.ARRAY_WEIGHTS]; idx = arr[Mesh.ARRAY_INDEX]
	pv = bones.size() / verts.size()

	var orig: Array[Transform3D] = []
	var rebuilt: Array[Transform3D] = []
	var dloc: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		dloc.append(sk.get_bone_pose(i))
	var dg: Array[Transform3D] = _globals(dloc)
	for i: int in range(sk.get_bone_count()):
		orig.append(mi.skin.get_bind_pose(i))
		rebuilt.append(dg[i].affine_inverse())

	for clip: String in ["Basic Attack", "FlyIdle", "idle01"]:
		var s: PackedScene = load(DIR + clip + ".fbx") as PackedScene
		var ap: AnimationPlayer = s.instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
		for i: int in range(a.get_track_count()):
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for k: int in range(a.track_get_key_count(i)):
					a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * 0.01)
		var glob: Array[Transform3D] = _globals(_pose(a, a.length * 0.35))
		print("\n##### ", clip, " #####")
		_m(glob, rebuilt, "現行(既定ポーズから再構築)")
		_m(glob, orig,    "FBX元来のバインドそのまま")

	quit()

func _pose(a: Animation, t: float) -> Array[Transform3D]:
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
	return loc

func _globals(local: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []; g.resize(sk.get_bone_count())
	for i: int in range(sk.get_bone_count()):
		var p: int = sk.get_bone_parent(i)
		g[i] = local[i] if p == -1 else g[p] * local[i]
	return g

func _m(glob: Array[Transform3D], bind: Array[Transform3D], label: String) -> void:
	var out := PackedVector3Array(); out.resize(verts.size())
	for v: int in range(verts.size()):
		var acc := Vector3.ZERO; var ws := 0.0
		for k: int in range(pv):
			var w: float = weights[v * pv + k]
			if w <= 0.0: continue
			var b: int = bones[v * pv + k]
			acc += (glob[b] * bind[b]) * verts[v] * w; ws += w
		out[v] = acc / ws if ws > 0.0 else verts[v]
	var r: Array[float] = []
	var step: int = max(3, (idx.size() / 3 / 800) * 3)
	for i: int in range(0, idx.size() - 2, step):
		for e: Array in [[0, 1], [1, 2], [2, 0]]:
			var a0: int = idx[i + (e[0] as int)]; var a1: int = idx[i + (e[1] as int)]
			var l0: float = (verts[a0] - verts[a1]).length()
			if l0 > 0.0001: r.append((out[a0] - out[a1]).length() / l0)
	r.sort()
	var med: float = r[r.size() / 2]
	var bad := 0
	for x: float in r:
		var norm: float = x / med   # 一様スケールを除去して形だけ見る
		if norm < 0.5 or norm > 2.0: bad += 1
	print("  %-26s 一様倍率=%.4f  形の破綻辺=%.1f%%" % [label, med, 100.0 * bad / max(1, r.size())])
