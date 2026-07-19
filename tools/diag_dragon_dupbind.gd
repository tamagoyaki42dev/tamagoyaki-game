extends SceneTree
const MESH := "res://assets/enemy_candidates/dungeon_mason_fbx/dragon_terror_bringer.fbx"
func _initialize() -> void:
	var ch: Node3D = (load(MESH) as PackedScene).instantiate()
	root.add_child(ch)
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = ch.find_child("DragonMesh", true, false) as MeshInstance3D
	var skin: Skin = mi.skin
	var seen: Dictionary = {}
	var dups: Array[String] = []
	var collide := 0
	print("bind一覧のうち、名前で引くと別のボーンに解決されるもの：")
	for i: int in range(skin.get_bind_count()):
		var nm: String = skin.get_bind_name(i)
		if seen.has(nm):
			dups.append(nm)
		seen[nm] = true
		var by_name: int = sk.find_bone(nm)
		if by_name != i:
			collide += 1
			if collide <= 12:
				print("   bind[%2d] name='%s' → find_bone=%d (ボーン%dの名前は'%s')"
					% [i, nm, by_name, i, sk.get_bone_name(i)])
	print("")
	print("bind名の重複 = ", dups.size(), " 件 ", dups.slice(0, 10))
	print("bind番号 != find_bone(名前) となる件数 = ", collide, " / ", skin.get_bind_count())
	print("→ 0なら名前引きでも安全。>0 なら _fix_dragon_skin が別ボーンへ潰している")
	quit()
