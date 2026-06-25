extends Node

## ポートレート・ベイクツール（使い捨て・エディタF6実行用）
##
## プレイヤー職のキャラモデル（BattleScene.unique_player_model_paths）を順に読み込み、
## SubViewport に正面向き・上半身が収まる構図で配置して 256×256・背景透過の PNG を
## res://assets/portraits/<モデルファイル名(stem)>.png に保存する。
##
## これは実行時には動かない一回限りの生成物。生成した PNG はリポジトリにコミットする。
## ヘッドレスでは GPU 描画されないため、必ずエディタ上で F6 実行すること。
##
## 構図が破綻していたら（顔が切れる・小さすぎる等）下記 @export を調整して再実行する。

const PORTRAIT_SIZE: int = 256                       # 出力PNGの一辺(px)
const OUT_DIR: String = "res://assets/portraits/"

# モデル実サイズ(AABB)から自動フレーミングするので高さの決め打ちは不要
@export var frame_zoom: float          = 0.62  # 全高に対し縦に映す割合（小さいほど上半身に寄る）
@export var frame_vertical_bias: float = 0.18  # 中心から上（頭側）へ狙点をずらす割合
@export var camera_margin: float       = 1.12  # フレーム外周の余白係数
@export var camera_fov: float        = 32.0   # 望遠寄りで歪みを抑える
@export var model_y_rotation: float  = 0.0    # モデルを正面（顔をカメラへ）に向ける回転(deg)
@export var key_light_energy: float  = 1.6
@export var fill_light_energy: float = 0.7
@export var settle_frames: int       = 3      # 描画確定を待つフレーム数

func _ready() -> void:
	await _bake_all()
	print("[portrait_baker] 完了。生成物: ", OUT_DIR)
	# エディタ実行を止める
	get_tree().quit()

func _bake_all() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var paths: Array[String] = BattleScene.unique_player_model_paths()
	for model_path: String in paths:
		await _bake_one(model_path)

func _bake_one(model_path: String) -> void:
	var packed: PackedScene = load(model_path) as PackedScene
	if not packed:
		push_warning("[portrait_baker] ロード失敗: %s" % model_path)
		return

	var vp := SubViewport.new()
	vp.size = Vector2i(PORTRAIT_SIZE, PORTRAIT_SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# モデル：正面を向けて原点に置く
	var model: Node3D = packed.instantiate() as Node3D
	model.rotation_degrees.y = model_y_rotation
	vp.add_child(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)  # idle の先頭フレームで固定

	# スキン付きメッシュの AABB は追加直後だと未確定なので、計測前に数フレーム待つ
	for _w: int in settle_frames:
		await get_tree().process_frame

	# カメラ：モデル実サイズ(AABB)から上半身が収まる正面構図を自動算出
	var aabb := _global_visual_aabb(model)
	var center := aabb.get_center()
	var height: float = aabb.size.y
	if height < 0.05:  # 計測が縮退したら既定値で代替（空PNG防止）
		push_warning("[portrait_baker] AABB縮退、既定構図で代替: %s" % model_path)
		height = 1.0
		center = Vector3(0.0, 0.5, 0.0)
	var target := Vector3(center.x, center.y + height * frame_vertical_bias, center.z)
	var visible_h: float = height * frame_zoom
	var dist: float = (visible_h * 0.5) / tan(deg_to_rad(camera_fov) * 0.5) * camera_margin

	var cam := Camera3D.new()
	cam.fov = camera_fov
	# look_at はツリー内必須なので look_at_from_position を使う（ノード追加前に向きを確定）
	cam.look_at_from_position(
		Vector3(target.x, target.y, center.z + dist),
		target, Vector3.UP)
	vp.add_child(cam)

	# ライティング（戦場と厳密一致でなくてよい・識別できれば十分）
	var key := DirectionalLight3D.new()
	key.light_energy = key_light_energy
	key.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = fill_light_energy
	fill.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	vp.add_child(fill)

	# 描画確定を待つ
	for _i: int in settle_frames:
		await get_tree().process_frame

	var img: Image = vp.get_texture().get_image()
	var stem: String = model_path.get_file().get_basename()
	var out_path: String = OUT_DIR + stem + ".png"
	var err: int = img.save_png(out_path)
	if err == OK:
		print("[portrait_baker] 保存: %s" % out_path)
	else:
		push_warning("[portrait_baker] 保存失敗(%d): %s" % [err, out_path])

	vp.queue_free()

# モデル配下の全 VisualInstance3D を覆うグローバル AABB（モデルはツリー内にいること）
func _global_visual_aabb(root: Node) -> AABB:
	var result := AABB()
	var has_any := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			var vi := n as VisualInstance3D
			var world_aabb: AABB = vi.global_transform * vi.get_aabb()
			if has_any:
				result = result.merge(world_aabb)
			else:
				result = world_aabb
				has_any = true
		for c: Node in n.get_children():
			stack.append(c)
	return result
