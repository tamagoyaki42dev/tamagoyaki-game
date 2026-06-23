extends GutTest

# /code-review 修正で追加した定数の値を検証する

func test_camera_shake_noise_speed_const() -> void:
	assert_almost_eq(BattleScene._CAMERA_SHAKE_NOISE_SPEED, 20.0, 0.001,
		"_CAMERA_SHAKE_NOISE_SPEED が 20.0 である")

func test_camera_shake_v_phase_const() -> void:
	assert_almost_eq(BattleScene._CAMERA_SHAKE_V_PHASE, 100.0, 0.001,
		"_CAMERA_SHAKE_V_PHASE が 100.0 である")

func test_spark_spawn_y_const() -> void:
	assert_almost_eq(BattleScene._SPARK_SPAWN_Y, 0.7, 0.001,
		"_SPARK_SPAWN_Y が 0.7 である")
