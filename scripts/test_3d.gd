extends Node3D

func _ready() -> void:
	# ── カメラ（アイソメトリック） ─────────────────────────
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	cam.look_at_from_position(Vector3(4, 4, 4), Vector3(0.0, 1.4, 0.0), Vector3.UP)
	add_child(cam)

	# ── 環境（背景色 + アンビエント） ────────────────────────
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	add_child(env_node)

	# ── ライト ──────────────────────────────────────────────
	var light := DirectionalLight3D.new()
	light.light_energy = 1.2
	light.look_at_from_position(Vector3(3, 6, 3), Vector3(0, 0, 0), Vector3.UP)
	add_child(light)

	# ── キャラクターメッシュ ────────────────────────────────
	var mesh_res = load("res://assets/obj/base2.obj")
	print("mesh_res: ", mesh_res)
	if mesh_res == null:
		push_error("base2.obj 読み込み失敗。Godotエディタで assets/obj/ を開いてインポートしてください")
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.position = Vector3(0, 1.4, 0)
		add_child(box)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	add_child(mi)
	print("OK: base2 loaded")
