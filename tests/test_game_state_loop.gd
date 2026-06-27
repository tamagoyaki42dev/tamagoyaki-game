extends GutTest

func before_each() -> void:
	GameState.battle_index = 0

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
