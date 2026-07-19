extends SceneTree
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer"
func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	# 既定ポーズとrestが食い違うボーンを控えておく
	var mismatch: Dictionary = {}
	for i: int in range(sk.get_bone_count()):
		var d: float = (sk.get_bone_pose(i).origin - sk.get_bone_rest(i).origin).length()
		var dr: float = absf(sk.get_bone_pose(i).basis.get_rotation_quaternion()
			.angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion()))
		if d > 0.00001 or rad_to_deg(dr) > 0.5:
			mismatch[sk.get_bone_name(i)] = true
	print("既定ポーズとrestが食い違うボーン = ", mismatch.size(), " / ", sk.get_bone_count())
	print("")
	print("%-18s %6s %8s %10s %14s" % ["クリップ", "track", "対象骨", "無トラック骨", "うち食違い骨"])
	print("".lpad(64, "-"))
	var d2 := DirAccess.open(DIR)
	var clips: Array[String] = []
	d2.list_dir_begin()
	var f := d2.get_next()
	while f != "":
		if f.ends_with(".fbx"):
			clips.append(f.get_basename())
		f = d2.get_next()
	clips.sort()
	for clip: String in clips:
		var src: Node3D = (load(DIR + "/" + clip + ".fbx") as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if not ap or ap.get_animation_list().is_empty():
			continue
		var a: Animation = ap.get_animation(ap.get_animation_list()[0])
		var tracked: Dictionary = {}
		for i: int in range(a.get_track_count()):
			var p: NodePath = a.track_get_path(i)
			if p.get_subname_count() > 0:
				tracked[p.get_subname(0)] = true
		var untracked := 0
		var untracked_mismatch := 0
		for i: int in range(sk.get_bone_count()):
			var bn: String = sk.get_bone_name(i)
			if tracked.has(bn):
				continue
			untracked += 1
			if mismatch.has(bn):
				untracked_mismatch += 1
		print("%-18s %6d %8d %10d %14d"
			% [clip, a.get_track_count(), tracked.size(), untracked, untracked_mismatch])
		src.queue_free()
	print("")
	print("→ 『うち食違い骨』が多いクリップほど激しく壊れるはず（idle02 > Fly > idle01 なら仮説的中）")
	quit()
