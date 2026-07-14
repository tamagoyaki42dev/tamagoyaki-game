extends Node3D
## Quaternius Ultimate Character Pack ビューア（開発ツール）
## assets/quaternius-ultimate-characters は元々 .gdignore で隔離されていたため、
## インポート可能な assets/quaternius_preview/ へ複製して読み込む。
## 素材の「Skin」「Face」マテリアルは未着色（ほぼ黒/白）のプレースホルダーなので、
## 通常の肌色へ自動着色してから表示する。scenes/quaternius_browser.tscn から単独起動する。

const DIR := "res://assets/quaternius_preview/"
const NAMES: Array[String] = [
	"BaseCharacter", "BlueSoldier_Female", "BlueSoldier_Male", "Casual2_Female", "Casual2_Male",
	"Casual3_Female", "Casual3_Male", "Casual_Bald", "Casual_Female", "Casual_Male",
	"Chef_Female", "Chef_Male", "Cowboy_Female", "Cowboy_Male", "Doctor_Female_Old",
	"Doctor_Female_Young", "Doctor_Male_Old", "Doctor_Male_Young", "Elf", "Goblin_Female",
	"Goblin_Male", "Kimono_Female", "Kimono_Male", "Knight_Golden_Female", "Knight_Golden_Male",
	"Knight_Male", "Ninja_Female", "Ninja_Male", "Ninja_Sand", "Ninja_Sand_Female",
	"OldClassy_Female", "OldClassy_Male", "Pirate_Female", "Pirate_Male", "Soldier_Female",
	"Soldier_Male", "Suit_Female", "Suit_Male", "Viking_Female", "Viking_Male",
	"Witch", "Wizard", "Worker_Female", "Worker_Male", "Zombie_Female", "Zombie_Male",
]
const SKIN_TONE := Color(0.94, 0.80, 0.68)

@export var cam_position: Vector3 = Vector3(0, 1.7, 3.4)
@export var cam_look_at: Vector3 = Vector3(0, 1.4, 0)
@export var cam_fov: float = 45.0
@export var rotate_speed: float = 0.01
@export var zoom_speed: float = 0.3
@export var zoom_min: float = 1.2
@export var zoom_max: float = 6.0

var _char_root: Node3D
var _dragging: bool = false
var _name_lbl: Label
var _cam: Camera3D
var _cam_dist: float

func _ready() -> void:
	_build_world()
	_build_ui()
	_load_character(NAMES[0])

func _load_character(cname: String) -> void:
	if _char_root and is_instance_valid(_char_root):
		_char_root.queue_free()
	var scn: PackedScene = load(DIR + cname + ".gltf")
	if not scn:
		push_warning("読み込み失敗: %s" % cname)
		return
	_char_root = scn.instantiate() as Node3D
	add_child(_char_root)
	_recolor_placeholder_materials(_char_root)
	if _name_lbl:
		_name_lbl.text = cname

## 「Skin」「Face」マテリアル（ほぼ黒/白のプレースホルダー）を通常の肌色へ塗り替える。
static func _recolor_placeholder_materials(root: Node3D) -> void:
	for node in _find_meshes(root):
		var mi := node as MeshInstance3D
		var m: Mesh = mi.mesh
		if not m:
			continue
		for s in m.get_surface_count():
			var mat: Material = m.surface_get_material(s)
			if mat and (mat.resource_name == "Skin" or mat.resource_name == "Face"):
				var dup := mat.duplicate() as StandardMaterial3D
				dup.albedo_color = SKIN_TONE
				mi.set_surface_override_material(s, dup)

static func _find_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_meshes(c))
	return out

# ── 3Dワールド ─────────────────────────────────────────────
func _build_world() -> void:
	_cam = Camera3D.new()
	_cam.position = cam_position
	_cam.look_at_from_position(cam_position, cam_look_at, Vector3.UP)
	_cam.fov = cam_fov
	_cam_dist = cam_position.distance_to(cam_look_at)
	add_child(_cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.4
	add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.37, 0.45)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.20)
	ground.material_override = mat
	add_child(ground)

# ── UI ─────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 320.0
	layer.add_child(left)
	var sc := ScrollContainer.new()
	left.add_child(sc)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(300, 0)
	sc.add_child(vb)

	var title := Label.new()
	title.text = "Quaternius Ultimate Characters"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)
	var hint := Label.new()
	hint.text = "肌色は自動着色済み（未着色プレースホルダー対策）"
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))
	hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(hint)

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(300, 900)
	for n: String in NAMES:
		list.add_item(n)
	list.item_selected.connect(_on_selected)
	vb.add_child(list)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 340.0
	bottom.offset_top = -50.0
	layer.add_child(bottom)
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 20)
	bottom.add_child(_name_lbl)

func _on_selected(idx: int) -> void:
	_load_character(NAMES[idx])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom(-zoom_speed)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom(zoom_speed)
	elif event is InputEventMouseMotion and _dragging and _char_root:
		_char_root.rotate_y(-event.relative.x * rotate_speed)

func _zoom(delta: float) -> void:
	_cam_dist = clampf(_cam_dist + delta, zoom_min, zoom_max)
	var dir := (cam_position - cam_look_at).normalized()
	_cam.position = cam_look_at + dir * _cam_dist
	_cam.look_at(cam_look_at, Vector3.UP)
