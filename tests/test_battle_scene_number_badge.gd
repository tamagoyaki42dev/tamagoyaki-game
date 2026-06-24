extends GutTest

# _spawn_number_badge が正しい text の Label3D を生成する
func test_spawn_number_badge_generates_correct_text() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	add_child(ch)

	scene._spawn_number_badge(ch, 3)

	var found: Label3D = null
	for c: Node in ch.get_children():
		if c is Label3D:
			found = c as Label3D
			break
	assert_not_null(found, "Label3D が生成される")
	assert_eq(found.text, "3", "text が '3' である")

	ch.queue_free()
	scene.free()

# 1〜7 すべての番号が正しい text で生成される
func test_spawn_number_badge_all_numbers_1_to_7() -> void:
	var scene := BattleScene.new()
	for n: int in range(1, 8):
		var ch := Node3D.new()
		add_child(ch)
		scene._spawn_number_badge(ch, n)
		var lbl: Label3D = ch.get_child(0) as Label3D
		assert_not_null(lbl, "Label3D が生成される (n=%d)" % n)
		assert_eq(lbl.text, str(n), "text が '%d' である" % n)
		ch.queue_free()
	scene.free()

# 旧・名前ラベルメソッドが存在しない
func test_spawn_name_label_removed() -> void:
	var scene := BattleScene.new()
	assert_false(scene.has_method("_spawn_name_label"),
		"_spawn_name_label は削除されている")
	scene.free()
