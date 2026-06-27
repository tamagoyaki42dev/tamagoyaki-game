class_name GameState

# static var でシーン遷移をまたいで保持（class_name でグローバルアクセス可）
static var party_pool: Array = []
static var formation: Dictionary = {}   # Vector2i(row, col) → CharacterData
static var enemy_stat_type: int = 0    # _ready相当がないので ensure_init() で設定
static var battle_index: int = 0       # 現在の戦（0=B1, 1=B2, 2=B3）
static var bench_order: Array = []     # ベンチ追加順（新しいほど末尾）

static func ensure_init() -> void:
	if not party_pool.is_empty():
		return
	bench_order.clear()
	enemy_stat_type = EnemyData.StatType.TANK
	_init_default_party()

# ══ ロスター段階解禁（battle_index で絞り込む） ══
const B1_JOBS: Array = [
	CharacterJob.Type.WARRIOR, CharacterJob.Type.KNIGHT,   CharacterJob.Type.CLERIC,
	CharacterJob.Type.WITCH,   CharacterJob.Type.ARCHER,   CharacterJob.Type.MONK,
	CharacterJob.Type.ADVENTURER, CharacterJob.Type.ILLUSIONIST,
	CharacterJob.Type.VALKYRIE,   CharacterJob.Type.SHRINE_MAIDEN,
]
const B2_UNLOCK_JOBS: Array = [CharacterJob.Type.GLADIATOR, CharacterJob.Type.SAMURAI]
const B3_UNLOCK_JOBS: Array = [CharacterJob.Type.MAGE, CharacterJob.Type.SHAMAN, CharacterJob.Type.NINJA]

static func get_available_pool() -> Array:
	var unlocked: Array = B1_JOBS.duplicate()
	if battle_index >= 1:
		unlocked.append_array(B2_UNLOCK_JOBS)
	if battle_index >= 2:
		unlocked.append_array(B3_UNLOCK_JOBS)
	var result: Array = []
	for c: CharacterData in party_pool:
		if c.job in unlocked:
			result.append(c)
	return result

# ══ パーティ定義（ここを差し替えるだけで変更可） ══
static func _init_default_party() -> void:
	var roster := [
		# B1解禁（10職）
		["ガウェイン",       CharacterJob.Type.WARRIOR],
		["セバスティアン",   CharacterJob.Type.KNIGHT],
		["アリシア",         CharacterJob.Type.CLERIC],
		["エヴァンジェリン", CharacterJob.Type.WITCH],
		["ロビン",           CharacterJob.Type.ARCHER],
		["ゴラン",           CharacterJob.Type.MONK],
		["ルシア",           CharacterJob.Type.ADVENTURER],
		["セシリア",         CharacterJob.Type.ILLUSIONIST],
		["ヒルデ",           CharacterJob.Type.VALKYRIE],
		["ソフィア",         CharacterJob.Type.SHRINE_MAIDEN],
		# B2解禁（+2職）
		["マクシム",   CharacterJob.Type.GLADIATOR],
		["マサムネ",   CharacterJob.Type.SAMURAI],
		# B3解禁（+3職）
		["コルネリウス", CharacterJob.Type.MAGE],
		["ベリン",       CharacterJob.Type.SHAMAN],
		["シノ",         CharacterJob.Type.NINJA],
	]
	for entry in roster:
		var data := CharacterData.from_job(entry[1])
		data.char_name = entry[0]
		party_pool.append(data)
	_set_default_formation()

static func _find_by_job(job: CharacterJob.Type) -> CharacterData:
	for c: CharacterData in party_pool:
		if c.job == job:
			return c
	return null

static func _set_default_formation() -> void:
	formation.clear()
	# B1デフォルト編成（前3・中3・後1）
	formation[Vector2i(0, 0)] = _find_by_job(CharacterJob.Type.WARRIOR)
	formation[Vector2i(0, 1)] = _find_by_job(CharacterJob.Type.ARCHER)
	formation[Vector2i(0, 2)] = _find_by_job(CharacterJob.Type.MONK)
	formation[Vector2i(1, 0)] = _find_by_job(CharacterJob.Type.KNIGHT)
	formation[Vector2i(1, 1)] = _find_by_job(CharacterJob.Type.WITCH)
	formation[Vector2i(1, 2)] = _find_by_job(CharacterJob.Type.ADVENTURER)
	formation[Vector2i(2, 0)] = _find_by_job(CharacterJob.Type.CLERIC)

# ══ 編成操作 ══

static func get_at(pos: Vector2i) -> CharacterData:
	return formation.get(pos, null)

static func place(pos: Vector2i, char_data: CharacterData) -> void:
	_remove_from_grid(char_data)
	formation.erase(pos)
	formation[pos] = char_data
	bench_order.erase(char_data)

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
	if not bench_order.has(char_data):
		bench_order.append(char_data)

static func _remove_from_grid(char_data: CharacterData) -> void:
	for pos in formation.keys():
		if formation[pos] == char_data:
			formation.erase(pos)
			return

static func get_bench() -> Array:
	var placed := formation.values()
	var bench: Array = []
	for c: CharacterData in get_available_pool():
		if not (c in placed):
			bench.append(c)
	return bench

static func get_bench_ordered() -> Array:
	var bench := get_bench()
	var ordered: Array = []
	# bench_orderにないキャラ（初期メンバー・新解禁）を先に並べる
	for c in bench:
		if not bench_order.has(c):
			ordered.append(c)
	# グリッドから移動したキャラ（bench_order）を末尾に追加順で並べる
	for c in bench_order:
		if bench.has(c):
			ordered.append(c)
	return ordered

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

static func advance_battle() -> void:
	battle_index += 1

static func reset_to_current_battle() -> void:
	pass  # battle_index・編成はそのまま。負け時の「引き継ぎリトライ」用

static func get_battle_enemy() -> Array:
	match battle_index:
		0: return [EnemyGenerator.make_battle1()]
		1: return [EnemyGenerator.make_battle2()]
		2: return [EnemyGenerator.make_battle3()]
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
