extends GutTest

# ──── calc_damage_multiplier ────

func test_normal_hit():
	var mult := BattleMath.calc_damage_multiplier(false, true, false, 0, 100, false)
	assert_eq(mult, 1.0)

func test_crit_applies_1_5x():
	var mult := BattleMath.calc_damage_multiplier(true, true, false, 0, 100, false)
	assert_eq(mult, 1.5)

func test_petrified_applies_1_5x():
	var mult := BattleMath.calc_damage_multiplier(false, true, false, 0, 100, true)
	assert_eq(mult, 1.5)

func test_crit_and_petrified_stack():
	# 1.5 * 1.5 = 2.25
	var mult := BattleMath.calc_damage_multiplier(true, true, false, 0, 100, true)
	assert_almost_eq(mult, 2.25, 0.001)

func test_charge_min_threshold():
	# charge_excess < 2 * hp_max → had_charge = false として呼ぶ（BattleManagerが判定）
	var mult := BattleMath.calc_damage_multiplier(false, true, false, 100, 100, false)
	assert_eq(mult, 1.0)

func test_charge_exact_2x():
	# charge_excess=200, hp_max=100 → cm = min(4.0, 300/100/2) = min(4.0, 1.5) = 1.5
	var mult := BattleMath.calc_damage_multiplier(false, true, true, 200, 100, false)
	assert_almost_eq(mult, 1.5, 0.001)

func test_charge_capped_at_4x():
	# charge_excess=800, hp_max=100 → cm = min(4.0, 900/100/2) = min(4.0, 4.5) = 4.0
	var mult := BattleMath.calc_damage_multiplier(false, true, true, 800, 100, false)
	assert_almost_eq(mult, 4.0, 0.001)

func test_charge_only_on_first_hit():
	# is_first=false → チャージ乗数は適用されない
	var mult := BattleMath.calc_damage_multiplier(false, false, true, 800, 100, false)
	assert_eq(mult, 1.0)

# ──── calc_raw_damage ────

func test_raw_damage_rounds_up():
	# base=10, mult=1.5 → ceili(15.0) = 15
	assert_eq(BattleMath.calc_raw_damage(10, 1.5), 15)

func test_raw_damage_fraction_rounds_up():
	# base=10, mult=1.25 → ceili(12.5) = 13
	assert_eq(BattleMath.calc_raw_damage(10, 1.25), 13)

# ──── calc_actual_damage ────

func test_actual_damage_no_defense():
	assert_eq(BattleMath.calc_actual_damage(10, 0), 10)

func test_actual_damage_with_defense():
	assert_eq(BattleMath.calc_actual_damage(10, 4), 6)

func test_actual_damage_never_negative():
	assert_eq(BattleMath.calc_actual_damage(5, 10), 0)

# ──── calc_absorb_heal ────

func test_absorb_50_percent_rounds_up():
	# actual=10 → ceili(5.0) = 5
	assert_eq(BattleMath.calc_absorb_heal(10), 5)

func test_absorb_odd_number_rounds_up():
	# actual=7 → ceili(3.5) = 4
	assert_eq(BattleMath.calc_absorb_heal(7), 4)

# ──── calc_healing ────

func test_normal_healing():
	var result := BattleMath.calc_healing(50, 100, 30)
	assert_eq(result["healed"], 30)
	assert_eq(result["overheal"], 0)

func test_healing_capped_at_max():
	var result := BattleMath.calc_healing(80, 100, 30)
	assert_eq(result["healed"], 20)
	assert_eq(result["overheal"], 10)

func test_healing_at_full_hp():
	var result := BattleMath.calc_healing(100, 100, 10)
	assert_eq(result["healed"], 0)
	assert_eq(result["overheal"], 10)
