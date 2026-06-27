extends GutTest

# 識別UI Phase 4：unit_3d_hovered 受信で行背景が明滅するかを検証。

func _make_ui() -> BattleUI:
	var ui := BattleUI.new()
	add_child(ui)
	return ui

func _make_unit() -> BattleUnit:
	var cd := CharacterData.from_job(CharacterJob.Type.WARRIOR)
	cd.char_name = "アレス"
	return BattleUnit.from_character(cd, 0)

func test_3d_hover_true_brightens_row_bg() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])

	var st := ui._party_entry_styles[unit] as StyleBoxFlat
	assert_eq(st.bg_color, BattleUI.ENTRY_BG_COLOR, "初期は通常背景色")

	ui._on_unit_3d_hovered(unit, true)
	assert_eq(st.bg_color, BattleUI.ENTRY_BG_HOVER, "3D ホバーでパネル行が明るくなる")
	ui.free()

func test_3d_hover_false_restores_row_bg() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])

	ui._on_unit_3d_hovered(unit, true)
	ui._on_unit_3d_hovered(unit, false)

	var st := ui._party_entry_styles[unit] as StyleBoxFlat
	assert_eq(st.bg_color, BattleUI.ENTRY_BG_COLOR, "退場で通常背景色へ復帰")
	ui.free()

func test_unknown_unit_is_noop() -> void:
	var ui := _make_ui()
	# 登録のないユニットでもクラッシュしないこと
	ui._on_unit_3d_hovered(BattleUnit.new(), true)
	pass_test("未登録ユニットでも例外なく処理される")
	ui.free()

# unit_row_hovered シグナルは 3D ホバー経由では emit しない（3D→パネルは一方向）
func test_3d_hover_does_not_emit_unit_row_hovered() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])
	watch_signals(ui)

	ui._on_unit_3d_hovered(unit, true)

	assert_signal_not_emitted(ui, "unit_row_hovered", "3D ホバーは unit_row_hovered を emit しない")
	ui.free()
