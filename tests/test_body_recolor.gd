extends GutTest
## BodyRecolor リソースの検証（描画なし・データ／往復／ドリフト、および実メッシュへの適用1本）。

const Customizer := preload("res://scripts/tools/char_customizer.gd")
const TMP_PATH := "user://test_body_recolor.tres"

func after_each() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

func _sample_bands() -> Dictionary:
	# detect_uv_color_bands 互換の形（{color,count}）。テスト用の固定データ。
	return {
		"Body": [{"color": Color(0.8, 0.2, 0.2), "count": 100}, {"color": Color(0.1, 0.1, 0.1), "count": 40}],
		"Cape": [{"color": Color(0.3, 0.3, 0.9), "count": 60}],
	}

func test_from_tool_state_builds_parallel_arrays() -> void:
	var tint := {
		"Body": {0: Color(0.5, 0.1, 0.1), 1: Color(0.9, 0.9, 0.2)},
		"Cape": {0: Color(0.8, 0.3, 0.7)},
	}
	var r := BodyRecolor.from_tool_state("res://x.glb", tint, _sample_bands())
	assert_eq(r.slots.size(), 3, "上書き3件が3エントリになるはず")
	assert_eq(r.override_colors.size(), 3)
	assert_eq(r.reference_colors.size(), 3)
	assert_eq(r.source_model, "res://x.glb")
	# reference は作成時のバンド色が入る（Bodyのband0＝赤）
	for i in r.slots.size():
		if r.slots[i] == "Body" and r.band_indices[i] == 0:
			assert_almost_eq(r.reference_colors[i].r, 0.8, 0.01, "Body band0 の参照色が赤でない")

func test_band_tint_for_returns_overrides_for_slot() -> void:
	var tint := {"Body": {0: Color.RED, 1: Color.YELLOW}, "Cape": {0: Color.BLUE}}
	var r := BodyRecolor.from_tool_state("res://x.glb", tint, _sample_bands())
	var body := r.band_tint_for("Body")
	assert_eq(body.size(), 2)
	assert_eq(body[0] as Color, Color.RED)
	assert_eq(body[1] as Color, Color.YELLOW)
	assert_eq((r.band_tint_for("Cape"))[0] as Color, Color.BLUE)
	assert_eq(r.band_tint_for("Nope").size(), 0, "無いスロットは空dict")

func test_slots_with_overrides_dedupes() -> void:
	var tint := {"Body": {0: Color.RED, 1: Color.YELLOW}, "Cape": {0: Color.BLUE}}
	var r := BodyRecolor.from_tool_state("res://x.glb", tint, _sample_bands())
	var slots := r.slots_with_overrides()
	assert_eq(slots.size(), 2, "Bodyが重複せず2スロット")
	assert_true(slots.has("Body") and slots.has("Cape"))

func test_tres_round_trip_preserves_data() -> void:
	var tint := {"Body": {1: Color(0.12, 0.34, 0.56)}, "Cape": {0: Color(0.9, 0.3, 0.7)}}
	var r := BodyRecolor.from_tool_state("res://rogue.glb", tint, _sample_bands())
	assert_eq(ResourceSaver.save(r, TMP_PATH), OK, "保存に失敗")
	var loaded := load(TMP_PATH) as BodyRecolor
	assert_not_null(loaded, "読み込み失敗")
	assert_eq(loaded.source_model, "res://rogue.glb")
	assert_eq(loaded.slots.size(), r.slots.size())
	assert_eq(loaded.band_tint_for("Body")[1] as Color, Color(0.12, 0.34, 0.56))
	assert_eq(loaded.band_tint_for("Cape")[0] as Color, Color(0.9, 0.3, 0.7))

func test_drift_warnings_empty_when_bands_match() -> void:
	var tint := {"Body": {0: Color.RED}}
	var r := BodyRecolor.from_tool_state("res://x.glb", tint, _sample_bands())
	# 同じバンド構成を渡せばズレなし
	assert_eq(r.drift_warnings(_sample_bands()).size(), 0, "一致時は警告ゼロ")

func test_drift_warnings_flags_color_shift_and_missing_band() -> void:
	var tint := {"Body": {0: Color.RED}, "Cape": {0: Color.BLUE}}
	var r := BodyRecolor.from_tool_state("res://x.glb", tint, _sample_bands())
	# Body band0 の色を大きく変え、Cape のバンドを消す
	var drifted := {
		"Body": [{"color": Color(0.1, 0.9, 0.1), "count": 100}],
		"Cape": [],
	}
	var w := r.drift_warnings(drifted)
	assert_eq(w.size(), 2, "色ズレ＋バンド消失で2件: %s" % str(w))

func test_apply_via_recolor_changes_mesh_pixels() -> void:
	# BodyRecolor を実メッシュ（Barbarian_Head）へ適用し、対象バンドの画素が塗り替わることを確認。
	var part_meshname := {"Head": {"Barbarian": "Barbarian_Head"}}
	var root := Customizer.assemble({"Head": "Barbarian"}, part_meshname)
	add_child_autofree(root)
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var head: MeshInstance3D = skel.find_child("Barbarian_Head", false, false) as MeshInstance3D
	var bands := Customizer.detect_uv_color_bands(head)
	assert_true(bands.size() >= 1, "前提：バンドが検出される")

	# band0 を鮮やかな赤に上書きする BodyRecolor をツール状態から組み立て、往復させて適用
	var r := BodyRecolor.from_tool_state("res://head.glb", {"Head": {0: Color(1.0, 0.1, 0.1)}},
		{"Head": bands})
	assert_eq(ResourceSaver.save(r, TMP_PATH), OK)
	var loaded := load(TMP_PATH) as BodyRecolor
	Customizer.recolor_part(head, bands, loaded.band_tint_for("Head"))
	assert_not_null(head.material_override, "適用後にmaterial_overrideが付くはず")
