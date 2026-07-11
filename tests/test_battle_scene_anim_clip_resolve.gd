extends GutTest

# _resolve_player_anim_clip の回帰テスト。
# 2026-07-11に実機フリーズを引き起こしたバグの再発防止：
# 弓職用に"release"kindを追加した際、Kenney組（_KAYKIT_CLIPS未登録）で
# 未知kindを渡すとmatchのdefaultが"idle"を返す実装だったため、
# 全Kenney組キャラの攻撃で「release用アニメが誤って"idle"と解決される」
# →攻撃アニメ再生中にidle（ループ）へ強制切り替え→
# 「anim_a.is_playingを待つ」whileループが無限ループしフリーズしていた。

func _make_player_unit(job: CharacterJob.Type) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.side = BattleUnit.Side.PLAYER
	var cd := CharacterData.new()
	cd.job = job
	unit.source_data = cd
	return unit

func test_kenney_job_release_kind_returns_empty() -> void:
	# 戦士(WARRIOR)はKenney組。"release"は未定義のkindなので空文字を返すべき
	# （"idle"を返すと _on_unit_acted 側で誤ってReleaseアニメ扱いされフリーズする）
	var unit := _make_player_unit(CharacterJob.Type.WARRIOR)
	assert_eq(BattleScene._resolve_player_anim_clip(unit, "release"), "",
		"Kenney組の未知kindは空文字（\"idle\"にフォールバックしてはいけない）")

func test_kenney_job_idle_still_resolves() -> void:
	var unit := _make_player_unit(CharacterJob.Type.WARRIOR)
	assert_eq(BattleScene._resolve_player_anim_clip(unit, "idle"), "idle",
		"Kenney組のidleは引き続き\"idle\"を返す")

func test_kenney_job_attack_and_death_unaffected() -> void:
	var unit := _make_player_unit(CharacterJob.Type.WARRIOR)
	assert_eq(BattleScene._resolve_player_anim_clip(unit, "attack"), "attack-melee-right",
		"Kenney組のattackは引き続き固定名を返す")
	assert_eq(BattleScene._resolve_player_anim_clip(unit, "death"), "die",
		"Kenney組のdeathは引き続き固定名を返す")

func test_kaykit_job_without_release_returns_empty() -> void:
	# 剣闘士はKayKit組だがreleaseクリップは持たない
	var unit := _make_player_unit(CharacterJob.Type.GLADIATOR)
	assert_eq(BattleScene._resolve_player_anim_clip(unit, "release"), "",
		"releaseを持たないKayKit職は空文字")

func test_bow_job_release_resolves_to_release_clip() -> void:
	var unit := _make_player_unit(CharacterJob.Type.ARCHER)
	assert_eq(BattleScene._resolve_player_anim_clip(unit, "release"), "ranged/Ranged_Bow_Release",
		"アーチャーのreleaseはRanged_Bow_Releaseを返す")
