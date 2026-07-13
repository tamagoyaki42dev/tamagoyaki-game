class_name BackgroundDungeonKayKit
extends Node3D

# KayKit DungeonRemastered版のダンジョン背景（既存 bg_dungeon.gd はKenney版のまま保持し、
# battle_scene.gd 側の @export トグルでどちらを使うか切り替える＝いつでも戻せる）。
# 構造（グリッド配置＋壁列＋小道具散布）は bg_dungeon.gd と同じロジックを踏襲し、素材だけ差し替え。

const _FLOOR_PLAIN  := preload("res://assets/kaykit/environment/dungeon/floor_tile_large.gltf")
const _FLOOR_ROCKS  := preload("res://assets/kaykit/environment/dungeon/floor_tile_large_rocks.gltf")
const _FLOOR_DECO   := preload("res://assets/kaykit/environment/dungeon/floor_tile_small_decorated.gltf")
const _WALL         := preload("res://assets/kaykit/environment/dungeon/wall.gltf")
const _CORNER       := preload("res://assets/kaykit/environment/dungeon/wall_corner.gltf")

const _PROP_SCENES: Array = [
	preload("res://assets/kaykit/environment/dungeon/barrel_large.gltf"),
	preload("res://assets/kaykit/environment/dungeon/crates_stacked.gltf"),
	preload("res://assets/kaykit/environment/dungeon/chest.gltf"),
	preload("res://assets/kaykit/environment/dungeon/candle_triple.gltf"),
	preload("res://assets/kaykit/environment/dungeon/box_small.gltf"),
]

# tools/dungeon_kaykit_probe.gd で実測して確定（当てずっぽう禁止）。
# floor_tile_large / floor_tile_large_rocks の実寸(XZ)=4.0x4.0に合わせたグリッド間隔
const _TILE_SIZE: float = 4.0
# floor_tile_small_decoratedのみ実寸2.0x2.0（他タイルの半分）と実測判明→グリッドに合わせ2倍スケールで補正
const _FLOOR_DECO_SCALE: float = 2.0
# wall.gltfの実寸(X)=4.0に合わせた壁の並び間隔
const _WALL_SPACING: float = 4.0

# 0=plain 1=floor-rocks 2=floor-deco（bg_dungeon.gdと同じパターン配列を流用）
const _TILE_PATTERN: Array = [
	[0, 0, 0, 0, 1, 0, 0, 2, 0, 0],
	[0, 2, 0, 1, 0, 0, 2, 0, 0, 1],
	[2, 0, 2, 0, 0, 1, 0, 0, 1, 0],
	[0, 1, 0, 0, 2, 0, 1, 0, 0, 0],
	[0, 0, 0, 2, 0, 1, 0, 1, 0, 0],
	[0, 0, 0, 0, 2, 0, 1, 0, 0, 0],
]

# [scene_idx, x, z, scale, rot_y_deg]  — bg_dungeon.gdの_PROPS座標をそのまま流用しつつ種類を巡回で割当（単調な同一プロップ反復を解消）
const _PROPS: Array = [
	[0, -13.0, -4.0, 1.3,   0.0],
	[1,  19.0, -4.0, 1.3,   0.0],
	[2, -14.0,  6.0, 1.2,  90.0],
	[3,  20.0,  6.0, 1.2,  90.0],
	[4, -15.0, 15.0, 1.2,   0.0],
	[0,  21.0, 15.0, 1.1, 180.0],
	[1,  -5.0,  -9.0, 1.1, 180.0],
	[2,  13.0,  -9.0, 1.0,  45.0],
	[3,   2.0,  -2.0, 1.0,  45.0],
	[4,  10.0,  -2.0, 1.0, -45.0],
	[0,  -9.0,   3.0, 1.1, 135.0],
	[1,  18.0,   2.0, 1.0,  90.0],
	[2,  -3.0,   8.0, 1.0, -90.0],
	[3,  15.0,   9.0, 1.1,   0.0],
	[4,   6.0,  13.0, 1.0, 180.0],
	[0, -11.0,  13.0, 1.0,  60.0],
	[1,  17.0,  14.0, 1.1, -60.0],
	[2,   4.0,   5.0, 0.9,  30.0],
]

# back wall at z=-12 — bg_dungeon.gdと同じ壁配置
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

	var tile_scenes: Array = [_FLOOR_PLAIN, _FLOOR_ROCKS, _FLOOR_DECO]
	for row: int in range(6):
		for col: int in range(10):
			var type_idx: int = _TILE_PATTERN[row][col]
			var tile: Node3D = (tile_scenes[type_idx] as PackedScene).instantiate()
			if type_idx == 2:
				tile.scale = Vector3.ONE * _FLOOR_DECO_SCALE
			var off_x := sin(col * 1.7 + row * 2.3) * 0.4
			var off_z := cos(col * 2.3 + row * 1.7) * 0.4
			tile.position = Vector3(-16.0 + col * _TILE_SIZE + off_x, 0.0, -4.0 + row * _TILE_SIZE + off_z)
			add_child(tile)

func _place_props() -> void:
	for p: Array in _PROPS:
		var scene_idx: int = p[0]
		var node: Node3D = (_PROP_SCENES[scene_idx] as PackedScene).instantiate()
		node.position = Vector3(p[1], 0.0, p[2])
		node.scale = Vector3.ONE * float(p[3])
		node.rotation_degrees.y = float(p[4])
		add_child(node)

func _place_walls() -> void:
	for w: Array in _WALLS:
		var is_corner: bool = w[3]
		var node: Node3D = (_CORNER if is_corner else _WALL).instantiate()
		node.position = Vector3(w[0], 0.0, w[1])
		node.rotation_degrees.y = float(w[2])
		add_child(node)
