extends GutTest

# 識別UI Phase 3：パネル行ホバーで unit_row_hovered を発火し、行背景を明滅させる検証。
# 戦場リング側の強調は test_battle_scene_ring_hover.gd で検証する。

func _make_ui() -> BattleUI:
	var ui := BattleUI.new()
	add_child(ui)
	return ui

func _make_unit() -> BattleUnit:
	var cd := CharacterData.from_job(CharacterJob.Type.WARRIOR)
	cd.char_name = "アレス"
	return BattleUnit.from_character(cd, 0)

func test_mouse_entered_emits_hovered_true() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])
	watch_signals(ui)

	var entry := ui._party_entries[unit] as Panel
	entry.mouse_entered.emit()

	assert_signal_emitted(ui, "unit_row_hovered", "行に入ると発火")
	var params: Array = get_signal_parameters(ui, "unit_row_hovered")
	assert_eq(params[0], unit, "第1引数が当該 unit")
	assert_eq(params[1], true, "第2引数が true")
	ui.free()

func test_mouse_exited_emits_hovered_false() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])
	watch_signals(ui)

	var entry := ui._party_entries[unit] as Panel
	entry.mouse_exited.emit()

	assert_signal_emitted(ui, "unit_row_hovered", "行から出ると発火")
	var params: Array = get_signal_parameters(ui, "unit_row_hovered")
	assert_eq(params[0], unit, "第1引数が当該 unit")
	assert_eq(params[1], false, "第2引数が false")
	ui.free()

func test_entry_bg_brightens_on_hover_and_restores() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])

	var st := ui._party_entry_styles[unit] as StyleBoxFlat
	assert_eq(st.bg_color, BattleUI.ENTRY_BG_COLOR, "初期は通常背景色")

	var entry := ui._party_entries[unit] as Panel
	entry.mouse_entered.emit()
	assert_eq(st.bg_color, BattleUI.ENTRY_BG_HOVER, "ホバーで明るい背景色")

	entry.mouse_exited.emit()
	assert_eq(st.bg_color, BattleUI.ENTRY_BG_COLOR, "退出で通常背景色へ復帰")
	ui.free()

# 行全体を安定してホバーさせるため、子コントロールは mouse を奪わない（IGNORE）こと。
func test_child_controls_ignore_mouse() -> void:
	var ui := _make_ui()
	var unit := _make_unit()
	ui._build_party_panel([unit])

	var portrait := ui._party_portraits[unit] as TextureRect
	assert_eq(portrait.mouse_filter, Control.MOUSE_FILTER_IGNORE, "ポートレートは mouse IGNORE")
	var hp_lbl := ui._party_hp_lbls[unit] as Label
	assert_eq(hp_lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HPラベルは mouse IGNORE")
	var bar := ui._party_bars[unit] as ProgressBar
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HPバーは mouse IGNORE")
	ui.free()
