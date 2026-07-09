extends GutTest

# 識別UI Phase 2：右パーティパネル再構成＋正面ポートレートの検証
#
# ⚠️ ポートレート PNG は tools/portrait_baker.tscn をエディタで F6 実行して
#    事前生成しておく必要がある。未生成だと存在系テストが落ちる。

const PORTRAIT_DIR := "res://assets/portraits/"

# ── スコープA：ベイク済みポートレート PNG の存在・ロード可否 ──

func test_all_portrait_pngs_exist_and_loadable() -> void:
	var paths: Array[String] = BattleScene.unique_player_model_paths()
	assert_eq(paths.size(), 14, "ユニークなプレイヤーモデルは14件（Kenney11＋KayKit3：剣闘士/騎士/魔女）")
	for model_path: String in paths:
		var stem: String = model_path.get_file().get_basename()
		var png: String = PORTRAIT_DIR + stem + ".png"
		assert_true(ResourceLoader.exists(png),
			"ポートレート PNG が存在する: %s" % png)
		if ResourceLoader.exists(png):
			assert_not_null(load(png) as Texture2D,
				"ポートレート PNG が load できる: %s" % png)

# ── スコープB：パネルエントリ生成の検証 ──

func _make_ui() -> BattleUI:
	var ui := BattleUI.new()
	add_child(ui)
	return ui

func test_panel_entry_shows_job_name_and_hp() -> void:
	var ui := _make_ui()
	var cd := CharacterData.from_job(CharacterJob.Type.WARRIOR)
	cd.char_name = "アレス"
	var unit := BattleUnit.from_character(cd, 0)
	ui._build_party_panel([unit])

	var job_lbl := ui._party_job_lbls[unit] as Label
	assert_true(job_lbl.text.contains(CharacterJob.get_display_name(CharacterJob.Type.WARRIOR)),
		"職名ラベルが unit の職（戦士）を含む")

	var hp_lbl := ui._party_hp_lbls[unit] as Label
	assert_eq(hp_lbl.text, "HP %d/%d" % [unit.hp, unit.hp_max],
		"HP数値ラベルが現在/最大と一致")

	ui.free()

func test_panel_portrait_texture_matches_job() -> void:
	var ui := _make_ui()
	var cd := CharacterData.from_job(CharacterJob.Type.WARRIOR)
	cd.char_name = "アレス"
	var unit := BattleUnit.from_character(cd, 0)
	ui._build_party_panel([unit])

	var portrait := ui._party_portraits[unit] as TextureRect
	assert_not_null(portrait, "ポートレート TextureRect が生成される")
	var ppath := BattleScene.portrait_path_for_job(CharacterJob.Type.WARRIOR)
	assert_true(ResourceLoader.exists(ppath),
		"職対応ポートレート PNG が存在する（未ベイクなら要 F6 実行）")
	if ResourceLoader.exists(ppath):
		assert_eq(portrait.texture, load(ppath),
			"ポートレート texture が職対応 PNG と一致")

	ui.free()

func test_panel_portrait_tint_for_shared_model_job() -> void:
	var ui := _make_ui()
	# MONK は male-b 共有のため _JOB_TINTS 対象
	var cd_tint := CharacterData.from_job(CharacterJob.Type.MONK)
	cd_tint.char_name = "リン"
	var u_tint := BattleUnit.from_character(cd_tint, 0)
	# WARRIOR は tint 対象外 → 白
	var cd_white := CharacterData.from_job(CharacterJob.Type.WARRIOR)
	cd_white.char_name = "アレス"
	var u_white := BattleUnit.from_character(cd_white, 1)
	ui._build_party_panel([u_tint, u_white])

	var p_tint := ui._party_portraits[u_tint] as TextureRect
	assert_eq(p_tint.modulate, BattleScene.job_tint_or_white(CharacterJob.Type.MONK),
		"tint 対象職のポートレート modulate が _JOB_TINTS 値と一致")

	var p_white := ui._party_portraits[u_white] as TextureRect
	assert_eq(p_white.modulate, Color.WHITE,
		"tint 対象外職のポートレート modulate は白")

	ui.free()

func test_panel_entry_has_no_position_or_row_label() -> void:
	var ui := _make_ui()
	var cd := CharacterData.from_job(CharacterJob.Type.KNIGHT)
	cd.char_name = "ガレス"
	var unit := BattleUnit.from_character(cd, 0)
	ui._build_party_panel([unit])

	var entry := ui._party_entries[unit] as Panel
	for child: Node in entry.get_children():
		if child is Label:
			var t: String = (child as Label).text
			assert_false(t.contains("位置"), "「位置」表示が存在しない: '%s'" % t)
			assert_false(t.contains("列"), "「列」表示が存在しない: '%s'" % t)

	ui.free()
