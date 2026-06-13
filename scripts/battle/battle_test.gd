## Godotエディタでこのスクリプトを空のNodeに貼って実行 → コンソールで戦闘ログ確認
extends Node

func _ready() -> void:
	var manager = BattleManager.new()
	add_child(manager)

	manager.battle_started.connect(_on_started)
	manager.turn_started.connect(_on_turn)
	manager.unit_acted.connect(_on_acted)
	manager.unit_died.connect(_on_died)
	manager.rotated.connect(func(): print("  -- ローテーション --"))
	manager.battle_ended.connect(_on_ended)

	manager.start_battle(_make_party(), _make_enemies())

	# UIができるまではここで全ターン回す
	while not manager.is_over and manager.turn_number < 50:
		manager.advance_turn()

func _make_party() -> Array:
	var w = CharacterData.new()
	w.char_name = "アーサー"
	w.job       = CharacterJob.Type.WARRIOR
	w.hp_max    = 120; w.attack = 15; w.defense = 8; w.speed = 8

	var c = CharacterData.new()
	c.char_name = "エレナ"
	c.job       = CharacterJob.Type.CLERIC
	c.hp_max    = 80;  c.attack = 6;  c.defense = 5; c.speed = 7

	var s = CharacterData.new()
	s.char_name = "リム"
	s.job       = CharacterJob.Type.SCOUT
	s.hp_max    = 70;  s.attack = 12; s.defense = 3; s.speed = 14

	return [w, c, s]

func _make_enemies() -> Array:
	return [
		EnemyGenerator.generate(1),
		EnemyGenerator.generate(1),
		EnemyGenerator.generate(1, 1.0),  # 確定極振り
	]

func _on_started(pg: RotationGrid, eg: RotationGrid) -> void:
	print("=== バトル開始 ===")
	print("味方: ", pg.get_all_alive().map(func(u: BattleUnit) -> String: return u.unit_name))
	print("敵:   ", eg.get_all_alive().map(func(u: BattleUnit) -> String: return u.unit_name))

func _on_turn(n: int, timeline: Array) -> void:
	var order = timeline.map(func(u: BattleUnit) -> String: return u.unit_name)
	print("\n[Turn %d] 行動順: %s" % [n, ", ".join(order)])

func _on_acted(attacker: BattleUnit, target: BattleUnit, damage: int) -> void:
	print("  %s → %s: %d ダメージ (残HP %d/%d)" % [
		attacker.unit_name, target.unit_name, damage, target.hp, target.hp_max
	])

func _on_died(unit: BattleUnit) -> void:
	print("  *** %s 戦死 ***" % unit.unit_name)

func _on_ended(player_won: bool, _loot: Array) -> void:
	print("\n=== %s ===" % ("勝利！" if player_won else "全滅..."))
