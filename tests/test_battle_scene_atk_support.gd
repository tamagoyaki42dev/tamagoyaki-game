extends GutTest

# _make_atk_support_label / _make_def_support_label は static func なので
# BattleScene をインスタンス化せずに呼べる

const _DEFAULT_OFFSET := Vector3(0.0, 1.8, 0.0)

func test_label_text() -> void:
	var lbl := BattleScene._make_atk_support_label(
		Vector3.ZERO, 48, 0.012, Color(1.0, 0.65, 0.1), _DEFAULT_OFFSET)
	assert_eq(lbl.text, "ATK Up", "テキストが 'ATK Up' である")
	lbl.free()

func test_label_is_label3d() -> void:
	var lbl := BattleScene._make_atk_support_label(
		Vector3.ZERO, 48, 0.012, Color(1.0, 0.65, 0.1), _DEFAULT_OFFSET)
	assert_is(lbl, Label3D, "Label3D 型である")
	lbl.free()

func test_label_font_size() -> void:
	var lbl := BattleScene._make_atk_support_label(
		Vector3.ZERO, 48, 0.012, Color(1.0, 0.65, 0.1), _DEFAULT_OFFSET)
	assert_eq(lbl.font_size, 48, "フォントサイズが 48 である")
	lbl.free()

func test_label_color() -> void:
	var color := Color(1.0, 0.65, 0.1)
	var lbl := BattleScene._make_atk_support_label(
		Vector3.ZERO, 48, 0.012, color, _DEFAULT_OFFSET)
	assert_eq(lbl.modulate, color, "オレンジ色が設定されている")
	lbl.free()

func test_label_position_offset() -> void:
	var base   := Vector3(1.0, 0.0, 2.0)
	var offset := Vector3(0.0, 1.8, 0.0)
	var lbl := BattleScene._make_atk_support_label(base, 48, 0.012, Color.WHITE, offset)
	assert_almost_eq(lbl.position.y, base.y + offset.y, 0.001, "Y オフセットが加算されている")
	lbl.free()

# ── 防御補助ラベル ────────────────────────────────────────────────

func test_def_label_text() -> void:
	var lbl := BattleScene._make_def_support_label(
		Vector3.ZERO, 48, 0.012, Color(0.3, 0.7, 1.0), _DEFAULT_OFFSET)
	assert_eq(lbl.text, "DEF Up", "テキストが 'DEF Up' である")
	lbl.free()

func test_def_label_is_label3d() -> void:
	var lbl := BattleScene._make_def_support_label(
		Vector3.ZERO, 48, 0.012, Color(0.3, 0.7, 1.0), _DEFAULT_OFFSET)
	assert_is(lbl, Label3D, "Label3D 型である")
	lbl.free()

func test_def_label_font_size() -> void:
	var lbl := BattleScene._make_def_support_label(
		Vector3.ZERO, 48, 0.012, Color(0.3, 0.7, 1.0), _DEFAULT_OFFSET)
	assert_eq(lbl.font_size, 48, "フォントサイズが 48 である")
	lbl.free()

func test_def_label_color() -> void:
	var color := Color(0.3, 0.7, 1.0)
	var lbl := BattleScene._make_def_support_label(
		Vector3.ZERO, 48, 0.012, color, _DEFAULT_OFFSET)
	assert_eq(lbl.modulate, color, "青色が設定されている")
	lbl.free()

func test_def_label_position_offset() -> void:
	var base   := Vector3(1.0, 0.0, 2.0)
	var offset := Vector3(0.0, 1.8, 0.0)
	var lbl := BattleScene._make_def_support_label(base, 48, 0.012, Color.WHITE, offset)
	assert_almost_eq(lbl.position.y, base.y + offset.y, 0.001, "Y オフセットが加算されている")
	lbl.free()
