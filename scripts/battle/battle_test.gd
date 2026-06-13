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
	w.hp_max    = 35; w.attack = 20; w.speed = 15

	var e = CharacterData.new()
	e.char_name = "エレナ"
	e.job       = CharacterJob.Type.CLERIC
	e.hp_max    = 18; e.attack = 8; e.speed = 6
	e.def_bonus = 20; e.row_regen = 15

	var r = CharacterData.new()
	r.char_name = "リム"
	r.job       = CharacterJob.Type.WITCH
	r.hp_max    = 22; r.attack = 10; r.speed = 16
	r.atk_bonus = 14

	return [w, e, r]

func _make_enemies() -> Array:
	return [EnemyGenerator.generate()]

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
	print("\n=== %s ===" % ("勝利！" if player_won else "撤退..."))
