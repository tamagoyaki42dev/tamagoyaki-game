extends SceneTree
# 骨格レベルの検査：アニメ再生中にボーンの長さ（親からの距離）が保たれるか。
# 保たれない＝骨格自体が伸びている（アニメ/合流の問題）。
# 保たれる＝骨格は正常でメッシュへの割り当てがズレている（スキンの問題）。
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer/"
var sk: Skeleton3D

func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	sk = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	# 重複名サフィックスの一覧
	var suffixed: Array[String] = []
	for i: int in range(sk.get_bone_count()):
		var n: String = sk.get_bone_name(i)
		if n.ends_with("_2") or n.ends_with("L1") or n.ends_with("R1"):
			suffixed.append(n)
	print("連番サフィックス付きボーン(%d本) = %s" % [suffixed.size(), suffixed])

	for clip: String in ["Basic Attack", "FlyIdle", "idle01"]:
		var s: PackedScene = load(DIR + clip + ".fbx") as PackedScene
		var ap: AnimationPlayer = s.instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
		for i: int in range(a.get_track_count()):
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for k: int in range(a.track_get_key_count(i)):
					a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * 0.01)
		_check(clip, a, a.length * 0.35)
	quit()

func _check(clip: String, a: Animation, t: float) -> void:
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
	var g: Array[Transform3D] = []; g.resize(sk.get_bone_count())
	var gr: Array[Transform3D] = []; gr.resize(sk.get_bone_count())
	for i: int in range(sk.get_bone_count()):
		var par: int = sk.get_bone_parent(i)
		g[i] = loc[i] if par == -1 else g[par] * loc[i]
		gr[i] = sk.get_bone_rest(i) if par == -1 else gr[par] * sk.get_bone_rest(i)
	var bad: Array[String] = []
	var worst := 0.0
	for i: int in range(sk.get_bone_count()):
		var par2: int = sk.get_bone_parent(i)
		if par2 < 0: continue
		var l_rest: float = (gr[i].origin - gr[par2].origin).length()
		var l_now: float = (g[i].origin - g[par2].origin).length()
		if l_rest < 1e-6: continue
		var r: float = l_now / l_rest
		worst = max(worst, absf(r - 1.0))
		if absf(r - 1.0) > 0.02:
			bad.append("%s(%.2f倍)" % [sk.get_bone_name(i), r])
	print("\n[%s] 骨の長さが変わったボーン = %d / %d   最大逸脱 = %.4f"
		% [clip, bad.size(), sk.get_bone_count(), worst])
	if not bad.is_empty():
		print("   ", bad.slice(0, 12))
	else:
		print("   → 骨格は完全に剛体。伸びていない＝アニメ側は正常、スキン割り当てが原因")
