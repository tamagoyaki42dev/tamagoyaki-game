extends GutTest

# 表情プリセット（A2・docs/dev_tooling_design.md）の保存・読込インフラを検証する。
# tools/face_editor.gd には class_name が無いためスクリプトを直接 .new() する。
# .new() だけでは _ready()（_rebuild()）が走らないため _built=false のまま＝重いモデル構築を経由せず
# 保存/読込ロジックだけを検証できる（face_editor.gd の _live_update() は _built ガード付き）。
# 注意：tools/face_editor.tscn は他セッションのRogue作業中の状態が保存されたままのため、
# このテストでは絶対に .tscn を経由しない（スクリプト単体のみ扱う）。

const _FaceEditorScript := preload("res://tools/face_editor.gd")

func test_face_expression_round_trip_save_load() -> void:
	var expr := FaceExpression.new()
	expr.eye_squareness = 4.2
	expr.brow_tilt = 33.0
	expr.mouth_smile = 15.0
	expr.eye_color = Color(0.5, 0.1, 0.1)

	var path := "user://test_face_expression_roundtrip.tres"
	ResourceSaver.save(expr, path)
	var loaded: FaceExpression = load(path)

	assert_almost_eq(loaded.eye_squareness, 4.2, 0.001, "eye_squareness がラウンドトリップで一致する")
	assert_almost_eq(loaded.brow_tilt, 33.0, 0.001, "brow_tilt がラウンドトリップで一致する")
	assert_almost_eq(loaded.mouth_smile, 15.0, 0.001, "mouth_smile がラウンドトリップで一致する")
	assert_eq(loaded.eye_color, Color(0.5, 0.1, 0.1), "eye_color がラウンドトリップで一致する")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_save_preset_then_load_preset_on_new_instance_restores_values() -> void:
	# face_editor.gd は画面UI完結ツールへ移行済み（dev_tooling_design.md「エディタ往復ゼロ」）。
	# _save_preset(name)/_load_preset(path) はUI(LineEdit/OptionButton)非依存の関数のため、
	# .new() のみ（_ready()未実行＝重いモデル構築を経由しない）で直接呼び出して検証できる。
	var saver = _FaceEditorScript.new()
	saver.brow_tilt = 37.0
	saver.eye_squareness = 5.5
	saver.mouth_smile = 20.0
	saver._save_preset("_gut_test_expression")
	saver.free()

	var loader = _FaceEditorScript.new()
	loader._load_preset("res://assets/face_expressions/_gut_test_expression.tres")

	assert_almost_eq(loader.brow_tilt, 37.0, 0.001, "保存したbrow_tiltが別インスタンスで復元される")
	assert_almost_eq(loader.eye_squareness, 5.5, 0.001, "保存したeye_squarenessが別インスタンスで復元される")
	assert_almost_eq(loader.mouth_smile, 20.0, 0.001, "保存したmouth_smileが別インスタンスで復元される")
	loader.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/face_expressions/_gut_test_expression.tres"))

func test_save_preset_with_empty_name_warns_and_skips() -> void:
	var fe = _FaceEditorScript.new()
	# push_warningで中断するだけでエラーにならないことを確認（ファイルが作られない）
	fe._save_preset("")
	assert_false(FileAccess.file_exists("res://assets/face_expressions/.tres"),
		"空名では保存されない")
	fe.free()

func test_face_editor_builds_ui_without_error() -> void:
	# @tool廃止後の全面移行（画面UI完結）がヘッドレスで実際に組み上がることのsmoke test。
	var fe = _FaceEditorScript.new()
	add_child_autofree(fe)  # _ready()（_build_ui()+_rebuild()）を実行させる
	# CanvasLayerはGDScriptで動的生成した無名ノードのためクラス名一致で確認する
	var found_canvas_layer := false
	for c in fe.get_children():
		if c is CanvasLayer:
			found_canvas_layer = true
			break
	assert_true(found_canvas_layer, "画面UI用のCanvasLayerが子として存在する")
