extends GutTest

func before_each() -> void:
	GameState.battle_index = 0
	GameState.formation.clear()

func test_initial_battle_index() -> void:
	assert_eq(GameState.battle_index, 0)

func test_advance_battle() -> void:
	GameState.advance_battle()
	assert_eq(GameState.battle_index, 1)

func test_advance_battle_twice() -> void:
	GameState.advance_battle()
	GameState.advance_battle()
	assert_eq(GameState.battle_index, 2)

func test_reset_to_current_battle_keeps_index() -> void:
	GameState.battle_index = 1
	GameState.reset_to_current_battle()
	assert_eq(GameState.battle_index, 1)

func test_get_battle_enemy_battle1() -> void:
	GameState.battle_index = 0
	var enemies := GameState.get_battle_enemy()
	assert_eq(enemies.size(), 1)
	var ed := enemies[0] as EnemyData
	assert_eq(ed.enemy_name, "マッシュナブ")

func test_get_battle_enemy_battle2() -> void:
	GameState.battle_index = 1
	var enemies := GameState.get_battle_enemy()
	assert_eq(enemies.size(), 1)
	var ed := enemies[0] as EnemyData
	assert_eq(ed.enemy_name, "トライバル")

func test_get_battle_enemy_battle3() -> void:
	GameState.battle_index = 2
	var enemies := GameState.get_battle_enemy()
	assert_eq(enemies.size(), 1)
	var ed := enemies[0] as EnemyData
	assert_eq(ed.enemy_name, "ドラゴン")

func test_rotate_formation_forward_moves_front_to_back() -> void:
	var a := CharacterData.new()
	var b := CharacterData.new()
	var c := CharacterData.new()
	GameState.formation = {
		Vector2i(0, 0): a,  # 前
		Vector2i(1, 0): b,  # 中
		Vector2i(2, 0): c,  # 後
	}
	GameState.rotate_formation(true)
	assert_eq(GameState.get_at(Vector2i(0, 0)), b, "中→前")
	assert_eq(GameState.get_at(Vector2i(1, 0)), c, "後→中")
	assert_eq(GameState.get_at(Vector2i(2, 0)), a, "前→後")

func test_rotate_formation_backward_is_inverse_of_forward() -> void:
	var a := CharacterData.new()
	var b := CharacterData.new()
	var c := CharacterData.new()
	GameState.formation = {
		Vector2i(0, 0): a,
		Vector2i(1, 0): b,
		Vector2i(2, 0): c,
	}
	GameState.rotate_formation(true)
	GameState.rotate_formation(false)
	assert_eq(GameState.get_at(Vector2i(0, 0)), a)
	assert_eq(GameState.get_at(Vector2i(1, 0)), b)
	assert_eq(GameState.get_at(Vector2i(2, 0)), c)

func test_rotate_formation_preserves_column() -> void:
	var a := CharacterData.new()
	GameState.formation = {Vector2i(0, 2): a}
	GameState.rotate_formation(true)
	assert_eq(GameState.get_at(Vector2i(2, 2)), a, "列(col)は変えず行(row)だけ回す")

func test_rotate_formation_handles_empty_slots() -> void:
	var a := CharacterData.new()
	GameState.formation = {Vector2i(0, 0): a}  # 中・後は空
	GameState.rotate_formation(true)
	assert_eq(GameState.formation.size(), 1, "空きマスは新規キーを生まない")
	assert_eq(GameState.get_at(Vector2i(2, 0)), a)

func test_place_allows_up_to_max_party() -> void:
	GameState.formation.clear()
	var positions: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2),
		Vector2i(2, 0),
	]
	for pos: Vector2i in positions:
		var ok := GameState.place(pos, CharacterData.new())
		assert_true(ok, "%s への配置は7人目まで成功するはず" % pos)
	assert_eq(GameState.formation.size(), GameState.MAX_PARTY)

func test_place_rejects_8th_member_into_empty_slot() -> void:
	GameState.formation.clear()
	for i in GameState.MAX_PARTY:
		GameState.formation[Vector2i(i % 3, i / 3)] = CharacterData.new()
	var eighth := CharacterData.new()
	var ok := GameState.place(Vector2i(2, 3), eighth)
	assert_false(ok, "7人埋まっている状態で新規キャラを空きマスに置くのは拒否されるはず")
	assert_eq(GameState.formation.size(), GameState.MAX_PARTY, "拒否時は人数が増えない")
	assert_false(GameState.is_in_formation(eighth))

func test_place_moves_existing_member_without_blocking_at_max_party() -> void:
	GameState.formation.clear()
	var members: Array[CharacterData] = []
	for i in GameState.MAX_PARTY:
		var c := CharacterData.new()
		members.append(c)
		GameState.formation[Vector2i(i % 3, i / 3)] = c
	# 満員でも「グリッド内の既存メンバーを別の空きマスへ移す」（人数は変わらない）は拒否されない
	var moved := members[0]
	var target_pos := Vector2i(2, 3)  # 空きマス
	var ok := GameState.place(target_pos, moved)
	assert_true(ok, "満員でも既存メンバーの再配置は人数を増やさないので通るはず")
	assert_eq(GameState.formation.size(), GameState.MAX_PARTY)
	assert_eq(GameState.get_at(target_pos), moved)
