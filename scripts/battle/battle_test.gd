## Godotエディタでこのスクリプトを空のNodeに貼って実行 → コンソールで戦闘ログ確認
extends Node

func _ready() -> void:
	var manager = BattleManager.new()
	add_child(manager)

	manager.battle_started.connect(_on_started)
	manager.turn_started.connect(_on_turn)
	manager.action_announced.connect(_on_action_announced)
	manager.unit_acted.connect(_on_acted)
	manager.unit_died.connect(_on_died)
	manager.rotated.connect(func(): print("  -- ローテーション --"))
	manager.battle_ended.connect(_on_ended)

	manager.start_battle(_make_party(), _make_enemies())

	# UIができるまではここで全ターン回す
	while not manager.is_over and manager.turn_number < 50:
		manager.advance_turn()

func _make_party() -> Array:
	var warrior = CharacterData.new()
	warrior.char_name = "アーサー"; warrior.job = CharacterJob.Type.WARRIOR
	warrior.hp_max = 35; warrior.attack = 20; warrior.speed = 15

	var samurai = CharacterData.new()
	samurai.char_name = "ライン"; samurai.job = CharacterJob.Type.SAMURAI
	samurai.hp_max = 28; samurai.attack = 24; samurai.speed = 28

	var archer = CharacterData.new()
	archer.char_name = "ルカ"; archer.job = CharacterJob.Type.ARCHER
	archer.hp_max = 24; archer.attack = 16; archer.speed = 12
	archer.indirect_attack = 12

	var knight = CharacterData.new()
	knight.char_name = "ガイ"; knight.job = CharacterJob.Type.KNIGHT
	knight.hp_max = 30; knight.attack = 12; knight.speed = 8
	knight.def_bonus = 12; knight.self_regen = 8

	var witch = CharacterData.new()
	witch.char_name = "リム"; witch.job = CharacterJob.Type.WITCH
	witch.hp_max = 22; witch.attack = 10; witch.speed = 16
	witch.atk_bonus = 14

	var mage = CharacterData.new()
	mage.char_name = "ソレン"; mage.job = CharacterJob.Type.MAGE
	mage.hp_max = 20; mage.attack = 8; mage.speed = 5
	mage.atk_bonus = 20; mage.def_bonus = 15; mage.row_regen = 10

	var cleric = CharacterData.new()
	cleric.char_name = "エレナ"; cleric.job = CharacterJob.Type.CLERIC
	cleric.hp_max = 18; cleric.attack = 8; cleric.speed = 6
	cleric.def_bonus = 20; cleric.row_regen = 15

	return [warrior, samurai, archer, knight, witch, mage, cleric]

func _make_enemies() -> Array:
	return [EnemyGenerator.generate(EnemyData.StatType.TANK)]

func _on_started(pg: RotationGrid, eg: RotationGrid) -> void:
	print("=== バトル開始 ===")
	print("味方: ", pg.get_all_alive().map(func(u: BattleUnit) -> String: return u.unit_name))
	print("敵:   ", eg.get_all_alive().map(func(u: BattleUnit) -> String: return u.unit_name))

func _on_turn(n: int, timeline: Array, enemy_action: String) -> void:
	var order = timeline.map(func(u: BattleUnit) -> String: return u.unit_name)
	print("\n[Turn %d] 行動順: %s" % [n, ", ".join(order)])
	if enemy_action != "":
		print("  敵の行動予告: " + enemy_action)

func _on_action_announced(action_name: String) -> void:
	print("  次ターン 敵: " + action_name)

func _on_acted(attacker: BattleUnit, target: BattleUnit, damage: int, is_crit: bool) -> void:
	var crit_str := " [CRIT]" if is_crit else ""
	print("  %s → %s: %d%s ダメージ (残HP %d/%d)" % [
		attacker.unit_name, target.unit_name, damage, crit_str, target.hp, target.hp_max
	])

func _on_died(unit: BattleUnit) -> void:
	print("  *** %s 戦死 ***" % unit.unit_name)

func _on_ended(player_won: bool, _loot: Array) -> void:
	print("\n=== %s ===" % ("勝利！" if player_won else "撤退..."))
