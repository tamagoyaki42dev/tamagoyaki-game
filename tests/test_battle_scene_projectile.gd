extends GutTest

# アーチャー/ヴァルキリー(矢)・巫女(光の玉)の飛翔体演出の回帰テスト。
# ヘッドレスでは飛翔の見た目は確認できないため、ここでは「設定テーブルの整合性」
# 「矢モデルが読み込める」「exportの初期値が妥当」の3点のみを検証する。
# 実際の飛び方・速度感・矢の向きは実機目視確認が必要（backlog参照）。

func test_projectile_kind_mapping() -> void:
	assert_eq(BattleScene._PROJECTILE_KIND[CharacterJob.Type.ARCHER], "arrow",
		"アーチャーは矢")
	assert_eq(BattleScene._PROJECTILE_KIND[CharacterJob.Type.VALKYRIE], "arrow",
		"ヴァルキリーは矢")
	assert_eq(BattleScene._PROJECTILE_KIND[CharacterJob.Type.SHRINE_MAIDEN], "orb",
		"巫女は光の玉")

func test_projectile_kind_excludes_instant_impact_jobs() -> void:
	# 魔術師/魔女等は従来どおり着弾即時のまま（今回スコープ外・要将来拡張）
	assert_false(BattleScene._PROJECTILE_KIND.has(CharacterJob.Type.MAGE),
		"魔術師は今回のスコープ外（インパクト遅延後に即時被弾のまま）")
	assert_false(BattleScene._PROJECTILE_KIND.has(CharacterJob.Type.WITCH),
		"魔女は今回のスコープ外（インパクト遅延後に即時被弾のまま）")

func test_arrow_model_exists_and_loadable() -> void:
	assert_true(ResourceLoader.exists(BattleScene._PROJECTILE_ARROW_PATH),
		"矢モデルが import 済みで存在する")
	assert_not_null(load(BattleScene._PROJECTILE_ARROW_PATH),
		"矢モデルが load できる")

func test_projectile_exports_have_sane_defaults() -> void:
	# BattleScene は _ready() でカメラ/グリッド/UI 一式(battle.tscn)を要求するため、
	# 他の battle_scene テストと同じ慣習でライブツリーへは実体化しない（export値の直接検査のみ）
	var scene := BattleScene.new()
	assert_true(scene.projectile_travel_time > 0.0,
		"飛翔時間は正の値")
	assert_true(scene.projectile_spawn_height > 0.0,
		"発射/着弾の高さは正の値（地面すれすれにならない）")
	assert_true(scene.projectile_orb_radius > 0.0,
		"光の玉の半径は正の値")
	assert_true(scene.projectile_orb_emission_energy > 0.0,
		"光の玉は発光する（emission_energyが正）")
	assert_true(scene.projectile_orb_glow_scale > 1.0,
		"グロー(にじみ)ビルボードは芯球より大きい")
	assert_true(scene.projectile_orb_glow_alpha > 0.0 and scene.projectile_orb_glow_alpha <= 1.0,
		"グローの不透明度は0〜1の範囲")
	scene.free()

func test_projectile_spawn_height_matches_hit_effect_height() -> void:
	# 飛翔体の着弾点は、既存の被弾エフェクト(火花/フラッシュ)の発生高さ(_SPARK_SPAWN_Y)と
	# 必ず一致させる。旧値1.0は当てずっぽうで0.3mズレており「敵の中心を向いていない」ように
	# 見えるバグの原因だった（ユーザー実機報告・2026-07-09）
	var scene := BattleScene.new()
	assert_almost_eq(scene.projectile_spawn_height, 0.7, 0.001,
		"着弾高さは_SPARK_SPAWN_Y(0.7)と一致")
	scene.free()

func test_orb_color_is_red_purple() -> void:
	# ユーザー指定（2026-07-09）：赤紫系。暖色(1.0,0.85,0.55)からの変更を固定する回帰テスト
	var scene := BattleScene.new()
	assert_true(scene.projectile_orb_color.r > scene.projectile_orb_color.g,
		"赤みが緑成分より強い")
	assert_true(scene.projectile_orb_color.b > scene.projectile_orb_color.g,
		"青み(紫成分)が緑成分より強い＝赤紫方向")
	scene.free()

func test_arrow_rot_offset_matches_measured_geometry() -> void:
	# arrow_A.gltf の全頂点AABB実測（ヘッドレス）で確定した値。当てずっぽうの90°では
	# 矢が進行方向の逆（後ろ向き）を向くバグをユーザーが実機で発見→180°が正解と判明
	var scene := BattleScene.new()
	assert_almost_eq(scene.projectile_arrow_rot_offset_deg, 180.0, 0.001,
		"矢モデルの前方はローカル+Z、look_at()はローカル-Zを目標へ向けるため180°反転が必要")
	scene.free()
