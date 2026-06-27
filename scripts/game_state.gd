class_name GameState

# static var でシーン遷移をまたいで保持（class_name でグローバルアクセス可）
static var party_pool: Array = []
static var formation: Dictionary = {}   # Vector2i(row, col) → CharacterData
static var enemy_stat_type: int = 0    # _ready相当がないので ensure_init() で設定

static func ensure_init() -> void:
	if not party_pool.is_empty():
		return
	enemy_stat_type = EnemyData.StatType.TANK
	_init_default_party()

# ══ パーティ定義（ここを差し替えるだけで変更可） ══
static func _init_default_party() -> void:
	var roster := [
		["アーサー", CharacterJob.Type.WARRIOR],
		["ライン",   CharacterJob.Type.SAMURAI],
		["ルカ",     CharacterJob.Type.ARCHER],
		["ガイ",     CharacterJob.Type.KNIGHT],
		["リム",     CharacterJob.Type.WITCH],
		["ソレン",   CharacterJob.Type.MAGE],
		["エレナ",   CharacterJob.Type.CLERIC],
	]
	for entry in roster:
		var data := CharacterData.from_job(entry[1])
		data.char_name = entry[0]
		party_pool.append(data)
	_set_default_formation()

static func _set_default_formation() -> void:
	formation.clear()
	formation[Vector2i(0, 0)] = party_pool[0]  # 前列
	formation[Vector2i(0, 1)] = party_pool[1]
	formation[Vector2i(0, 2)] = party_pool[2]
	formation[Vector2i(1, 0)] = party_pool[3]  # 中列
	formation[Vector2i(1, 1)] = party_pool[4]
	formation[Vector2i(1, 2)] = party_pool[5]
	formation[Vector2i(2, 0)] = party_pool[6]  # 後列

# ══ 編成操作 ══

static func get_at(pos: Vector2i) -> CharacterData:
	return formation.get(pos, null)

static func place(pos: Vector2i, char_data: CharacterData) -> void:
	_remove_from_grid(char_data)
	formation.erase(pos)
	formation[pos] = char_data

static func swap(pos_a: Vector2i, pos_b: Vector2i) -> void:
	var a := get_at(pos_a)
	var b := get_at(pos_b)
	formation.erase(pos_a)
	formation.erase(pos_b)
	if a:
		formation[pos_b] = a
	if b:
		formation[pos_a] = b

static func remove_from_grid(char_data: CharacterData) -> void:
	_remove_from_grid(char_data)

static func _remove_from_grid(char_data: CharacterData) -> void:
	for pos in formation.keys():
		if formation[pos] == char_data:
			formation.erase(pos)
			return

static func get_bench() -> Array:
	var placed := formation.values()
	var bench: Array = []
	for c in party_pool:
		if not (c in placed):
			bench.append(c)
	return bench

static func is_in_formation(char_data: CharacterData) -> bool:
	return char_data in formation.values()

# ══ 戦闘用データ ══

static func get_battle_entries() -> Array:
	var result: Array = []
	for pos in formation:
		var data = formation[pos]
		if data:
			result.append({"data": data, "row": (pos as Vector2i).x, "col": (pos as Vector2i).y})
	return result

static func get_battle_enemy() -> Array:
	# TODO: 3戦ゲームループ実装時に battle_index で切り替える
	return [EnemyGenerator.make_battle1()]

# ══ 敵タイプ切り替え ══

static func next_enemy_type() -> void:
	enemy_stat_type = (enemy_stat_type + 1) % EnemyData.StatType.keys().size()

static func prev_enemy_type() -> void:
	enemy_stat_type = (enemy_stat_type - 1 + EnemyData.StatType.keys().size()) % EnemyData.StatType.keys().size()

static func enemy_type_name() -> String:
	match enemy_stat_type:
		EnemyData.StatType.BALANCE:          return "バランス"
		EnemyData.StatType.BERSERKER:        return "バーサーカー"
		EnemyData.StatType.SPEED_STAR:       return "スピードスター"
		EnemyData.StatType.TANK:             return "タンク"
		EnemyData.StatType.ENHANCED_BALANCE: return "強化バランス"
	return "不明"
