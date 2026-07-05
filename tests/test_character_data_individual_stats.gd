extends GutTest

# ──── roll_individual_stats: ガードレール遵守 ────

func test_all_jobs_stay_within_guardrails():
	for type_int in CharacterData.BASE.keys():
		var type: CharacterJob.Type = type_int as CharacterJob.Type
		for trial in range(30):
			var result: Array = CharacterData.roll_individual_stats(type)
			for i in range(8):
				if result[i] > 0:
					assert_between(result[i], CharacterData.STAT_MIN[i], CharacterData.STAT_MAX[i])

func test_inactive_stats_stay_zero():
	# WARRIOR は iatk/ab/db/sr/rr が全てベース0
	for trial in range(30):
		var result: Array = CharacterData.roll_individual_stats(CharacterJob.Type.WARRIOR)
		assert_eq(result[3], 0)
		assert_eq(result[4], 0)
		assert_eq(result[5], 0)
		assert_eq(result[6], 0)
		assert_eq(result[7], 0)

# ──── roll_individual_stats: 総量保存（平均で職のベース総量に一致） ────

func test_average_weighted_total_conserves_base_score():
	for type_int in CharacterData.BASE.keys():
		var type: CharacterJob.Type = type_int as CharacterJob.Type
		var b: Array = CharacterData.BASE[type_int]
		var base_total := 0.0
		for i in range(8):
			base_total += b[i] * CharacterData.STAT_WEIGHTS[i]

		var trials := 500
		var sum_total := 0.0
		for trial in range(trials):
			var result: Array = CharacterData.roll_individual_stats(type)
			var weighted := 0.0
			for i in range(8):
				weighted += result[i] * CharacterData.STAT_WEIGHTS[i]
			sum_total += weighted
		var avg_total: float = sum_total / trials
		# 丸め誤差＋ガードレール clamp のドリフトを吸収する許容誤差
		assert_almost_eq(avg_total, base_total, 2.0)
