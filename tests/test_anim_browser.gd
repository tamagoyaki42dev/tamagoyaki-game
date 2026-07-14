extends GutTest
## KayKitアニメビューアの合流ロジック検証（描画なし・データのみ）

const AnimBrowser := preload("res://scripts/tools/anim_browser.gd")
const CHAR_GLB := "res://assets/kaykit/characters/Mannequin_Medium.glb"

var _root: Node3D
var _anim: AnimationPlayer

func before_each() -> void:
	var scn: PackedScene = load(CHAR_GLB)
	_root = scn.instantiate() as Node3D
	add_child_autofree(_root)
	_anim = AnimBrowser.build_merged_anim(_root)

func test_all_eight_categories_merged() -> void:
	for cat: String in AnimBrowser.ANIM_CATS:
		assert_true(_anim.has_animation_library(cat), "カテゴリ未合流: %s" % cat)

func test_total_clip_count_matches_probe() -> void:
	# ヘッドレス実測で139クリップ（T-Pose8個含む）
	assert_eq(_anim.get_animation_list().size(), 139,
		"合流クリップ総数が実測値と一致しない")

func test_playable_list_excludes_tpose() -> void:
	var clips := AnimBrowser.list_playable_clips(_anim)
	# 139 - T-Pose 8個 = 131
	assert_eq(clips.size(), 131, "再生可能クリップ数が想定外")
	for c: String in clips:
		assert_false(c.ends_with("/T-Pose"), "T-Poseが混入: %s" % c)

func test_known_clips_present() -> void:
	# 代表クリップが "Cat/Name" 形式で引けること
	for key: String in ["General/Idle_A", "CombatMelee/Melee_1H_Attack_Chop",
			"CombatRanged/Ranged_Bow_Release", "Simulation/Waving"]:
		assert_true(_anim.has_animation(key), "既知クリップが無い: %s" % key)
