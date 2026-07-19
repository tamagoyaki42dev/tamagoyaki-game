extends SceneTree
# 診断その3：クリップが「時間で変化しているか」をAnimationPlayerを介さずに直接調べる。
# 手足が動かない症状が (a)アニメデータ自体が静止 (b)再生側の問題 のどちらかを切り分ける。
#   実行: godot --headless --path . -s tools/diag_dragon_time.gd

const ANIM_DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer"

func _initialize() -> void:
	for clip: String in ["idle01", "Run", "Basic Attack", "Flame Attack", "die"]:
		_check(clip)
	print("\n=========== 診断ここまで ===========")
	quit()

func _check(clip: String) -> void:
	var scene: PackedScene = load(ANIM_DIR + "/" + clip + ".fbx") as PackedScene
	if not scene:
		print("\n[", clip, "] 読み込めない")
		return
	var src: Node3D = scene.instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not ap or ap.get_animation_list().is_empty():
		print("\n[", clip, "] AnimationPlayerかクリップが無い")
		return
	var a: Animation = ap.get_animation(ap.get_animation_list()[0])

	var total_keys := 0
	var multi_key_tracks := 0
	var single_key_tracks := 0
	# 回転トラックが時間で実際に変化しているか（先頭キーと最大乖離）
	var max_rot_delta := 0.0
	var busiest := ""
	for i: int in range(a.get_track_count()):
		var kc: int = a.track_get_key_count(i)
		total_keys += kc
		if kc > 1:
			multi_key_tracks += 1
		elif kc == 1:
			single_key_tracks += 1
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D or kc < 2:
			continue
		var q0: Quaternion = a.track_get_key_value(i, 0)
		for k: int in range(1, kc):
			var qk: Quaternion = a.track_get_key_value(i, k)
			var d: float = absf(q0.angle_to(qk))
			if d > max_rot_delta:
				max_rot_delta = d
				busiest = str(a.track_get_path(i))

	print("\n[", clip, "] length=%.3f  track=%d  総キー数=%d" % [a.length, a.get_track_count(), total_keys])
	print("   キーが2個以上のトラック = ", multi_key_tracks, " / キー1個だけ = ", single_key_tracks)
	print("   回転の最大変化 = %.2f 度  (最大のトラック: %s)" % [rad_to_deg(max_rot_delta), busiest])
	print("   → 度数が0に近いとクリップ自体が静止。大きければデータは動いている")
