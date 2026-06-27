extends Node

const _ENEMY_INFO_SCENE := "res://scenes/enemy_info.tscn"
const _FORMATION_SCENE  := "res://scenes/formation.tscn"
const _BATTLE_SCENE     := "res://scenes/battle.tscn"
const _CLEAR_SCENE      := "res://scenes/clear.tscn"

func _ready() -> void:
	GameState.ensure_init()
	var vp := get_viewport().get_visible_rect().size
	var sw := vp.x
	var sh := vp.y

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.10)
	root.add_child(bg)

	_lbl(root, "デバッグランチャー", Vector2(sw * 0.5, 60.0), 32, Color(1, 1, 1), true)

	var cx := sw * 0.5
	var y := 160.0
	var gap := 70.0

	_lbl(root, "── 通常フロー（敵情報 → 編成 → 戦闘）──", Vector2(cx, y), 16, Color(0.6, 0.8, 1.0), true)
	y += 40.0

	for i in 3:
		var idx := i
		_btn(root, "第%d戦" % (i + 1), Vector2(cx - 160.0 + i * 170.0, y), func():
			GameState.battle_index = idx
			get_tree().change_scene_to_file(_ENEMY_INFO_SCENE))
	y += gap

	_lbl(root, "── 戦闘のみ（編成スキップ）──", Vector2(cx, y), 16, Color(0.6, 0.8, 1.0), true)
	y += 40.0

	for i in 3:
		var idx := i
		_btn(root, "第%d戦" % (i + 1), Vector2(cx - 160.0 + i * 170.0, y), func():
			GameState.battle_index = idx
			get_tree().change_scene_to_file(_BATTLE_SCENE))
	y += gap

	_lbl(root, "── その他 ──", Vector2(cx, y), 16, Color(0.6, 0.8, 1.0), true)
	y += 40.0

	_btn(root, "クリア画面", Vector2(cx, y), func():
		get_tree().change_scene_to_file(_CLEAR_SCENE))

func _lbl(parent: Node, text: String, pos: Vector2, size: int,
		color: Color = Color.WHITE, centered: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos if not centered else Vector2(pos.x - 300.0, pos.y)
	l.size = Vector2(600.0, 40.0) if centered else Vector2(400.0, 40.0)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)

func _btn(parent: Node, text: String, pos: Vector2, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos - Vector2(70.0, 20.0)
	b.size = Vector2(140.0, 44.0)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(callback)
	parent.add_child(b)
