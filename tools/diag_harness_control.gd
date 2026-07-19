extends SceneTree
# ハーネス検証：正常と分かっているKayKitキャラを同じ方法で測る。
# ここで破綻ゼロが出なければハーネスが間違っている＝ドラゴンの数値も信用できない。
const CASES: Array[Dictionary] = [
	{"name": "KayKit Knight", "mesh": "res://assets/kaykit/characters/Knight.glb",
	 "anim": "res://assets/kaykit/animations/Rig_Medium_General.glb", "clips": ["Idle", "Walking_A"]},
	{"name": "ドラゴン", "mesh": "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx",
	 "anim": "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer/idle01.fbx",
	 "clips": [""], "pos_scale": 0.01},
]

func _initialize() -> void:
	for c: Dictionary in CASES:
		_run_case(c)
	print("\n→ KayKitで破綻≒0%が出れば、ハーネスは正常/破綻を区別できている")
	quit()

func _run_case(c: Dictionary) -> void:
	print("\n########## ", c["name"], " ##########")
	var scene: PackedScene = load(c["mesh"] as String) as PackedScene
	if not scene:
		print("  メッシュを読めない: ", c["mesh"]); return
	var ch: Node3D = scene.instantiate()
	root.add_child(ch)
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	if not sk:
		print("  Skeleton3Dが無い"); return
	var mis: Array[Node] = ch.find_children("*", "MeshInstance3D", true, false)
	var mi: MeshInstance3D = null
	for n: Node in mis:
		var cand := n as MeshInstance3D
		if cand.skin and cand.mesh:
			mi = cand
			break
	if not mi:
		print("  スキン付きメッシュが無い"); return
	print("  骨=", sk.get_bone_count(), " メッシュ=", mi.name, " bind=", mi.skin.get_bind_count())

	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var pv: int = bones.size() / verts.size()

	# バインド基準＝既定ポーズ（ドラゴンの現行実装と同じ扱い）
	var dloc: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		dloc.append(sk.get_bone_pose(i))
	var dglob: Array[Transform3D] = _globals(sk, dloc)
	var bind: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		bind.append(dglob[i].affine_inverse())

	_measure(sk, verts, bones, weights, idx, pv, dglob, bind, "(既定ポーズ＝無変形の基準)")

	var asrc: PackedScene = load(c["anim"] as String) as PackedScene
	var ap: AnimationPlayer = asrc.instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var names: PackedStringArray = ap.get_animation_list()
	print("  アニメ側クリップ数=", names.size())
	var wanted: Array = c["clips"] as Array
	for w: Variant in wanted:
		var clip: String = ""
		for n2: String in names:
			if (w as String).is_empty() or n2.findn(w as String) != -1:
				clip = n2
				break
		if clip.is_empty():
			print("  クリップ未発見: ", w); continue
		var a: Animation = ap.get_animation(clip).duplicate()
		var ps: float = c.get("pos_scale", 1.0)
		if ps != 1.0:
			for i: int in range(a.get_track_count()):
				if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
					for k: int in range(a.track_get_key_count(i)):
						a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * ps)
		for f: float in [0.3, 0.7]:
			var loc: Array[Transform3D] = _pose(sk, a, a.length * f, dloc)
			_measure(sk, verts, bones, weights, idx, pv, _globals(sk, loc), bind,
				"%s t=%.2f" % [clip, a.length * f])

func _pose(sk: Skeleton3D, a: Animation, t: float, fallback: Array[Transform3D]) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		out.append(sk.get_bone_rest(i))
	var hit := 0
	for i: int in range(a.get_track_count()):
		var p: NodePath = a.track_get_path(i)
		if p.get_subname_count() == 0:
			continue
		var b: int = sk.find_bone(p.get_subname(0))
		if b == -1:
			continue
		hit += 1
		var tr: Transform3D = out[b]
		match a.track_get_type(i):
			Animation.TYPE_POSITION_3D:
				tr.origin = a.position_track_interpolate(i, t)
			Animation.TYPE_ROTATION_3D:
				tr.basis = Basis(a.rotation_track_interpolate(i, t)).scaled(tr.basis.get_scale())
			Animation.TYPE_SCALE_3D:
				tr.basis = Basis(tr.basis.get_rotation_quaternion()).scaled(a.scale_track_interpolate(i, t))
		out[b] = tr
	return out

func _globals(sk: Skeleton3D, local: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	g.resize(sk.get_bone_count())
	for i: int in range(sk.get_bone_count()):
		var p: int = sk.get_bone_parent(i)
		g[i] = local[i] if p == -1 else g[p] * local[i]
	return g

func _measure(sk: Skeleton3D, verts: PackedVector3Array, bones: PackedInt32Array,
		weights: PackedFloat32Array, idx: PackedInt32Array, pv: int,
		glob: Array[Transform3D], bind: Array[Transform3D], label: String) -> void:
	var out := PackedVector3Array(); out.resize(verts.size())
	for v: int in range(verts.size()):
		var acc := Vector3.ZERO; var ws := 0.0
		for k: int in range(pv):
			var w: float = weights[v * pv + k]
			if w <= 0.0: continue
			var b: int = bones[v * pv + k]
			if b >= glob.size(): continue
			acc += (glob[b] * bind[b]) * verts[v] * w
			ws += w
		out[v] = acc / ws if ws > 0.0 else verts[v]
	var r: Array[float] = []
	var step: int = max(3, (idx.size() / 3 / 700) * 3)
	for i: int in range(0, idx.size() - 2, step):
		for e: Array in [[0, 1], [1, 2], [2, 0]]:
			var a0: int = idx[i + (e[0] as int)]; var a1: int = idx[i + (e[1] as int)]
			var l0: float = (verts[a0] - verts[a1]).length()
			if l0 > 0.0001:
				r.append((out[a0] - out[a1]).length() / l0)
	r.sort()
	var bad := 0
	for x: float in r:
		if x < 0.5 or x > 2.0: bad += 1
	print("    %-26s 中央値=%.4f 最小=%.4f 最大=%.4f 破綻辺=%.1f%%"
		% [label, r[r.size()/2], r[0], r[r.size()-1], 100.0*bad/max(1,r.size())])
