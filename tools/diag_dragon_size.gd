extends SceneTree
const MESH_FBX := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
func _initialize() -> void:
	var ch: Node3D = (load(MESH_FBX) as PackedScene).instantiate()
	root.add_child(ch)
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var aabb: AABB = mi.mesh.get_aabb()
	print("メッシュ頂点データのAABB = ", aabb.size)
	print("  → 数メートル台ならインポート時に縮小済み（restと同じ空間・追加スケール不要）")
	print("  → 数百台ならcm原寸のまま（スキン倍率1.0にすると100倍になる）")
	print("MeshInstance3D の可視AABB = ", mi.get_aabb().size)
	quit()
