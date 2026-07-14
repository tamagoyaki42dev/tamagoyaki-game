extends SceneTree

# KayKit頭メッシュのUV展開とテクスチャを実測する使い捨てツール。
# 頭のUVが「面として広がる島」か「アトラスの一点」かを判定する（ルート1成立の生命線）。
# 実行：GODOT --headless --path . --script res://tools/head_uv_probe.gd

const TARGETS: Dictionary = {
	"res://assets/kaykit/characters/Knight.glb": "Knight_Head",
	"res://assets/kaykit/characters/Mage.glb":   "Mage_Head",
	"res://assets/kaykit/characters/Rogue.glb":  "Rogue_Head",
}

func _initialize() -> void:
	for path: String in TARGETS:
		var head_name: String = TARGETS[path]
		print("\n========== ", path, "  head='", head_name, "' ==========")
		var ps: PackedScene = load(path)
		var root: Node = ps.instantiate()
		var head: MeshInstance3D = _find(root, head_name) as MeshInstance3D
		if head == null:
			print("  <head not found>")
			continue
		_report(head)
	quit()

func _find(n: Node, target: String) -> Node:
	if n.name == target:
		return n
	for c in n.get_children():
		var r: Node = _find(c, target)
		if r != null:
			return r
	return null

func _report(head: MeshInstance3D) -> void:
	var mesh: Mesh = head.mesh
	if mesh == null:
		print("  <no mesh>")
		return
	# --- material / texture ---
	var mat: Material = head.get_surface_override_material(0)
	if mat == null and mesh.get_surface_count() > 0:
		mat = mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		var bm: BaseMaterial3D = mat as BaseMaterial3D
		var tex: Texture2D = bm.albedo_texture
		if tex != null:
			print("  albedo_texture: ", tex.resource_path, "  size=", tex.get_width(), "x", tex.get_height())
		else:
			print("  albedo_texture: <none>  albedo_color=", bm.albedo_color)
	else:
		print("  material class: ", ("<null>" if mat == null else mat.get_class()))
	# --- UV bounds ---
	var arrays: Array = mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if uvs.is_empty():
		print("  <no UVs>")
		return
	var umin: float = 1e9
	var umax: float = -1e9
	var vmin: float = 1e9
	var vmax: float = -1e9
	for uv in uvs:
		umin = min(umin, uv.x); umax = max(umax, uv.x)
		vmin = min(vmin, uv.y); vmax = max(vmax, uv.y)
	var span_u: float = umax - umin
	var span_v: float = vmax - vmin
	print("  verts=", verts.size(), "  uv_count=", uvs.size())
	print("  UV bounds: u[%.4f..%.4f] span=%.4f   v[%.4f..%.4f] span=%.4f" % [umin, umax, span_u, vmin, vmax, span_v])
	var verdict: String = "ISLAND(描ける)" if (span_u > 0.03 and span_v > 0.03) else "POINT/PALETTE(描けない=要Blender再UV)"
	print("  => VERDICT: ", verdict)
