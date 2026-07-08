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

func test_battle_scene_has_hit_knockback_exports() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.hit_knockback_dist, 0.25, 0.001,
		"被弾ノックバック距離。ジュース強化で0.12→0.25に増量（2026-07-08）")
	assert_true(scene.hit_knockback_out_time > 0.0, "hit_knockback_out_time が正の値")
	assert_true(scene.hit_knockback_return_time > 0.0, "hit_knockback_return_time が正の値")
	scene.free()

func test_battle_scene_hitstop_scales_with_damage() -> void:
	var scene := BattleScene.new()
	assert_true(scene.hitstop_dmg_ref > 0.0, "hitstop_dmg_ref が正の値")
	assert_true(scene.hitstop_dmg_min_mult < 1.0, "小ダメージ側はhitstop_durationより短くなる")
	assert_true(scene.hitstop_dmg_max_mult > 1.0, "大ダメージ側はhitstop_durationより長くなる")
	assert_true(scene.hitstop_dmg_min_mult < scene.hitstop_dmg_max_mult,
		"min_mult < max_mult（範囲が逆転していない）")
	scene.free()
