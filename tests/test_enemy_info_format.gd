extends GutTest

# EnemyData.format_action_cycle / format_thought_type のユニットテスト

func test_format_action_cycle_normal_only() -> void:
	var cycle: Array[int] = [EnemyData.ActionType.NORMAL]
	assert_eq(EnemyData.format_action_cycle(cycle), "通常攻撃のみ")

func test_format_action_cycle_charge_pattern() -> void:
	var cycle: Array[int] = [
		EnemyData.ActionType.CHARGE,
		EnemyData.ActionType.NORMAL,
		EnemyData.ActionType.NORMAL,
		EnemyData.ActionType.NORMAL,
	]
	var result := EnemyData.format_action_cycle(cycle)
	assert_true(result.begins_with("力を溜める"), "溜めで始まる")
	assert_true(result.ends_with("（くり返し）"), "くり返し表記で終わる")

func test_format_thought_random() -> void:
	var ed := EnemyData.new()
	ed.thought_type = EnemyData.ThoughtType.RANDOM
	assert_true(ed.format_thought_type().begins_with("きまぐれ"))

func test_format_thought_strong_target() -> void:
	var ed := EnemyData.new()
	ed.thought_type = EnemyData.ThoughtType.STRONG_TARGET
	assert_true(ed.format_thought_type().begins_with("強者狙い"))

func test_format_thought_support_target() -> void:
	var ed := EnemyData.new()
	ed.thought_type = EnemyData.ThoughtType.SUPPORT_TARGET
	assert_true(ed.format_thought_type().begins_with("補助狙い"))

# 3体の実データで表示文字列が空でないことを確認
func test_battle1_enemy_formats() -> void:
	var ed := EnemyGenerator.make_battle1()
	assert_false(EnemyData.format_action_cycle(ed.action_cycle).is_empty())
	assert_false(ed.format_thought_type().is_empty())

func test_battle2_enemy_formats() -> void:
	var ed := EnemyGenerator.make_battle2()
	assert_false(EnemyData.format_action_cycle(ed.action_cycle).is_empty())
	assert_false(ed.format_thought_type().is_empty())

func test_battle3_enemy_formats() -> void:
	var ed := EnemyGenerator.make_battle3()
	assert_false(EnemyData.format_action_cycle(ed.action_cycle).is_empty())
	assert_false(ed.format_thought_type().is_empty())
