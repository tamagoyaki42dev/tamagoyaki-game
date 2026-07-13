extends SceneTree

# KayKit DungeonRemastered（assets/kaykit/environment/dungeon/）採用パーツの実寸(AABB)を実測する使い捨てツール。
# 床タイルのグリッド間隔・壁/コーナーの向き合わせに使う。当てずっぽう禁止のため実測してから battle 側の座標を決める。
# 実行：GODOT --headless --path . --script res://tools/dungeon_kaykit_probe.gd

const TARGETS: Array = [
	"res://assets/kaykit/environment/dungeon/floor_tile_large.gltf",
	"res://assets/kaykit/environment/dungeon/floor_tile_large_rocks.gltf",
	"res://assets/kaykit/environment/dungeon/floor_tile_small_decorated.gltf",
	"res://assets/kaykit/environment/dungeon/wall.gltf",
	"res://assets/kaykit/environment/dungeon/wall_corner.gltf",
	"res://assets/kaykit/environment/dungeon/barrel_large.gltf",
	"res://assets/kaykit/environment/dungeon/crates_stacked.gltf",
	"res://assets/kaykit/environment/dungeon/chest.gltf",
	"res://assets/kaykit/environment/dungeon/candle_triple.gltf",
	"res://assets/kaykit/environment/dungeon/banner_thin_red.gltf",
]

func _initialize() -> void:
	for path: String in TARGETS:
		print("\n========== ", path, " ==========")
		if not ResourceLoader.exists(path):
			print("  <missing>")
			continue
		var ps: PackedScene = load(path)
		var root: Node = ps.instantiate()
		_report_aabb(root)
	quit()

func _report_aabb(n: Node, depth: int = 0) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		var m: Mesh = mi.mesh
		if m != null:
			var ab: AABB = m.get_aabb()
			print("  ", n.name, " aabb_pos=", ab.position, " aabb_size=", ab.size)
	for c in n.get_children():
		_report_aabb(c, depth + 1)
