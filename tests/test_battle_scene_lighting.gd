extends GutTest

func test_ambient_energy_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.ambient_energy, 0.35, 0.001,
		"ambient_energy のデフォルト値が 0.35 である")
	scene.free()

func test_key_light_energy_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.key_light_energy, 1.3, 0.001,
		"key_light_energy のデフォルト値が 1.3 である")
	scene.free()

func test_key_light_from_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.key_light_from.x, 6.0, 0.001,
		"key_light_from.x のデフォルト値が 6.0 である")
	assert_almost_eq(scene.key_light_from.y, 7.0, 0.001,
		"key_light_from.y のデフォルト値が 7.0 である")
	assert_almost_eq(scene.key_light_from.z, 3.0, 0.001,
		"key_light_from.z のデフォルト値が 3.0 である")
	scene.free()

func test_fog_density_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.fog_density, 0.02, 0.001,
		"fog_density のデフォルト値が 0.02 である")
	scene.free()
