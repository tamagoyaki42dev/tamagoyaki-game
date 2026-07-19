extends GutTest

# dungeon_masonドラゴンの外部アニメ合流（2026-07-19・FBX直接方式）。
# GLB本体はアニメ0本・ボーン83本中29本がFBXと別名（重複名の流儀違い）で名前ベース合流が
# 破裂する事故を踏んだため、メッシュ専用FBXを実体にする方式へ切り替えた
# （メッシュFBXとアニメFBXは同じ配布物由来でボーン名が完全一致する）。
# この事故の再発を機械的に検知するため、合流後の全トラックのボーン名が
# 実際のSkeleton3Dに存在することまで確認する（has_animation()だけでは検知できない）。
#
# スケール方針（2026-07-19に3回変更）：
# 1回目＝.importのroot_scaleを焼かず素のFBXのままNode3D.scaleだけで縮める方式にしたが、
#   実機で再生すると消える不具合を踏んだ（当時は「Node.scaleが極小(0.002前後)だと
#   GPUスキニングが描画されなくなる」と誤って推定した）。
# 2回目＝.importのroot_scale=0.01でメッシュのrest姿勢を焼き、Node3D.scaleを静止GLB版と
#   同程度の通常範囲に戻したが、それでも実機で再生すると消える不具合が再現した
#   （Node.scaleの大小は無関係だったと判明）。
# 3回目（現在、本当の原因）＝メッシュFBXのSkin（頂点↔ボーンの逆バインド行列）が、
#   Skeleton3Dが実際に報告するrest姿勢と恒常的に一致していないことが判明した
#   （root_scaleの値に関係なく常に、全83ボーンで「rest姿勢×逆バインド行列」がscale=0.01だけ
#   ズレる＝インポータがSkinをボーンのスケール成分抜きで計算しているとみられる）。
#   restのままなら影響しない（Godotはボーン姿勢が一度も変更されていないメッシュはGPUスキニング
#   計算自体をスキップするとみられる）が、アニメーションでボーン姿勢に触れた瞬間にスキニング
#   計算が実際に走り、このズレがそのまま反映されて全身が1/100サイズまで縮んで事実上不可視に
#   なる。BattleScene._fix_dragon_skin() が、Skeleton3Dの実際のrest姿勢からSkinを作り直す
#   ことでこの不整合を解消している＝本ファイルの本命テスト。
#
# root_scaleの縮小は今も焼いている（Node3D.scaleを静止GLB版と同程度の範囲に保つため）。
# ただしrest姿勢だけ縮めると外部合流するアニメFBXの位置トラック（cm単位のまま・原寸）との間に
# 単位不一致が生じRootボーンが100倍の距離まで飛んで四散する事故を過去に踏んだため、これを
# 避けるためBattleScene._build_dragon_anim_player が合流時に位置トラックへ
# BattleScene._DRAGON_ANIM_POS_SCALE を掛けて単位を合わせている。この2つの値（.importの
# root_scaleとコードの_DRAGON_ANIM_POS_SCALE）は必ず一致していなければならず、ズレると
# 四散事故が再発する。

const _DRAGONS: Array[Dictionary] = [
	{"model": "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx",
	 "anim_dir": "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer", "clip_count": 18},
	{"model": "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_soul_eater.fbx",
	 "anim_dir": "res://assets/dungeon-mason-dragons/Animations/DragonSoulEater", "clip_count": 17},
	{"model": "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_nightmare.fbx",
	 "anim_dir": "res://assets/dungeon-mason-dragons/Animations/DragonNightMare", "clip_count": 16},
	{"model": "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_usurper.fbx",
	 "anim_dir": "res://assets/dungeon-mason-dragons/Animations/DragonUsurper", "clip_count": 18},
]
const _DRAGON := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
const _DRAGON_ANIM_DIR := "res://assets/dungeon-mason-dragons/Animations/DragonTerrorBringer"

# 本命：FBX元来のスキンは「形は正しく、一様に1/100スケール」であることを確認する。
# _DRAGON_SKIN_SCALE_FIX を掛けて1.0になれば、ノードスケールでの打ち消しが妥当。
# スキンを作り直すと形が壊れる（2026-07-19実測：形の破綻辺 1.3% → 17.1%）ので触らないこと。
# 例外ボーン（soul_eaterのTailEnd・usurperのWingThumb01_L/R）は元アセット側で二重に
# 0.01倍が乗っており、全体の1%未満なので許容する。増えたら元アセットの異常を疑う。
func test_dragon_original_skin_is_uniform_hundredth_scale() -> void:
	for d: Dictionary in _DRAGONS:
		var ch: Node3D = (load(d["model"] as String) as PackedScene).instantiate()
		add_child_autofree(ch)
		var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
		var mi: MeshInstance3D = ch.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := mi.skin
		var name_ := (d["model"] as String).get_file()
		assert_gt(skin.get_bind_count(), 0, "%s はスキンを持つ" % name_)
		var outliers: Array[String] = []
		for i: int in range(skin.get_bind_count()):
			var bone_idx := skin.get_bind_bone(i)
			if bone_idx == -1:
				bone_idx = sk.find_bone(skin.get_bind_name(i))
			assert_true(bone_idx != -1, "%s のbind %d がボーンに解決できる" % [name_, i])
			if bone_idx == -1:
				continue
			var m: Transform3D = sk.get_bone_global_pose(bone_idx) * skin.get_bind_pose(i)
			var s: float = m.basis.get_scale().x * BattleScene._DRAGON_SKIN_SCALE_FIX
			if absf(s - 1.0) > 0.02:
				outliers.append("%s(%.4f)" % [sk.get_bone_name(bone_idx), s])
		assert_lt(float(outliers.size()) / float(skin.get_bind_count()), 0.05,
			"%s : 元来バインド×%d倍で等倍にならないボーンは全体の5%%未満 %s" %
			[name_, int(BattleScene._DRAGON_SKIN_SCALE_FIX), outliers])

func test_dragon_clip_names_lists_fbx_clips() -> void:
	var clips := BattleScene.dragon_clip_names(_DRAGON_ANIM_DIR)
	assert_gt(clips.size(), 10, "TerrorBringerは18本前後のクリップを持つ")
	for expected: String in ["idle01", "FlyIdle", "die", "Basic Attack"]:
		assert_true(clips.has(expected), "基本クリップ %s がある" % expected)

func test_dragon_clip_names_empty_for_non_dragon() -> void:
	assert_eq(BattleScene.dragon_clip_names("res://assets/enemy_candidates/unity/").size(), 0,
		"アニメフォルダを持たないパスは空＝従来の内蔵アニメ経路に落ちる（回帰なし）")
	assert_eq(BattleScene.dragon_clip_names("").size(), 0)

func test_dragon_anim_player_is_findable_and_holds_clips() -> void:
	var ch: Node3D = (load(_DRAGON) as PackedScene).instantiate()
	add_child_autofree(ch)
	var ap := BattleScene._build_dragon_anim_player(ch, _DRAGON_ANIM_DIR)
	assert_not_null(ap, "AnimationPlayerが組み立てられる")
	assert_not_null(ch.find_child("AnimationPlayer", true, false),
		"find_child(\"AnimationPlayer\")で見つかる名前が付いている（2026-07-05既知の罠）")
	assert_true(ap.has_animation("idle01"), "クリップ名はFBXのファイル名（Take 001ではない）")
	assert_true(ap.has_animation("FlyIdle"))

func test_dragon_anim_player_null_when_anim_dir_empty() -> void:
	var ch: Node3D = (load(_DRAGON) as PackedScene).instantiate()
	add_child_autofree(ch)
	assert_null(BattleScene._build_dragon_anim_player(ch, ""),
		"anim_dirが空＝アニメ合流しない候補（静止GLB等）はnullを返す")

func test_dragon_clip_counts_match_per_dragon() -> void:
	for d: Dictionary in _DRAGONS:
		var clips := BattleScene.dragon_clip_names(d["anim_dir"] as String)
		assert_eq(clips.size(), d["clip_count"] as int,
			"%s のクリップ数が期待どおり" % (d["model"] as String).get_file())

func test_dragon_clip_names_have_no_slash() -> void:
	# add_animation_library("", lib) で改名済み＝"idle01" のはずで "idle01/idle01" 等の
	# 二重ライブラリ名衝突が起きていないことの検知
	for d: Dictionary in _DRAGONS:
		for clip: String in BattleScene.dragon_clip_names(d["anim_dir"] as String):
			assert_false(clip.contains("/"), "クリップ名にライブラリ区切りが残っていない: %s" % clip)

func test_dragon_anim_tracks_resolve_to_actual_bones() -> void:
	# 本命：GLB/FBXのボーン名29/83不一致で棘状に破裂した事故の再発検知。
	# 全アニメの全トラックが、実際に読み込んだSkeleton3Dのボーン名と一致することを確認する
	var checked_tracks: int = 0
	for d: Dictionary in _DRAGONS:
		var ch: Node3D = (load(d["model"] as String) as PackedScene).instantiate()
		add_child_autofree(ch)
		var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
		assert_not_null(sk, "%s にスケルトンがある" % (d["model"] as String).get_file())
		var ap := BattleScene._build_dragon_anim_player(ch, d["anim_dir"] as String)
		for clip: String in ap.get_animation_list():
			var a := ap.get_animation(clip)
			for i: int in range(a.get_track_count()):
				var bone: String = a.track_get_path(i).get_concatenated_subnames()
				if bone.is_empty():
					continue
				checked_tracks += 1
				assert_true(sk.find_bone(bone) != -1,
					"%s / %s の トラック %d が指すボーン '%s' がSkeleton3Dに実在する" %
					[(d["model"] as String).get_file(), clip, i, bone])
	assert_gt(checked_tracks, 400, "4体分・十分な数のトラックを検査した（検査漏れの誤検知防止）")

func test_dragon_animation_actually_moves_bones() -> void:
	for d: Dictionary in _DRAGONS:
		var ch: Node3D = (load(d["model"] as String) as PackedScene).instantiate()
		add_child_autofree(ch)
		var ap := BattleScene._build_dragon_anim_player(ch, d["anim_dir"] as String)
		var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
		var clips: PackedStringArray = ap.get_animation_list()
		# 全クリップは重いので代表3本だけ動きを確認する（ボーン実在チェックは別テストで全網羅済み）
		for j: int in range(min(3, clips.size())):
			var clip: String = clips[j]
			var before: Array = []
			for b: int in range(sk.get_bone_count()):
				before.append(sk.get_bone_pose_rotation(b))
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * 0.5, true, true)
			var moved: int = 0
			for b: int in range(sk.get_bone_count()):
				if not sk.get_bone_pose_rotation(b).is_equal_approx(before[b]):
					moved += 1
			ap.stop()
			assert_gt(moved, 0,
				"%s / %s の再生でボーン姿勢が変わる＝トラックがスケルトンに解決している" %
				[(d["model"] as String).get_file(), clip])

func test_dragon_texture_is_applied() -> void:
	for d: Dictionary in _DRAGONS:
		var ch: Node3D = (load(d["model"] as String) as PackedScene).instantiate()
		add_child_autofree(ch)
		BattleScene._apply_dragon_texture(ch, d["model"] as String)
		var found: Array = ch.find_children("*", "MeshInstance3D", true, false)
		assert_false(found.is_empty(), "メッシュが見つかる: %s" % (d["model"] as String).get_file())
		var mi := found[0] as MeshInstance3D
		var mat := mi.get_surface_override_material(0) as BaseMaterial3D
		assert_not_null(mat, "テクスチャ適用でマテリアルのオーバーライドが入る: %s" % (d["model"] as String).get_file())
		assert_not_null(mat.albedo_texture, "albedo_textureが設定されている（元FBXは空のはず）")

func test_dragon_mesh_import_root_scale_matches_anim_pos_scale() -> void:
	# 本命：.importのroot_scale（メッシュのrest姿勢を焼く比率）と
	# BattleScene._DRAGON_ANIM_POS_SCALE（合流するアニメの位置トラックを縮める比率）は
	# 必ず一致していなければならない。ズレるとRootボーンが実際の距離の何倍も飛んで
	# 全身が視界外に四散する（2026-07-19に実際に踏んだ事故の回帰検知）
	for d: Dictionary in _DRAGONS:
		var cfg := ConfigFile.new()
		var model_path: String = d["model"] as String
		var err := cfg.load(model_path + ".import")
		assert_eq(err, OK, "%s の.importが読める" % model_path.get_file())
		if err != OK:
			continue
		var root_scale: float = cfg.get_value("params", "nodes/root_scale", 1.0)
		assert_almost_eq(root_scale, BattleScene._DRAGON_ANIM_POS_SCALE, 0.0001,
			"%s の.importのroot_scaleとBattleScene._DRAGON_ANIM_POS_SCALEが一致する（ズレると四散する）" %
			model_path.get_file())

func test_dragon_bone_poses_stay_near_rest_after_animating() -> void:
	# 四散事故が起きるとRootが数十〜数百単位も飛び、全ボーンの姿勢がrestから大きく乖離する。
	# 通常のidle/歩行アニメでは体の中心付近のボーンはrestから大きく動かないはずなので、
	# 「rest→posedの移動量が異常に大きいボーンがいない」ことを機械的に確認する
	for d: Dictionary in _DRAGONS:
		var ch: Node3D = (load(d["model"] as String) as PackedScene).instantiate()
		add_child_autofree(ch)
		var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := BattleScene._build_dragon_anim_player(ch, d["anim_dir"] as String)
		var idle_clip := "idle01" if ap.has_animation("idle01") else ap.get_animation_list()[0]
		var rest_positions: Array = []
		for b: int in range(sk.get_bone_count()):
			rest_positions.append(sk.get_bone_rest(b).origin)
		ap.play(idle_clip)
		ap.seek(ap.get_animation(idle_clip).length * 0.5, true, true)
		var max_delta := 0.0
		for b: int in range(sk.get_bone_count()):
			var delta: float = (rest_positions[b] as Vector3).distance_to(sk.get_bone_pose(b).origin)
			max_delta = maxf(max_delta, delta)
		# メッシュのrest姿勢は原点付近（Root rest位置が概ね0.02〜0.03単位）に焼かれているため、
		# 四散していれば移動量は数十単位に跳ね上がる。1.0単位あれば十分な安全マージン
		assert_lt(max_delta, 1.0,
			"%s / %s 再生後もボーン姿勢がrestから大きく乖離していない（四散していない）" %
			[(d["model"] as String).get_file(), idle_clip])

func test_dragon_anim_position_tracks_are_scaled_down() -> void:
	# _build_dragon_anim_playerが合流時に位置トラックへBattleScene._DRAGON_ANIM_POS_SCALEを
	# 掛けていることを、生のアニメFBXの値と比較して直接確認する
	var src_scene: PackedScene = load(_DRAGON_ANIM_DIR + "/idle01.fbx")
	var src: Node3D = src_scene.instantiate()
	add_child_autofree(src)
	var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var raw_anim := src_ap.get_animation(src_ap.get_animation_list()[0])
	var raw_root_track := -1
	for i: int in range(raw_anim.get_track_count()):
		if raw_anim.track_get_type(i) == Animation.TYPE_POSITION_3D and \
				raw_anim.track_get_path(i).get_concatenated_subnames() == "Root":
			raw_root_track = i
			break
	assert_true(raw_root_track != -1, "生アニメFBXにRootの位置トラックがある")
	var raw_key0: Vector3 = raw_anim.track_get_key_value(raw_root_track, 0)

	var ch: Node3D = (load(_DRAGON) as PackedScene).instantiate()
	add_child_autofree(ch)
	var ap := BattleScene._build_dragon_anim_player(ch, _DRAGON_ANIM_DIR)
	var merged_anim := ap.get_animation("idle01")
	var merged_root_track := -1
	for i: int in range(merged_anim.get_track_count()):
		if merged_anim.track_get_type(i) == Animation.TYPE_POSITION_3D and \
				merged_anim.track_get_path(i).get_concatenated_subnames() == "Root":
			merged_root_track = i
			break
	assert_true(merged_root_track != -1, "合流後のアニメにもRootの位置トラックがある")
	var merged_key0: Vector3 = merged_anim.track_get_key_value(merged_root_track, 0)

	assert_almost_eq(merged_key0.y, raw_key0.y * BattleScene._DRAGON_ANIM_POS_SCALE, 0.0001,
		"合流後の位置トラック値は生の値に_DRAGON_ANIM_POS_SCALEを掛けたもの")
