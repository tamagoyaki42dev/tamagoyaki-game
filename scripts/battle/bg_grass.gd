class_name BackgroundGrass
extends Node3D

const _PLATFORM := preload("res://assets/kenney-nature-kit/Models/GLTF format/platform_grass.glb")

const _TREE_SCENES: Array = [
	preload("res://assets/kenney-nature-kit/Models/GLTF format/tree_default.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/tree_oak.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/tree_simple.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/tree_small.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/tree_tall.glb"),
]

const _DECO_SCENES: Array = [
	preload("res://assets/kenney-nature-kit/Models/GLTF format/rock_largeA.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/rock_largeB.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/rock_largeC.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/flower_redA.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/flower_yellowA.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/plant_bush.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/plant_bushLarge.glb"),
	preload("res://assets/kenney-nature-kit/Models/GLTF format/mushroom_red.glb"),
]

# [scene_idx, x, z, scale, rot_y_deg]  — カメラ全域に分散
const _TREES: Array = [
	# 奥列（z=-5〜-11）
	[0, -14.0,  -6.0, 2.2,   0.0],
	[4,  -5.0,  -9.0, 2.8,  20.0],
	[1,   2.0,  -7.0, 2.0,  50.0],
	[2,  10.0,  -9.0, 2.4, -30.0],
	[0,  18.0,  -5.0, 2.0,  10.0],
	[4, -10.0, -11.0, 3.0,  70.0],
	[1,   5.0, -11.0, 2.6, -15.0],
	[2,  15.0, -10.0, 2.2,  40.0],
	# 左縁（x=-15〜-19）
	[3, -17.0,   0.0, 1.8,  45.0],
	[0, -16.0,   5.0, 2.0, -20.0],
	[1, -18.0,  10.0, 2.3,  60.0],
	[4, -16.0,  15.0, 2.5,  30.0],
	# 右縁（x=19〜23）
	[2,  21.0,   1.0, 1.9, -40.0],
	[0,  20.0,   6.0, 2.1,  15.0],
	[3,  22.0,  11.0, 1.7, -60.0],
	[1,  21.0,  16.0, 2.4,  80.0],
	# 手前（z=14〜18、プレイヤー後方）
	[2,  -4.0,  17.0, 1.6, -10.0],
	[0,   8.0,  16.0, 1.8,  35.0],
	[3,  16.0,  17.0, 1.5, -25.0],
]

# [scene_idx, x, z, scale]
const _DECOS: Array = [
	# 岩
	[0, -15.0,  3.0, 1.3],
	[1,  21.0,  4.0, 1.1],
	[2,  -4.0, -4.0, 1.2],
	[0,  14.0, -3.0, 1.0],
	[1, -13.0, 13.0, 1.2],
	[2,  19.0, 12.0, 1.0],
	# 花
	[3,   2.0, -3.5, 0.9],
	[4,  10.0, -2.0, 0.9],
	[3,  -8.0,  4.0, 0.8],
	[4,   6.0, 15.0, 0.8],
	[3,  18.0,  8.0, 0.9],
	# 茂み
	[5, -12.0,  -1.0, 1.1],
	[6,  20.0,   9.0, 1.2],
	[5,  -2.0,  16.0, 1.0],
	[6,  12.0,  -4.0, 1.1],
	# キノコ
	[7,   4.0,   2.0, 0.9],
	[7, -10.0,   8.0, 0.8],
	[7,  16.0,   5.0, 1.0],
]

func _ready() -> void:
	_build_ground()
	_place_decorations()

func _build_ground() -> void:
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	base.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.38, 0.14)
	base.material_override = mat
	base.position = Vector3(3.0, -0.4, 2.0)
	add_child(base)

	# platform_grass タイルをサイン波でばらけさせて配置
	for row: int in range(6):
		for col: int in range(10):
			var bx := -16.0 + col * 4.0
			var bz := -4.0  + row * 4.0
			var off_x := sin(col * 2.7 + row * 1.3) * 1.2
			var off_z := cos(col * 1.9 + row * 3.1) * 1.2
			var rot   := sin(col * 3.1 + row * 2.7) * 55.0
			var tile: Node3D = _PLATFORM.instantiate()
			tile.position = Vector3(bx + off_x, 0.0, bz + off_z)
			tile.scale = Vector3(2.0, 1.0, 2.0)
			tile.rotation_degrees.y = rot
			add_child(tile)

func _place_decorations() -> void:
	for t: Array in _TREES:
		var node: Node3D = (_TREE_SCENES[t[0]] as PackedScene).instantiate()
		node.position = Vector3(t[1], 0.0, t[2])
		node.scale = Vector3.ONE * float(t[3])
		node.rotation_degrees.y = float(t[4])
		add_child(node)
	for d: Array in _DECOS:
		var node: Node3D = (_DECO_SCENES[d[0]] as PackedScene).instantiate()
		node.position = Vector3(d[1], 0.0, d[2])
		node.scale = Vector3.ONE * float(d[3])
		add_child(node)
