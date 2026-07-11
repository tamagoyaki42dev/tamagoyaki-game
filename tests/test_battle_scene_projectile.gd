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

func test_bow_jobs_have_release_clip() -> void:
	# 旧実装はDrawのみ再生してReleaseを一切使わないまま矢を発射しており、
	# 「引いている最中に矢が飛ぶ」ズレの原因だった（ユーザー実機報告・2026-07-11）
	var archer_clips: Dictionary = BattleScene._KAYKIT_CLIPS[CharacterJob.Type.ARCHER]
	var valkyrie_clips: Dictionary = BattleScene._KAYKIT_CLIPS[CharacterJob.Type.VALKYRIE]
	assert_eq(archer_clips.get("release", ""), "ranged/Ranged_Bow_Release",
		"アーチャーはRelease（弦を離す）クリップを持つ")
	assert_eq(valkyrie_clips.get("release", ""), "ranged/Ranged_Bow_Release",
		"ヴァルキリーはRelease（弦を離す）クリップを持つ")

func test_bow_release_delay_default() -> void:
	# Ranged_Bow_Release実測（角速度＝連続フレーム間の回転差）：最大角速度はクリップ冒頭
	# 0.02〜0.07s付近に集中＝弦を放つ瞬間。旧採用値0.35s（変位ピーク基準）は実機で
	# 「離す動作が終わるか終わらないかで矢が飛ぶ」違和感の原因だった（2026-07-11）
	var scene := BattleScene.new()
	assert_almost_eq(scene.bow_release_delay, 0.08, 0.001,
		"bow_release_delay のデフォルト値が0.08s（Release冒頭の初速ピークに同期）である")
	scene.free()

func test_bow_draw_hold_time_default() -> void:
	# Ranged_Bow_Draw実測：handslot.rが0.8s付近でfull draw姿勢に収束し以降は静止保持。
	# 旧実装はDrawの全長1.33sを律儀に待ってからReleaseへ切り替えており、
	# 「攻撃モーションが単純に長すぎる」の一因だった（2026-07-11）
	var scene := BattleScene.new()
	assert_almost_eq(scene.bow_draw_hold_time, 0.85, 0.001,
		"bow_draw_hold_time のデフォルト値が0.85s（Draw実測の収束点＋バッファ）である")
	scene.free()

func test_bow_release_tail_wait_default() -> void:
	# 旧実装はReleaseの全長1.33sが終わるまでidleへ切り替えず待っており冗長だった
	var scene := BattleScene.new()
	assert_almost_eq(scene.bow_release_tail_wait, 0.2, 0.001,
		"bow_release_tail_wait のデフォルト値が0.2s（被弾処理後の短い追い見せ）である")
	scene.free()
