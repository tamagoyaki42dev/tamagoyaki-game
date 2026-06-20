extends GutTest

# _make_heal_label は static func なので BattleScene をインスタンス化せずに呼べる

const DEFAULT_COLOR := Color(0.3, 1.0, 0.55)

func test_label_is_label3d() -> void:
	var lbl := BattleScene._make_heal_label(
		Vector3.ZERO, "+10", 48, 0.012, DEFAULT_COLOR)
	assert_is(lbl, Label3D, "Label3D 型である")
	lbl.free()

func test_label_text() -> void:
	var lbl := BattleScene._make_heal_label(
		Vector3.ZERO, "+10", 48, 0.012, DEFAULT_COLOR)
	assert_eq(lbl.text, "+10", "テキストが '+10' である")
	lbl.free()

func test_label_font_size() -> void:
	var lbl := BattleScene._make_heal_label(
		Vector3.ZERO, "+10", 48, 0.012, DEFAULT_COLOR)
	assert_eq(lbl.font_size, 48, "フォントサイズが 48 である")
	lbl.free()

func test_label_color() -> void:
	var lbl := BattleScene._make_heal_label(
		Vector3.ZERO, "+10", 48, 0.012, DEFAULT_COLOR)
	assert_eq(lbl.modulate, DEFAULT_COLOR, "緑色が設定されている")
	lbl.free()

func test_label_position_offset() -> void:
	var base := Vector3(1.0, 0.0, 2.0)
	var lbl  := BattleScene._make_heal_label(base, "+10", 48, 0.012, DEFAULT_COLOR)
	assert_almost_eq(lbl.position.y, base.y + 1.5, 0.001, "Y+1.5 オフセットが加算されている")
	lbl.free()
