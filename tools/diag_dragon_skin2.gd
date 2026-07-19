extends SceneTree
# 診断その2：スキニング行列そのものを検算し、bind_pose再計算で直るかを試す。
#   M_i = bone_global_pose_i * bind_pose_i
#   rest姿勢では M_i は単位行列でなければならない（＝メッシュは無変形）。
#   単位行列から外れていれば「rest状態ですでにメッシュが歪む」＝今回の症状。
#   実行: godot --headless --path . -s tools/diag_dragon_skin2.gd

const MESH_FBX := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const ANIM_DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer"
const SAMPLE_CLIP := "idle01"

func _initialize() -> void:
	var ch: Node3D = (load(MESH_FBX) as PackedScene).instantiate()
	root.add_child(ch)
	var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var skin: Skin = mi.skin

	print("=========== A. rest状態のスキニング行列を検算 ===========")
	_report_skinning(skel, skin, "修正前")

	print("\n=========== B. bind_pose を rest から再計算したら？ ===========")
	var fixed: Skin = skin.duplicate()
	for b: int in range(fixed.get_bind_count()):
		var bn: String = fixed.get_bind_name(b)
		var idx: int = skel.find_bone(bn) if not bn.is_empty() else fixed.get_bind_bone(b)
		if idx < 0:
			continue
		fixed.set_bind_pose(b, skel.get_bone_global_rest(idx).affine_inverse())
	_report_skinning(skel, fixed, "再計算後")

	print("\n=========== C. アニメでボーンが実際に動くか（ツリーを回す） ===========")
	var ap := AnimationPlayer.new()
	ap.name = "DiagAP"
	ch.add_child(ap)
	ap.root_node = ap.get_path_to(ch)
	var src: Node3D = (load(ANIM_DIR + "/" + SAMPLE_CLIP + ".fbx") as PackedScene).instantiate()
	var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a: Animation = src_ap.get_animation(src_ap.get_animation_list()[0]).duplicate()
	# battle_scene.gd と同じ前処理（位置トラックを0.01倍）を再現する
	for i: int in range(a.get_track_count()):
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		for k: int in range(a.track_get_key_count(i)):
			a.track_set_key_value(i, k, (a.track_get_key_value(i, k) as Vector3) * 0.01)
	var lib := AnimationLibrary.new()
	lib.add_animation(SAMPLE_CLIP, a)
	ap.add_animation_library("", lib)

	var rest_g: Array[Transform3D] = []
	for i: int in range(skel.get_bone_count()):
		rest_g.append(skel.get_bone_global_rest(i))

	ap.play(SAMPLE_CLIP)
	for step: int in range(4):
		var t: float = a.length * (float(step) / 4.0)
		ap.seek(t, true)
		# AnimationMixerはプロセス経由で反映されるので明示的に回す
		ap.advance(0.0)
		var moved := 0
		var max_move := 0.0
		for i: int in range(skel.get_bone_count()):
			var d: float = (skel.get_bone_global_pose(i).origin - rest_g[i].origin).length()
			max_move = max(max_move, d)
			if d > 0.0005:
				moved += 1
		print("t=%.2f  restから動いたボーン = %d / %d   最大移動量 = %.5f"
			% [t, moved, skel.get_bone_count(), max_move])

	print("\n=========== D. 動作中のスキニング行列（修正前 vs 再計算後） ===========")
	ap.seek(a.length * 0.5, true)
	ap.advance(0.0)
	_report_skinning_posed(skel, skin, "修正前")
	_report_skinning_posed(skel, fixed, "再計算後")

	print("\n=========== 診断ここまで ===========")
	quit()

func _report_skinning(skel: Skeleton3D, skin: Skin, label: String) -> void:
	var worst_pos := 0.0
	var worst_scale := 0.0
	var bad := 0
	for b: int in range(skin.get_bind_count()):
		var bn: String = skin.get_bind_name(b)
		var idx: int = skel.find_bone(bn) if not bn.is_empty() else skin.get_bind_bone(b)
		if idx < 0:
			continue
		var m: Transform3D = skel.get_bone_global_rest(idx) * skin.get_bind_pose(b)
		var dp: float = m.origin.length()
		var ds: float = (m.basis.get_scale() - Vector3.ONE).length()
		worst_pos = max(worst_pos, dp)
		worst_scale = max(worst_scale, ds)
		if dp > 0.001 or ds > 0.001:
			bad += 1
	print("[%s] rest時に単位行列から外れるボーン = %d / %d" % [label, bad, skin.get_bind_count()])
	print("        最大の位置ズレ = %.5f  /  最大のスケールズレ = %.5f" % [worst_pos, worst_scale])
	print("        → 0に近いほど正常（rest状態でメッシュが無変形）")

func _report_skinning_posed(skel: Skeleton3D, skin: Skin, label: String) -> void:
	var worst_scale := 0.0
	var sum_scale := 0.0
	var n := 0
	for b: int in range(skin.get_bind_count()):
		var bn: String = skin.get_bind_name(b)
		var idx: int = skel.find_bone(bn) if not bn.is_empty() else skin.get_bind_bone(b)
		if idx < 0:
			continue
		var m: Transform3D = skel.get_bone_global_pose(idx) * skin.get_bind_pose(b)
		var s: float = m.basis.get_scale().length() / sqrt(3.0)
		worst_scale = max(worst_scale, abs(s - 1.0))
		sum_scale += s
		n += 1
	print("[%s] 動作中のスキニング倍率 平均=%.4f  最大逸脱=%.4f" % [label, sum_scale / max(1, n), worst_scale])
	print("        → 平均が1.0から大きく外れるとメッシュが潰れる/膨れる")
