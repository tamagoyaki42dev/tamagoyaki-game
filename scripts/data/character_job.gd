class_name CharacterJob

enum Type {
	WARRIOR,  # 前列特化・物理火力
	CLERIC,   # 後列・回復担当
	SUPPORT,  # 中列・補助担当
	SCOUT,    # 速度特化・前列
}

static func get_display_name(type: Type) -> String:
	match type:
		Type.WARRIOR: return "戦士"
		Type.CLERIC:  return "聖職者"
		Type.SUPPORT: return "補佐"
		Type.SCOUT:   return "斥候"
	return "不明"

# 各ジョブが最もパフォーマンスを発揮する行（0=前列, 1=中列, 2=後列）
static func preferred_row(type: Type) -> int:
	match type:
		Type.WARRIOR: return 0
		Type.CLERIC:  return 2
		Type.SUPPORT: return 1
		Type.SCOUT:   return 0
	return 0
