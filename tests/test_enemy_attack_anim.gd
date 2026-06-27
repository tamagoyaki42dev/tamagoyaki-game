extends GutTest

# EnemyData.attack_anim フィールドと proto1 ファクトリの設定値を検証。
# await を含む実際のアニメ再生はテスト外 → 実機目視で確認すること。

func test_enemy_data_has_attack_anim_field() -> void:
	var e := EnemyData.new()
	assert_true(e.get("attack_anim") != null, "attack_anim フィールドが存在する")
	assert_eq(e.attack_anim, "", "デフォルトは空文字（突進フォールバック）")

func test_mushnub_has_bite_front() -> void:
	var e := EnemyGenerator.make_battle1()
	assert_eq(e.attack_anim, "Bite_Front", "マッシュナブは Bite_Front アニメを使う")

func test_tribal_has_no_attack_anim() -> void:
	var e := EnemyGenerator.make_battle2()
	assert_eq(e.attack_anim, "", "トライバルは attack_anim 空（Tween 突進フォールバック）")

func test_dragon_has_no_attack_anim() -> void:
	var e := EnemyGenerator.make_battle3()
	assert_eq(e.attack_anim, "", "ドラゴンは attack_anim 空（Tween 突進フォールバック）")

func test_battle_scene_has_lunge_exports() -> void:
	var scene := BattleScene.new()
	assert_true(scene.enemy_lunge_dist > 0.0, "enemy_lunge_dist が正の値")
	assert_true(scene.enemy_lunge_in_time > 0.0, "enemy_lunge_in_time が正の値")
	assert_true(scene.enemy_lunge_out_time > 0.0, "enemy_lunge_out_time が正の値")
