extends GutTest

# _resolve_hit_flash_color は static func なので BattleScene インスタンス不要

const MELEE  := Color(1.0, 0.15, 0.15)
const MAGIC  := Color(0.7, 0.15, 1.0)
const RANGED := Color(1.0, 0.85, 0.10)

func _make_player_unit(job: CharacterJob.Type) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.side = BattleUnit.Side.PLAYER
	var cd := CharacterData.new()
	cd.job = job
	unit.source_data = cd
	return unit

func _make_enemy_unit() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.side = BattleUnit.Side.ENEMY
	return unit

func test_warrior_melee_red() -> void:
	var unit := _make_player_unit(CharacterJob.Type.WARRIOR)
	assert_eq(BattleScene._resolve_hit_flash_color(unit, MELEE, MAGIC, RANGED), MELEE,
		"戦士は赤フラッシュ")

func test_archer_ranged_yellow() -> void:
	var unit := _make_player_unit(CharacterJob.Type.ARCHER)
	assert_eq(BattleScene._resolve_hit_flash_color(unit, MELEE, MAGIC, RANGED), RANGED,
		"アーチャーは黄フラッシュ")

func test_valkyrie_ranged_yellow() -> void:
	var unit := _make_player_unit(CharacterJob.Type.VALKYRIE)
	assert_eq(BattleScene._resolve_hit_flash_color(unit, MELEE, MAGIC, RANGED), RANGED,
		"ヴァルキリーは黄フラッシュ")

func test_mage_magic_purple() -> void:
	var unit := _make_player_unit(CharacterJob.Type.MAGE)
	assert_eq(BattleScene._resolve_hit_flash_color(unit, MELEE, MAGIC, RANGED), MAGIC,
		"魔術師は紫フラッシュ")

func test_witch_magic_purple() -> void:
	var unit := _make_player_unit(CharacterJob.Type.WITCH)
	assert_eq(BattleScene._resolve_hit_flash_color(unit, MELEE, MAGIC, RANGED), MAGIC,
		"魔女は紫フラッシュ")

func test_enemy_always_red() -> void:
	var unit := _make_enemy_unit()
	assert_eq(BattleScene._resolve_hit_flash_color(unit, MELEE, MAGIC, RANGED), MELEE,
		"敵は常に赤フラッシュ")
