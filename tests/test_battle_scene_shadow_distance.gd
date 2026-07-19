extends GutTest

# シャドウマップ解像度対策（2026-07-17・「影がマイクラ状にカクつく」修正）。固定アイソメ＋
# 狭いアリーナなので遠距離の影は不要＝directional_shadow_max_distanceを縮めて同じ解像度を
# 近くへ集中させる（shadow_blurのボケでごまかす方向は不採用）。実ゲームにも効かせるため
# @export既定として持ち、shadow_soft_enabledのON/OFFに関わらず常に_lightへ書き込む。
# 見た目（実際にジャギーが消えるか・フレームレート）はGUTで守れないため実機目視が別途必要。

func test_shadow_distance_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.shadow_distance, 20.0, 0.001,
		"shadow_distance の既定値（固定アイソメ+狭いアリーナに合わせた控えめな距離）")
	scene.free()

func test_shadow_distance_setter_api_exists() -> void:
	var scene := BattleScene.new()
	assert_true(scene.has_method("set_shadow_distance"), "stage_composerが呼ぶ公開APIが存在する")
	scene.free()

func test_shadow_distance_setter_safe_when_out_of_tree() -> void:
	var scene := BattleScene.new()
	scene.set_shadow_distance(12.5)
	assert_almost_eq(scene.shadow_distance, 12.5, 0.001, "@exportへの書き戻しはツリー未接続でも行われる")
	scene.free()

# ── set_shadow_distance：_light（onready）を手動差し替えして実際にdirectional_shadow_max_distance
# へ届くことを検証する（test_battle_scene_paint_texture.gdの_characters差し替えと同じ流儀）──

func test_set_shadow_distance_updates_light_directly() -> void:
	var scene := BattleScene.new()
	var light := DirectionalLight3D.new()
	add_child_autofree(light)
	scene._light = light

	scene.set_shadow_distance(35.0)

	assert_almost_eq(light.directional_shadow_max_distance, 35.0, 0.001,
		"directional_shadow_max_distanceがsetter経由で_lightへ届く")
	assert_almost_eq(scene.shadow_distance, 35.0, 0.001)
	scene.free()

func test_set_shadow_distance_safe_when_light_is_null() -> void:
	var scene := BattleScene.new()
	scene.set_shadow_distance(10.0)
	assert_almost_eq(scene.shadow_distance, 10.0, 0.001, "_light未接続でもクラッシュしない")
	scene.free()

# シャドウマップ解像度そのもの（2026-07-17・距離短縮だけでは不十分だったため追加投入）。
# project.godotの[rendering]で直接指定（デスクトップ/Web(.mobile)両方4096）。
# Web書き出しのperfに響くため、距離短縮とセットで様子見する前提の値

func test_directional_shadow_size_project_setting_is_4096() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"), 4096,
		"デスクトップ向けシャドウマップ解像度")

func test_directional_shadow_size_mobile_project_setting_is_4096() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size.mobile"), 4096,
		"Web書き出し向け（.mobile）も揃える")
