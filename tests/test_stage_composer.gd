extends GutTest

# 戦闘画面構築ツール（stage_composer・dev_tooling_design.md B1+A4・P1）。
# battle_scene に足した「実行中に背景/効果を組み直す」公開APIと背景種別の解決ロジック、
# および実ゲームへの回帰が無いこと（新exportの既定値）を検証する。
# 画面効果の"見た目"はGUTで守れないため、目視確認手順（devlog）が別途必要。

func test_background_variant_override_defaults_to_auto() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.background_variant_override, -1,
		"既定は-1（自動）＝実ゲームは従来通り battle_index から背景を決める（回帰なし）")
	scene.free()

func test_preview_mode_defaults_to_false() -> void:
	var scene := BattleScene.new()
	assert_false(scene.preview_mode,
		"既定false＝実ゲームは戦闘終了で従来通りシーン遷移する（回帰なし）")
	scene.free()

func test_resolve_bg_variant_honors_override() -> void:
	var scene := BattleScene.new()
	scene.background_variant_override = 0
	assert_eq(scene._resolve_bg_variant(), 0, "override>=0 は battle_index に依らず override を返す")
	scene.background_variant_override = 1
	assert_eq(scene._resolve_bg_variant(), 1)
	scene.free()

func test_resolve_bg_variant_auto_grass_for_early_battles() -> void:
	var saved: int = GameState.battle_index
	var scene := BattleScene.new()
	scene.background_variant_override = -1
	GameState.battle_index = 0
	assert_eq(scene._resolve_bg_variant(), 0, "battle_index<2 は草原(0)")
	GameState.battle_index = 1
	assert_eq(scene._resolve_bg_variant(), 0)
	scene.free()
	GameState.battle_index = saved

func test_resolve_bg_variant_auto_dungeon_follows_kaykit_toggle() -> void:
	var saved: int = GameState.battle_index
	var scene := BattleScene.new()
	scene.background_variant_override = -1
	GameState.battle_index = 2
	scene.dungeon_bg_use_kaykit = true
	assert_eq(scene._resolve_bg_variant(), 2, "ダンジョンでトグルON＝KayKit(2)")
	scene.dungeon_bg_use_kaykit = false
	assert_eq(scene._resolve_bg_variant(), 1, "ダンジョンでトグルOFF＝Kenney(1)")
	scene.free()
	GameState.battle_index = saved

func test_battle_scene_exposes_effect_toggle_api() -> void:
	var scene := BattleScene.new()
	for m: String in ["rebuild_background", "set_outline_enabled", "set_paper_enabled",
			"set_fog_enabled", "set_lut_enabled", "set_boil_enabled"]:
		assert_true(scene.has_method(m), "stage_composerが呼ぶ公開API %s が存在する" % m)
	scene.free()

func test_composer_scene_loads_with_expected_defaults() -> void:
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	assert_not_null(ps, "stage_composer.tscn がロードできる")
	var root := ps.instantiate()  # ツリーに入れない＝_ready()（戦闘生成）は走らせず既定値だけ見る
	assert_eq(root.bg_variant, 2, "既定背景＝ダンジョンKayKit(2)")
	assert_true(root.clay_enabled, "粘土ベースは既定ON")
	root.free()

# 画風プリセット（2026-07-16・dev_tooling_design.md「A/B画風プリセット」フェーズ1）

func test_composer_style_preset_defaults_to_current() -> void:
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	assert_eq(root.style_preset_idx, 2, "既定=現状（BattleScene.StylePreset.CURRENT）")
	root.free()

func test_composer_new_effect_toggles_default_off_matching_battle_scene() -> void:
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	for f: String in ["tilt_enabled", "glow_enabled", "shadow_soft_enabled", "msaa_enabled",
			"contact_shadow_enabled", "paint_tex_enabled", "kuwahara_enabled", "hull_outline_enabled"]:
		assert_false(bool(root.get(f)), "%s の既定はfalse（battle_sceneの現状既定と一致）" % f)
	root.free()

func test_composer_fine_tune_fields_match_battle_scene_defaults() -> void:
	# battle_sceneをツリーに入れず@exportの既定値をそのまま比較する（回帰なしの確認）
	var battle := BattleScene.new()
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	for f: String in ["clay_hatch_strength", "clay_rim_strength", "clay_light_softness",
			"clay_outline_thickness", "clay_outline_softness", "clay_grain_strength",
			"clay_posterize_levels", "tilt_sharp_band", "tilt_blur", "glow_intensity",
			"shadow_blur", "contact_shadow_radius", "contact_shadow_opacity",
			"lut_desaturate", "fog_density", "paint_tex_strength", "paint_tex_scale", "kuwahara_radius",
			"hull_outline_width", "shadow_distance"]:
		assert_almost_eq(float(root.get(f)), float(battle.get(f)), 0.001,
			"stage_composerの%s既定がbattle_sceneの@export既定と一致する" % f)
	battle.free()
	root.free()

func test_enemy_preview_path_defaults_to_empty() -> void:
	var scene := BattleScene.new()
	assert_eq(scene.enemy_preview_path, "",
		"既定は空文字＝実ゲームは従来通りEnemyData.model_pathで敵の見た目を決める（回帰なし）")
	assert_almost_eq(scene.enemy_preview_scale, 1.0, 0.001)
	scene.free()

func test_composer_enemy_preview_idx_defaults_to_none() -> void:
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	assert_eq(int(root.get("enemy_preview_idx")), 0, "既定は0（なし・通常の敵）")
	root.free()

# 敵モデル差し替えの表示倍率（2026-07-19・ドラゴン4種が画面に収まらない問題）

func test_composer_enemy_preview_arrays_are_index_parallel() -> void:
	# ラベル/パス/倍率/アニメフォルダはインデックス対応で引かれる（battle_sceneがpath・scale・
	# anim_dirを対で受け取る）ため件数がずれると別モデルの倍率/アニメが当たる／範囲外で落ちる
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	var consts: Dictionary = (root.get_script() as GDScript).get_script_constant_map()
	var labels: PackedStringArray = consts["_ENEMY_PREVIEW_LABELS"]
	var paths: PackedStringArray = consts["_ENEMY_PREVIEW_PATHS"]
	var scales: PackedFloat32Array = consts["_ENEMY_PREVIEW_SCALES"]
	var anim_dirs: PackedStringArray = consts["_ENEMY_PREVIEW_ANIM_DIRS"]
	assert_eq(paths.size(), labels.size(), "ラベルとパスの件数が一致する")
	assert_eq(scales.size(), labels.size(), "ラベルと倍率の件数が一致する")
	assert_eq(anim_dirs.size(), labels.size(), "ラベルとアニメフォルダの件数が一致する")
	root.free()

func test_composer_dragon_previews_are_scaled_down() -> void:
	# 静止GLB4種・アニメ入りFBX4種とも素のメッシュが大きすぎるため縮小する。
	# FBX版は.importのroot_scale=0.01でメッシュ側を焼いており、Node3D.scaleはGLB版と同程度の
	# 通常範囲で足りる（2026-07-19：Node.scaleを極小値にする方式はGPUスキニングが実機で
	# 描画されなくなる不具合を踏んだため廃止し、この通常範囲に戻した）。
	# それ以外の候補は素のまま(1.0)を保つ
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	var consts: Dictionary = (root.get_script() as GDScript).get_script_constant_map()
	var paths: PackedStringArray = consts["_ENEMY_PREVIEW_PATHS"]
	var scales: PackedFloat32Array = consts["_ENEMY_PREVIEW_SCALES"]
	var dragon_count: int = 0
	for i: int in range(paths.size()):
		var f := paths[i].get_file()
		if not (paths[i].contains("dungeon_mason") and f.begins_with("dragon_")):
			assert_almost_eq(scales[i], 1.0, 0.001,
				"ドラゴン以外は素のまま（従来の見え方から変えない）: %s" % f)
			continue
		dragon_count += 1
		assert_between(scales[i], 0.05, 0.5,
			"%s は縮小倍率を持つ（素のままだと画面外まで膨らむ）" % f)
	assert_eq(dragon_count, 8, "縮小対象＝静止GLB4種＋アニメ入りFBX4種")
	root.free()

func test_composer_enemy_preview_anim_dirs_exist_on_disk() -> void:
	# 罠：テクスチャのフォルダ名(Texture/DragonNightmare)とアニメのフォルダ名
	# (Animations/DragonNightMare)で綴りが違う（大文字M）。この手の誤記を機械的に検知する
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	var consts: Dictionary = (root.get_script() as GDScript).get_script_constant_map()
	var anim_dirs: PackedStringArray = consts["_ENEMY_PREVIEW_ANIM_DIRS"]
	var checked: int = 0
	for d: String in anim_dirs:
		if d.is_empty():
			continue
		checked += 1
		assert_true(DirAccess.dir_exists_absolute(d), "アニメフォルダが実在する: %s" % d)
	assert_eq(checked, 4, "アニメ入り候補は現在4体")
	root.free()

func test_composer_apply_style_preset_method_exists() -> void:
	var ps: PackedScene = load("res://scenes/stage_composer.tscn")
	var root := ps.instantiate()
	assert_true(root.has_method("_apply_style_preset"), "画風プリセットドロップダウンのハンドラが存在する")
	root.free()
