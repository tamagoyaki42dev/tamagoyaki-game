extends Node3D

# 顔テクスチャをKayKitキャラに載せて単体で見るためのプレビュー専用シーン。
# 戦闘シーン（本番）には一切影響しない。tools/face_preview_view.tscn を開いて F6 で実行。
# 静止プレビューのためボーン装着ではなくモデル空間に顔板を置く（本番統合時はheadボーンにBoneAttachment3Dで載せ直す）。
#
# 調整はインスペクタで（実行しなくても数値だけ変えて再実行すればOK）：
#   - body_facing_away を切り替えると、顔とカメラが反対側へ一緒に回る（＝キャラが後ろ向きだった時の一発反転）
#   - face_height / face_forward / face_size で顔の高さ・前後・大きさ
#   - face_rot_deg で顔の傾き微調整

@export_file("*.glb", "*.gltf") var char_glb: String = "res://assets/kaykit/characters/Barbarian.glb"
@export_file("*.png") var face_texture_path: String = "res://tools/_face_preview.png"

@export var blank_head: bool = false           # KayKit限定機能。Quaternius系はheadメッシュが分離してないため無効（no-op)
# 注意：blank_head_texture_pathはキャラごとにUV配置が違うため専用生成が必要（tools/gen_blank_head.gd参照）。
# char_glbを変えたら対応する_[job]_head_blank.pngも作り直してここを差し替えること。
@export_file("*.png") var blank_head_texture_path: String = "res://tools/_knight_head_blank.png"
@export var show_face_plane: bool = true       # 自作の顔板を出すか

# 元の頭を隠し、面取りされた球（低ポリのっぺらぼう）に丸ごと差し替える。
# flatten_head_faceで頑張って均すより、最初から顔の無い形を用意する方が早い場合の比較用。
@export var use_primitive_head: bool = false
@export_range(6, 16) var primitive_head_segments: int = 8   # 少ないほど角ばる（KayKitの低ポリ感に寄せる）
@export var primitive_head_color: Color = Color(0.969, 0.765, 0.627)  # Knightの肌色実測値

# ユーザーがBlenderで作った「のっぺらぼう」頭メッシュ（別glbファイル）に丸ごと差し替える。
# base.glbはKayKitと同じ座標系（Rig_Medium）で作られているため、位置合わせ不要でそのまま置ける想定。
@export var use_custom_head_mesh: bool = true
@export_file("*.glb", "*.gltf") var custom_head_glb: String = "res://assets/kaykit/characters/base.glb"
@export var custom_head_mesh_name: String = "Barbarian_Head_001"

# 頭メッシュの顔面（鼻・眉の出っ張り）を平らへ寄せる。テクスチャ差し替えだけでは
# ジオメトリの陰影（鼻の影・眉の稜線）が残って顔が消せないため、頂点自体を動かす。
@export var flatten_head_face: bool = true
@export_range(0.0, 1.0) var flatten_strength: float = 1.0    # 1.0=完全に平ら, 0=無効
@export_range(0.0, 0.5) var flatten_target_percentile: float = 0.0  # 基準面の位置。0=最も奥（最強）、大きいほど控えめ
@export_range(0.3, 0.9) var flatten_window_x: float = 0.70    # 平坦化する範囲の横幅（頭幅に対する比率）
@export_range(0.15, 0.5) var flatten_window_y: float = 0.42   # 平坦化する範囲の縦幅（頭高さに対する比率。眉山まで届かせるため広め）

@export var body_facing_away: bool = false     # キャラが後ろ向きに見えたらチェック
# A案：板を頭表面ギリギリまで寄せ、目・眉の凹みが縁からはみ出ない大きさにして下の陰影を隠す
@export var face_height: float = 1.60           # 顔（目）の高さ（頭中心≈1.6）
@export var face_forward: float = 0.50          # 頭表面までの前後距離（鼻先より少し手前に詰めた）
@export var face_size: float = 0.85             # 顔板の一辺（頭幅≈1.14よりひと回り小さく＝頭の輪郭からはみ出させない）
@export var face_side: float = 0.0              # 左右微調整
@export var face_rot_deg: Vector3 = Vector3.ZERO

@export var cam_distance: float = 2.4
@export var cam_height: float = 1.85
@export var cam_side: float = 0.8
@export var cam_fov: float = 45.0

func _ready() -> void:
	var z_sign: float = -1.0 if body_facing_away else 1.0

	# --- キャラ ---
	var char_scene: PackedScene = load(char_glb)
	var ch: Node3D = char_scene.instantiate()
	add_child(ch)

	# --- 頭メッシュの下処理（カスタム頭差し替え／プリミティブ差し替え／平坦化・色消し）---
	var head: MeshInstance3D = _find_head(ch)
	if use_custom_head_mesh:
		if head != null:
			_replace_with_custom_head(head)
	elif use_primitive_head:
		if head != null:
			_replace_with_primitive_head(head, ch)
	else:
		if head != null and flatten_head_face:
			_flatten_head_face(head)
		if blank_head and head != null and ResourceLoader.exists(blank_head_texture_path):
			var blank_tex: Texture2D = load(blank_head_texture_path)
			var base: Material = head.get_active_material(0)
			var m: BaseMaterial3D = (base.duplicate() if base is BaseMaterial3D else StandardMaterial3D.new()) as BaseMaterial3D
			m.albedo_texture = blank_tex
			head.material_override = m

	# --- 顔板 ---
	if not show_face_plane:
		_finish(ch, z_sign)
		return
	var tex: Texture2D = load(face_texture_path)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(face_size, face_size)
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = "FacePlane"
	face.mesh = quad
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.material_override = mat
	face.position = Vector3(face_side, face_height, z_sign * face_forward)
	face.rotation_degrees = Vector3(face_rot_deg.x, face_rot_deg.y + (180.0 if body_facing_away else 0.0), face_rot_deg.z)
	ch.add_child(face)

	_finish(ch, z_sign)

func _finish(_ch: Node3D, z_sign: float) -> void:
	# --- ライト＆環境 ---
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, z_sign * 35.0, 0.0)
	add_child(key)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# --- カメラ（顔と同じ側・軽くアイソメ寄せ）---
	var cam: Camera3D = Camera3D.new()
	cam.fov = cam_fov
	add_child(cam)
	cam.global_position = Vector3(cam_side, cam_height, z_sign * cam_distance)
	cam.look_at(Vector3(0.0, face_height, 0.0), Vector3.UP)
	cam.current = true

# 元の頭メッシュを隠し、外部glb（ユーザーがBlenderで作った頭）の指定メッシュに差し替える。
# 実測でAABBがKayKit本家Headとほぼ一致していたため、頂点データをそのまま元の頭と同じ
# ローカル座標（同じ親ノードの直下）に置くだけで位置合わせできる想定。スキン情報は使わず
# 静止ジオメトリとして貼る（本番でアニメ追従させるにはheadボーンへのBoneAttachment3Dが別途必要）。
func _replace_with_custom_head(head: MeshInstance3D) -> void:
	if not ResourceLoader.exists(custom_head_glb):
		push_warning("custom_head_glb not found: " + custom_head_glb)
		return
	var src_root: Node = (load(custom_head_glb) as PackedScene).instantiate()
	var src: MeshInstance3D = _find_named(src_root, custom_head_mesh_name)
	if src == null or src.mesh == null:
		push_warning("custom head mesh not found: " + custom_head_mesh_name)
		return
	head.visible = false
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CustomHead"
	mi.mesh = src.mesh
	# 元の頭と同じ親・同じローカル変形で配置（座標系が一致している前提の直置き）
	head.get_parent().add_child(mi)
	mi.transform = head.transform

func _find_named(n: Node, nm: String) -> MeshInstance3D:
	if n is MeshInstance3D and n.name == nm:
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _find_named(c, nm)
		if r != null:
			return r
	return null

# 元の頭メッシュを隠し、同じ位置・大きさの面取り球（SphereMesh）を代わりに置く。
# セグメント数を絞ることでKayKitの低ポリな面取り感に寄せつつ、最初から顔の凹凸を持たない下地にする。
func _replace_with_primitive_head(head: MeshInstance3D, ch: Node3D) -> void:
	head.visible = false
	var ab: AABB = head.mesh.get_aabb()
	var ctr: Vector3 = ab.position + ab.size * 0.5
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = ab.size.x * 0.5
	sphere.height = ab.size.y
	sphere.radial_segments = primitive_head_segments
	sphere.rings = int(primitive_head_segments * 0.75)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "PrimitiveHead"
	mi.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = primitive_head_color
	mi.material_override = mat
	mi.position = ctr
	head.get_parent().add_child(mi)

# 頭メッシュの顔窓（鼻・眉のある領域）の頂点を、出っ張り量ベースで平坦面へ寄せる。
# Blender不要・頂点座標をCPUで直接書き換える。窓の中心ほど強く効かせ、縁でフェードアウトさせて
# 周囲の頬・こめかみとの継ぎ目に段差ができないようにする（tools/face_depth_probeでの実測に基づく）。
func _flatten_head_face(head: MeshInstance3D) -> void:
	var src_mesh: Mesh = head.mesh
	if src_mesh == null or src_mesh.get_surface_count() == 0:
		return
	var arrays: Array = src_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var ab: AABB = src_mesh.get_aabb()
	var ctr: Vector3 = ab.position + ab.size * 0.5
	var half_w: float = ab.size.x * 0.5 * flatten_window_x
	var half_h: float = ab.size.y * flatten_window_y

	# 前面がどちら側(+Z/-Z)か、窓内の頂点数が多い側で判定する
	var count_pos: int = 0
	var count_neg: int = 0
	for v: Vector3 in verts:
		if absf(v.x - ctr.x) > half_w or absf(v.y - ctr.y) > half_h:
			continue
		if v.z >= ctr.z:
			count_pos += 1
		else:
			count_neg += 1
	var front_sign: float = 1.0 if count_pos >= count_neg else -1.0

	# 窓内かつ前面側にある頂点の「出っ張り量」を集めて基準面(低めの百分位)を決める
	var protrusions: Array[float] = []
	for v: Vector3 in verts:
		if absf(v.x - ctr.x) > half_w or absf(v.y - ctr.y) > half_h:
			continue
		var p: float = front_sign * (v.z - ctr.z)
		if p > 0.0:
			protrusions.append(p)
	if protrusions.is_empty():
		return
	protrusions.sort()
	var base_p: float = protrusions[int(protrusions.size() * flatten_target_percentile)]

	# 陰影は法線の向きだけで決まる（Lambert照明はvertex座標を見ない）。
	# 座標だけ動かして法線を放置すると、形は変わっても「鼻の傾き」の陰影がそのまま残って
	# 見た目には無変化になる（実際にこれで一度ハマった）。法線も同じ強さで平面向きへ寄せる。
	var has_normals: bool = arrays[Mesh.ARRAY_NORMAL] != null
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if has_normals else PackedVector3Array()
	var flat_normal: Vector3 = Vector3(0.0, 0.0, front_sign)

	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var dx: float = absf(v.x - ctr.x)
		var dy: float = absf(v.y - ctr.y)
		if dx > half_w or dy > half_h:
			continue
		var p: float = front_sign * (v.z - ctr.z)
		if p <= base_p:
			continue
		var tx: float = clampf(1.0 - dx / half_w, 0.0, 1.0)
		var ty: float = clampf(1.0 - dy / half_h, 0.0, 1.0)
		var fall: float = smoothstep(0.0, 1.0, minf(tx, ty))
		var t: float = flatten_strength * fall
		var new_p: float = lerpf(p, base_p, t)
		verts[i] = Vector3(v.x, v.y, ctr.z + front_sign * new_p)
		if has_normals:
			normals[i] = normals[i].lerp(flat_normal, t).normalized()

	arrays[Mesh.ARRAY_VERTEX] = verts
	if has_normals:
		arrays[Mesh.ARRAY_NORMAL] = normals
	var new_mesh: ArrayMesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var orig_mat: Material = src_mesh.surface_get_material(0)
	if orig_mat != null:
		new_mesh.surface_set_material(0, orig_mat)
	head.mesh = new_mesh

func _find_head(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).ends_with("_Head"):
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _find_head(c)
		if r != null:
			return r
	return null
