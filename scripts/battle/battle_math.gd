class_name BattleMath

const CRIT_MULT: float = 1.5
const PETRIFIED_MULT: float = 1.5
const CHARGE_MULT_MAX: float = 4.0
const ABSORB_RATE: float = 0.5

# ──── ダメージ計算 ────

static func calc_damage_multiplier(
		is_crit: bool,
		is_first_hit: bool,
		had_charge: bool,
		charge_excess: int,
		hp_max: int,
		is_target_petrified: bool
) -> float:
	var mult := 1.0
	if is_crit:
		mult *= CRIT_MULT
	if is_first_hit and had_charge:
		var cm := minf(CHARGE_MULT_MAX, float(hp_max + charge_excess) / float(hp_max) / 2.0)
		mult *= cm
	if is_target_petrified:
		mult *= PETRIFIED_MULT
	return mult

static func calc_raw_damage(base_atk: int, mult: float) -> int:
	return ceili(float(base_atk) * mult)

static func calc_actual_damage(raw: int, def_support: int) -> int:
	return max(0, raw - def_support)

# 吸収量を返す（実ダメージの50%・切り上げ）
static func calc_absorb_heal(actual_damage: int) -> int:
	return ceili(float(actual_damage) * ABSORB_RATE)

# ──── 回復計算 ────

# 戻り値: { "healed": int, "overheal": int }
static func calc_healing(current_hp: int, hp_max: int, amount: int) -> Dictionary:
	var new_hp := mini(hp_max, current_hp + amount)
	var healed := new_hp - current_hp
	var overheal := amount - healed
	return {"healed": healed, "overheal": overheal}
