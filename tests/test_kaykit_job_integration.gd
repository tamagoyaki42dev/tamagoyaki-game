extends GutTest

# アーチャー/ヴァルキリー/巫女を KayKit モデル（Ranger/Rogue/Rogue_Hooded）へ差し替えた
# 配線の回帰テスト。モデルパス・アニメクリップ・武器パス・武器トランスフォーム・チントの
# 各テーブルが 3 職ぶん整合していることを検証する（実機の見た目調整とは別＝値の存在と対応の検査）。

const NEW_JOBS := [
	CharacterJob.Type.ARCHER,
	CharacterJob.Type.VALKYRIE,
	CharacterJob.Type.SHRINE_MAIDEN,
]

func test_new_jobs_use_kaykit_models() -> void:
	var expected := {
		CharacterJob.Type.ARCHER:        "Ranger.glb",
		CharacterJob.Type.VALKYRIE:      "Rogue.glb",
		CharacterJob.Type.SHRINE_MAIDEN: "Rogue_Hooded.glb",
	}
	for job: int in expected:
		var path: String = BattleScene._JOB_CHAR_PATHS[job]
		assert_true(path.begins_with(BattleScene._KAYKIT_CHAR_DIR),
			"%s は KayKit ディレクトリのモデルを使う" % CharacterJob.get_display_name(job))
		assert_true(path.ends_with(expected[job]),
			"%s → %s" % [CharacterJob.get_display_name(job), expected[job]])
		assert_true(ResourceLoader.exists(path),
			"%s のモデルが import 済みで存在する" % expected[job])

func test_new_jobs_have_kaykit_clips() -> void:
	for job: int in NEW_JOBS:
		assert_true(BattleScene._KAYKIT_CLIPS.has(job),
			"%s に _KAYKIT_CLIPS 定義がある" % CharacterJob.get_display_name(job))
		var clips: Dictionary = BattleScene._KAYKIT_CLIPS[job]
		for key: String in ["idle", "attack", "death"]:
			assert_true(clips.has(key) and not (clips[key] as String).is_empty(),
				"%s のクリップ %s が定義済み" % [CharacterJob.get_display_name(job), key])

func test_new_jobs_weapons_exist() -> void:
	var expected := {
		CharacterJob.Type.ARCHER:        "bow_A_withString.gltf",
		CharacterJob.Type.VALKYRIE:      "bow_B_withString.gltf",
		CharacterJob.Type.SHRINE_MAIDEN: "torch.gltf",
	}
	for job: int in expected:
		var path: String = BattleScene._WEAPON_PATHS[job]
		assert_true(path.ends_with(expected[job]),
			"%s の武器 → %s" % [CharacterJob.get_display_name(job), expected[job]])
		assert_true(ResourceLoader.exists(path),
			"%s の武器が import 済みで存在する" % expected[job])

func test_new_jobs_have_weapon_xform() -> void:
	for job: int in NEW_JOBS:
		assert_true(BattleScene._KAYKIT_WEAPON_XFORM.has(job),
			"%s に武器トランスフォーム上書きがある（剣用グローバル値と分離）" % CharacterJob.get_display_name(job))
		var xf: Dictionary = BattleScene._KAYKIT_WEAPON_XFORM[job]
		assert_true(xf.has("pos") and xf.has("rot_deg") and xf.has("scale"),
			"%s の武器トランスフォームに pos/rot_deg/scale が揃う" % CharacterJob.get_display_name(job))

func test_shrine_maiden_tinted_archer_not() -> void:
	assert_true(BattleScene._JOB_TINTS.has(CharacterJob.Type.SHRINE_MAIDEN),
		"巫女は赤紫チント対象")
	assert_false(BattleScene._JOB_TINTS.has(CharacterJob.Type.ARCHER),
		"アーチャーは固有モデル化したのでチント対象から外れている")

# 弓職・巫女はその場攻撃分類のまま（接近しない）を保証
func test_new_jobs_stay_ranged() -> void:
	for job: int in NEW_JOBS:
		assert_true(BattleScene._is_ranged_or_magic_job(job),
			"%s はその場攻撃（接近しない）" % CharacterJob.get_display_name(job))
