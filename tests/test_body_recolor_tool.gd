extends GutTest
## 体リカラー・ツールのブート検証：シーンをツリーに載せて _ready〜_scan_slots が
## 実際に通り、Rogueの Body/Cape スロットとバンドが検出されることを確認する（描画なし）。
## UI構築（DevControlsのスライダー/チェック生成）・AnimBrowser合流もこの起動経路で走る。

const TOOL_SCENE := "res://scenes/body_recolor_tool.tscn"

func test_tool_boots_and_scans_rogue_slots() -> void:
	var scn: PackedScene = load(TOOL_SCENE)
	assert_not_null(scn, "ツールシーンが読めない")
	var tool_node: Node = scn.instantiate()
	add_child_autofree(tool_node)
	await wait_process_frames(2)  # _ready→_load_model→_scan_slots が回るのを待つ

	assert_true(tool_node._slot_order.has("Body"), "Bodyスロットが検出されない")
	assert_true(tool_node._slot_order.has("Cape"), "Capeスロット（マント）が検出されない")
	assert_gt((tool_node._bands["Cape"] as Array).size(), 0, "Capeのバンドが空")
	# キャラ本体とアニメが組み上がっている
	assert_true(is_instance_valid(tool_node._char_root), "キャラルートが生成されていない")
	assert_not_null(tool_node._anim, "AnimationPlayerが組まれていない")

func test_tool_applies_rogue_starter_recolor() -> void:
	# 生成済みスターター rogue_recolor.tres がツール上の実メッシュへ適用できる。
	var recolor := load("res://assets/kaykit/characters/recolors/rogue_recolor.tres") as BodyRecolor
	assert_not_null(recolor, "rogue_recolor.tres が読めない")
	var scn: PackedScene = load(TOOL_SCENE)
	var tool_node: Node = scn.instantiate()
	add_child_autofree(tool_node)
	await wait_process_frames(2)

	# Capeメッシュへ赤紫を適用 → material_override が付く
	var cape: MeshInstance3D = tool_node._slot_mesh.get("Cape")
	assert_not_null(cape, "Capeメッシュが取れない")
	var Customizer := load("res://scripts/tools/char_customizer.gd")
	Customizer.recolor_part(cape, tool_node._bands["Cape"], recolor.band_tint_for("Cape"))
	assert_not_null(cape.material_override, "リカラー適用後にoverrideが付くはず")
	# スターターはドリフト無しで作られている
	assert_eq(recolor.drift_warnings(tool_node._bands).size(), 0, "スターターにドリフト警告が出ている")

func test_height_slider_offsets_model() -> void:
	# 手動の高さスライダー（沈み補正の確実な手段）でモデルが上下することを確認。
	var scn: PackedScene = load(TOOL_SCENE)
	var tool_node: Node = scn.instantiate()
	add_child_autofree(tool_node)
	await wait_process_frames(2)
	tool_node.auto_ground = false  # 自動接地が上書きしないよう切る
	tool_node.char_y = 1.25
	tool_node._apply_y(1.25)
	assert_almost_eq(tool_node._char_root.position.y, 1.25, 0.001, "高さスライダーでモデルのyが動く")

func test_auto_ground_grounds_sunk_model() -> void:
	# 足元が沈んだ状態を作り、自動接地(ライブ計測)が数フレームでy=0付近へ寄せることを確認。
	var scn: PackedScene = load(TOOL_SCENE)
	var tool_node: Node = scn.instantiate()
	add_child_autofree(tool_node)
	await wait_process_frames(2)
	tool_node.auto_ground = false
	tool_node.char_y = -1.4                    # わざと沈める
	tool_node._char_root.position.y = -1.4
	assert_lt(tool_node._measure_min_y(), -0.5, "前提：沈んでいる")
	tool_node.auto_ground = true               # 自動接地ON→毎フレーム補正
	await wait_process_frames(4)
	assert_almost_eq(tool_node._measure_min_y(), 0.0, 0.1, "自動接地で足元がy=0付近へ")

func test_anim_dropdown_lists_many_clips() -> void:
	# アニメドロップダウンが仮の5個でなく全クリップ（多数）へ差し替わっている。
	var scn: PackedScene = load(TOOL_SCENE)
	var tool_node: Node = scn.instantiate()
	add_child_autofree(tool_node)
	await wait_process_frames(2)
	assert_gt(tool_node._all_clips.size(), 20, "全クリップが載っているはず（仮リスト5個から差し替え）")
