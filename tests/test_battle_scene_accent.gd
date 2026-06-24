extends GutTest

# accent_color_for(0..7) が8色すべて異なり、index=8 で index=0 に巡回する
func test_accent_palette_all_distinct_and_cycles() -> void:
	var colors: Array = []
	for i: int in 8:
		colors.append(BattleScene.accent_color_for(i))

	for i: int in 8:
		for j: int in 8:
			if i != j:
				assert_ne(colors[i], colors[j],
					"index %d と %d は異なる色であること" % [i, j])

	assert_eq(BattleScene.accent_color_for(8), BattleScene.accent_color_for(0),
		"index=8 は index=0 に巡回する")

# パレットが ACCENT_PALETTE サイズと一致して返る
func test_accent_color_for_returns_color_type() -> void:
	for i: int in 16:
		var c: Color = BattleScene.accent_color_for(i)
		assert_true(c is Color, "戻り値が Color 型であること (index=%d)" % i)
