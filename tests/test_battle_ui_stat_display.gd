extends GutTest

# 識別UI Phase 2 拡張：ステータス行（攻ライン・持ちステータス）の書式検証
#
# - 攻ライン書式は静的ヘルパー BattleUI._build_atk_text() で直接検証
# - 持ちステータス書式は BattleUI._build_stat_items_text() で直接検証
# - UI レベルでは「連」「石」単独ラベルが存在しないことと攻ラインラベルの生成を確認

# ── 攻ライン書式 ──

func test_atk_text_normal() -> void:
	var unit := BattleUnit.new()
	unit.attack = 8
	unit.attack_hits = 1
	unit.is_stone_attack = false
	assert_eq(BattleUI._build_atk_text(unit), "攻 8", "通常: 攻 N")

func test_atk_text_multi_hit() -> void:
	var unit := BattleUnit.new()
	unit.attack = 6
	unit.attack_hits = 4
	unit.is_stone_attack = false
	assert_eq(BattleUI._build_atk_text(unit), "攻 6×4", "連撃: 攻 N×H")

func test_atk_text_stone() -> void:
	var unit := BattleUnit.new()
	unit.attack = 4
	unit.attack_hits = 1
	unit.is_stone_attack = true
	assert_eq(BattleUI._build_atk_text(unit), "攻 4 石", "石化攻撃: 末尾 石")

func test_atk_text_multi_hit_and_stone() -> void:
	var unit := BattleUnit.new()
	unit.attack = 5
	unit.attack_hits = 3
	unit.is_stone_attack = true
	assert_eq(BattleUI._build_atk_text(unit), "攻 5×3 石", "連撃+石化: 攻 N×H 石")

# ── 持ちステータス書式 ──

func test_stat_items_atk_bonus_not_row() -> void:
	var unit := BattleUnit.new()
	unit.atk_bonus = 3
	unit.atk_bonus_is_row = false
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("攻補 3"), "攻補 N を含む（非列タイプ）")
	assert_false(text.contains("攻補列"), "攻補列 は含まない")

func test_stat_items_atk_bonus_row() -> void:
	var unit := BattleUnit.new()
	unit.atk_bonus = 5
	unit.atk_bonus_is_row = true
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("攻補列 5"), "攻補列 N を含む（列タイプ）")

func test_stat_items_indirect_shown() -> void:
	var unit := BattleUnit.new()
	unit.indirect_attack = 12
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("間 12"), "間 N が出る")

func test_stat_items_def_bonus_shown() -> void:
	var unit := BattleUnit.new()
	unit.def_bonus = 10
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("防補 10"), "防補 N が出る")

func test_stat_items_self_regen_shown() -> void:
	var unit := BattleUnit.new()
	unit.self_regen = 6
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("自 6"), "自 N が出る")

func test_stat_items_row_regen_shown() -> void:
	var unit := BattleUnit.new()
	unit.row_regen = 8
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("列 8"), "列 N が出る")

func test_stat_items_all_zero_is_empty() -> void:
	var unit := BattleUnit.new()
	# BattleUnit デフォルト値は全 0
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_eq(text, "", "全値 0 のとき空文字")

func test_stat_items_zero_fields_absent() -> void:
	var unit := BattleUnit.new()
	unit.def_bonus = 4
	unit.self_regen = 0
	unit.row_regen = 0
	unit.indirect_attack = 0
	unit.atk_bonus = 0
	var text: String = BattleUI._build_stat_items_text(unit)
	assert_true(text.contains("防補 4"), "防補 が出る")
	assert_false(text.contains("自"), "自回復 0 → 出ない")
	assert_false(text.contains("列"), "列回復 0 → 出ない")
	assert_false(text.contains("間"), "間接 0 → 出ない")
	assert_false(text.contains("攻補"), "攻補 0 → 出ない")

# ── UIレベル：独立「連」「石」ラベルが存在しないこと ──

func _make_ui() -> BattleUI:
	var ui := BattleUI.new()
	add_child(ui)
	return ui

func _make_unit(atk: int, hits: int, stone: bool) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.attack = atk
	unit.attack_hits = hits
	unit.is_stone_attack = stone
	unit.hp = 20
	unit.hp_max = 20
	unit.speed = 10
	unit.unit_name = "テスト"
	return unit

func test_no_standalone_ren_label() -> void:
	var ui := _make_ui()
	var unit := _make_unit(6, 4, false)
	ui._build_party_panel([unit])
	var entry := ui._party_entries[unit] as Panel
	for child: Node in entry.get_children():
		if child is Label:
			var t: String = (child as Label).text.strip_edges()
			assert_false(t == "連", "「連」単独ラベルが存在しない（text='%s'）" % t)
	ui.free()

func test_no_standalone_ishi_label() -> void:
	var ui := _make_ui()
	var unit := _make_unit(4, 1, true)
	ui._build_party_panel([unit])
	var entry := ui._party_entries[unit] as Panel
	for child: Node in entry.get_children():
		if child is Label:
			var t: String = (child as Label).text.strip_edges()
			assert_false(t == "石", "「石」単独ラベルが存在しない（text='%s'）" % t)
	ui.free()

func test_stat_lbl_generated_and_begins_with_atk_text() -> void:
	var ui := _make_ui()
	var unit := _make_unit(12, 2, false)
	ui._build_party_panel([unit])
	assert_true(ui._party_stat_lbls.has(unit), "攻ラインラベルが辞書に登録される")
	var lbl := ui._party_stat_lbls[unit] as Label
	assert_not_null(lbl, "攻ラインラベルが null でない")
	var expected_prefix: String = BattleUI._build_atk_text(unit)
	assert_true(lbl.text.begins_with(expected_prefix),
		"ラベルテキストが攻テキストで始まる（expected='%s', got='%s'）" % [expected_prefix, lbl.text])
	ui.free()

func test_stat_lbl_fits_in_entry_with_7_units() -> void:
	var ui := _make_ui()
	var units: Array[BattleUnit] = []
	for _i: int in 7:
		units.append(_make_unit(8, 1, false))
	ui._build_party_panel(units)
	for unit: BattleUnit in units:
		var entry := ui._party_entries[unit] as Panel
		var stat_lbl := ui._party_stat_lbls[unit] as Label
		var font_size: int = stat_lbl.get_theme_font_size("font_size")
		assert_true(
			stat_lbl.position.y + float(font_size) <= entry.size.y,
			"攻ラインが7人でクリップされない: y=%f font=%d entry_h=%f" % [
				stat_lbl.position.y, float(font_size), entry.size.y
			]
		)
	ui.free()

# ステータスは HP数値の右に横並び（バーの縦帯に被らせない）。
# 過去、攻ラインをバー直下に置いて ProgressBar の最小高さに被った不具合の回帰防止。
func test_stat_lbl_on_hp_row_beside_hp() -> void:
	var ui := _make_ui()
	var unit := _make_unit(12, 2, false)
	ui._build_party_panel([unit])
	var stat_lbl := ui._party_stat_lbls[unit] as Label
	var hp_lbl := ui._party_hp_lbls[unit] as Label
	var bar := ui._party_bars[unit] as ProgressBar
	assert_eq(stat_lbl.position.y, hp_lbl.position.y,
		"ステータスは HP数値と同じ行（同 y）")
	assert_gt(stat_lbl.position.x, hp_lbl.position.x,
		"ステータスは HP数値の右に並ぶ（x が HP より大）")
	assert_lt(stat_lbl.position.y, bar.position.y,
		"ステータスはバーより上にある（バーの縦帯に被らない）")
	ui.free()

# 速・持ちステータスが HP行に統合表示されること。
func test_stat_lbl_includes_speed_and_held() -> void:
	var ui := _make_ui()
	var unit := _make_unit(10, 1, false)
	unit.def_bonus = 18
	ui._build_party_panel([unit])
	var stat_lbl := ui._party_stat_lbls[unit] as Label
	assert_true(stat_lbl.text.contains("速 %d" % unit.speed), "速が含まれる")
	assert_true(stat_lbl.text.contains("防補 18"), "持ちステータスが含まれる")
	ui.free()
