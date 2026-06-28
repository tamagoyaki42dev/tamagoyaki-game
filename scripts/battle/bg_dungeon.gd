class_name BackgroundDungeon
extends Node3D

const _FLOOR_PLAIN  := preload("res://assets/kenney-dungeon-kit/Models/GLB format/template-floor.glb")
const _FLOOR_DETAIL := preload("res://assets/kenney-dungeon-kit/Models/GLB format/template-floor-detail.glb")
const _FLOOR_DETLA  := preload("res://assets/kenney-dungeon-kit/Models/GLB format/template-floor-detail-a.glb")
const _PROP_DETAIL  := preload("res://assets/kenney-dungeon-kit/Models/GLB format/template-detail.glb")
const _WALL         := preload("res://assets/kenney-dungeon-kit/Models/GLB format/template-wall.glb")
const _CORNER       := preload("res://assets/kenney-dungeon-kit/Models/GLB format/template-corner.glb")

# 0=plain 1=floor-detail 2=floor-detail-a
const _TILE_PATTERN: Array = [
	[0, 0, 0, 0, 1, 0, 0, 2, 0, 0],
	[0, 2, 0, 1, 0, 0, 2, 0, 0, 1],
	[2, 0, 2, 0, 0, 1, 0, 0, 1, 0],
	[0, 1, 0, 0, 2, 0, 1, 0, 0, 0],
	[0, 0, 0, 2, 0, 1, 0, 1, 0, 0],
	[0, 0, 0, 0, 2, 0, 1, 0, 0, 0],
]

# [x, z, scale, rot_y_deg]  — 端+中央に分散
const _PROPS: Array = [
	# 元の8箇所（縁）
	[-13.0, -4.0, 1.3,   0.0],
	[ 19.0, -4.0, 1.3,   0.0],
	[-14.0,  6.0, 1.2,  90.0],
	[ 20.0,  6.0, 1.2,  90.0],
	[-15.0, 15.0, 1.2,   0.0],
	[ 21.0, 15.0, 1.2,   0.0],
	[ -5.0, -9.0, 1.1, 180.0],
	[ 13.0, -9.0, 1.1, 180.0],
	# 追加：フロア内に散在
	[  2.0,  -2.0, 1.0,  45.0],
	[ 10.0,  -2.0, 1.0, -45.0],
	[ -9.0,   3.0, 1.1, 135.0],
	[ 18.0,   2.0, 1.0,  90.0],
	[ -3.0,   8.0, 1.0, -90.0],
	[ 15.0,   9.0, 1.1,   0.0],
	[  6.0,  13.0, 1.0, 180.0],
	[-11.0,  13.0, 1.0,  60.0],
	[ 17.0,  14.0, 1.1, -60.0],
	[  4.0,   5.0, 0.9,  30.0],
]

# back wall at z=-12 — 壁＋コーナーで変化をつける
const _WALLS: Array = [
	[-16.0, -12.0,   0.0, false],
	[-12.0, -12.0,   0.0, false],
	[ -8.0, -12.0,   0.0, false],
	[ -4.0, -12.0,   0.0, false],
	[  0.0, -12.0,   0.0, false],
	[  4.0, -12.0,   0.0, false],
	[  8.0, -12.0,   0.0, false],
	[ 12.0, -12.0,   0.0, false],
	[ 16.0, -12.0,   0.0, false],
	[ 20.0, -12.0,   0.0, false],
	# コーナーをアクセントに
	[-16.0, -12.0,   0.0, true],
	[ 20.0, -12.0,  90.0, true],
]

func _ready() -> void:
	_build_ground()
	_place_props()
	_place_walls()

func _build_ground() -> void:
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	base.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.36, 0.22)
	base.material_override = mat
	base.position = Vector3(3.0, -0.1, 2.0)
	add_child(base)

	var tile_scenes: Array = [_FLOOR_PLAIN, _FLOOR_DETAIL, _FLOOR_DETLA]
	for row: int in range(6):
		for col: int in range(10):
			var type_idx: int = _TILE_PATTERN[row][col]
			var tile: Node3D = (tile_scenes[type_idx] as PackedScene).instantiate()
			# サイン波で少しばらけさせる
			var off_x := sin(col * 1.7 + row * 2.3) * 0.4
			var off_z := cos(col * 2.3 + row * 1.7) * 0.4
			tile.position = Vector3(-16.0 + col * 4.0 + off_x, 0.0, -4.0 + row * 4.0 + off_z)
			add_child(tile)

func _place_props() -> void:
	for p: Array in _PROPS:
		var node: Node3D = _PROP_DETAIL.instantiate()
		node.position = Vector3(p[0], 0.0, p[1])
		node.scale = Vector3.ONE * float(p[2])
		node.rotation_degrees.y = float(p[3])
		add_child(node)

func _place_walls() -> void:
	for w: Array in _WALLS:
		var is_corner: bool = w[3]
		var node: Node3D = (_CORNER if is_corner else _WALL).instantiate()
		node.position = Vector3(w[0], 0.0, w[1])
		node.rotation_degrees.y = float(w[2])
		add_child(node)
