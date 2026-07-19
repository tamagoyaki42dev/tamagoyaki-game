extends SceneTree
# 変形測定ハーネス（手計算版）。Godotのポーズ更新タイミングに一切依存せず、
# ボーン階層を自前でたどってスキニングを再現し、辺の伸縮を測る。
#   実行: godot --headless --path . -s tools/diag_dragon_deform2.gd
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer"
const CLIPS: Array[String] = ["idle01", "idle02", "Basic Attack", "FlyIdle", "Run"]

var sk: Skeleton3D
var verts: PackedVector3Array
var bones: PackedInt32Array
var weights: PackedFloat32Array
var idx: PackedInt32Array
var per_vert: int

func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	sk = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	verts = arr[Mesh.ARRAY_VERTEX]; bones = arr[Mesh.ARRAY_BONES]
	weights = arr[Mesh.ARRAY_WEIGHTS]; idx = arr[Mesh.ARRAY_INDEX]
	per_vert = bones.size() / verts.size()

	# バインド基準＝既定ポーズ（＝現行実装）。自前グローバルで作る
	var default_local: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		default_local.append(sk.get_bone_pose(i))
	var default_global: Array[Transform3D] = _globals(default_local)
	var bind: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		bind.append(default_global[i].affine_inverse())

	print("既定ポーズとrestが食い違う骨 = %d / %d" % [_count_mismatch(), sk.get_bone_count()])
	print("")
	print("%-14s %10s %10s %10s %12s" % ["クリップ", "中央値", "最小", "最大", "破綻辺%"])
	print("".lpad(62, "-"))
	# 無変形の基準（既定ポーズのまま）
	_run("(既定ポーズ)", default_local, default_global, bind)
	for clip: String in CLIPS:
		for fallback: String in ["rest", "既定"]:
			var a: Animation = _load(clip)
			if not a:
				continue
			for t: float in [a.length * 0.3, a.length * 0.7]:
				var loc: Array[Transform3D] = _pose_at(a, t, fallback == "rest", default_local)
				_run("%s t=%.1f/%s" % [clip, t, fallback], loc, _globals(loc), bind)
	print("")
	print("→ 『rest』は現状（トラック無し骨をrestへ）／『既定』は今入れた修正の効果")
	quit()

func _count_mismatch() -> int:
	var n := 0
	for i: int in range(sk.get_bone_count()):
		if (sk.get_bone_pose(i).origin - sk.get_bone_rest(i).origin).length() > 0.00001:
			n += 1
	return n

func _load(clip: String) -> Animation:
	var s: PackedScene = load(DIR + "/" + clip + ".fbx") as PackedScene
	if not s:
		return null
	var ap: AnimationPlayer = s.instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
	for i: int in range(a.get_track_count()):
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			for k: int in range(a.track_get_key_count(i)):
				a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * 0.01)
	return a

func _pose_at(a: Animation, t: float, use_rest: bool, default_local: Array[Transform3D]) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in range(sk.get_bone_count()):
		out.append(sk.get_bone_rest(i) if use_rest else default_local[i])
	for i: int in range(a.get_track_count()):
		var p: NodePath = a.track_get_path(i)
		if p.get_subname_count() == 0:
			continue
		var b: int = sk.find_bone(p.get_subname(0))
		if b == -1:
			continue
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

func _globals(local: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	g.resize(sk.get_bone_count())
	for i: int in range(sk.get_bone_count()):
		var p: int = sk.get_bone_parent(i)
		g[i] = local[i] if p == -1 else g[p] * local[i]
	return g

func _run(label: String, _local: Array[Transform3D], glob: Array[Transform3D], bind: Array[Transform3D]) -> void:
	var out := PackedVector3Array(); out.resize(verts.size())
	for v: int in range(verts.size()):
		var acc := Vector3.ZERO; var ws := 0.0
		for k: int in range(per_vert):
			var w: float = weights[v * per_vert + k]
			if w <= 0.0: continue
			var b: int = bones[v * per_vert + k]
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
	print("%-14s %10.4f %10.4f %10.4f %11.1f%%"
		% [label, r[r.size() / 2], r[0], r[r.size() - 1], 100.0 * bad / max(1, r.size())])
