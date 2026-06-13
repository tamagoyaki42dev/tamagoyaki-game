class_name EnemyData
extends Resource

@export var enemy_name: String = ""
@export var level: int = 1
@export var hp_max: int = 50
@export var attack: int = 8
@export var defense: int = 3
@export var speed: int = 8
@export var is_extreme: bool = false  # 極振り個体フラグ

# 完全情報開示用：戦闘前にUIへ渡す説明文
func get_label() -> String:
	if is_extreme:
		return "%s [極振り] Lv%d" % [enemy_name, level]
	return "%s Lv%d" % [enemy_name, level]
