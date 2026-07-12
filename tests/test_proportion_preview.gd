extends GutTest

const ProportionPreview := preload("res://scripts/tools/proportion_preview.gd")

func test_find_bone_ci_matches_exact_case_insensitive() -> void:
	var skel := Skeleton3D.new()
	skel.add_bone("Hips")
	skel.add_bone("Head")
	skel.add_bone("Spine")
	var idx := ProportionPreview._find_bone_ci(skel, "head")
	assert_eq(idx, 1, "大文字小文字を無視して 'Head' ボーンのインデックスを見つける")
	skel.free()

func test_find_bone_ci_falls_back_to_substring() -> void:
	var skel := Skeleton3D.new()
	skel.add_bone("Hips")
	skel.add_bone("HeadTop_End")
	var idx := ProportionPreview._find_bone_ci(skel, "head")
	assert_eq(idx, 1, "完全一致が無ければ部分一致にフォールバックする")
	skel.free()

func test_find_bone_ci_returns_minus_one_when_not_found() -> void:
	var skel := Skeleton3D.new()
	skel.add_bone("Hips")
	skel.add_bone("Spine")
	var idx := ProportionPreview._find_bone_ci(skel, "head")
	assert_eq(idx, -1, "見つからない場合は -1 を返す")
	skel.free()
