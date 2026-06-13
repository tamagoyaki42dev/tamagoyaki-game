class_name CharacterJob

enum Type {
	WARRIOR,
	KNIGHT,
	GLADIATOR,
	ILLUSIONIST,
	ADVENTURER,
	MONK,
	CLERIC,
	MAGE,
	WITCH,
	ARCHER,
	VALKYRIE,
	SHAMAN,
	SHRINE_MAIDEN,
	SAMURAI,
	NINJA,
	DARK_KNIGHT,
	HOLY_KNIGHT,
}

static func get_display_name(type: Type) -> String:
	match type:
		Type.WARRIOR:       return "戦士"
		Type.KNIGHT:        return "騎士"
		Type.GLADIATOR:     return "剣闘士"
		Type.ILLUSIONIST:   return "幻術師"
		Type.ADVENTURER:    return "冒険者"
		Type.MONK:          return "僧侶"
		Type.CLERIC:        return "神官"
		Type.MAGE:          return "魔術師"
		Type.WITCH:         return "魔女"
		Type.ARCHER:        return "アーチャー"
		Type.VALKYRIE:      return "ヴァルキリー"
		Type.SHAMAN:        return "祈祷師"
		Type.SHRINE_MAIDEN: return "巫女"
		Type.SAMURAI:       return "サムライ"
		Type.NINJA:         return "ニンジャ"
		Type.DARK_KNIGHT:   return "魔騎士"
		Type.HOLY_KNIGHT:   return "聖騎士"
	return "不明"

static func is_female(type: Type) -> bool:
	match type:
		Type.CLERIC, Type.WITCH, Type.VALKYRIE, Type.SHRINE_MAIDEN, Type.NINJA, Type.HOLY_KNIGHT:
			return true
	return false

# デフォルト配置列（0=前列, 1=中列, 2=後列）
static func preferred_row(type: Type) -> int:
	match type:
		Type.KNIGHT, Type.MONK, Type.MAGE, Type.WITCH, Type.DARK_KNIGHT, Type.HOLY_KNIGHT:
			return 1
		Type.CLERIC:
			return 2
	return 0
