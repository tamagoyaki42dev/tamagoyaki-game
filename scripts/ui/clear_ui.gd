## 3戦クリア画面 — scenes/clear.tscn にアタッチ
extends Node

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	var sw := vp.x
	var sh := vp.y

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(sw, sh)
	bg.color = Color(0.05, 0.06, 0.10)
	root.add_child(bg)

	var title := Label.new()
	title.text = "全3戦クリア！"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(sw * 0.5 - 250.0, sh * 0.35)
	title.size = Vector2(500.0, 80.0)
	root.add_child(title)

	var quit_btn := Button.new()
	quit_btn.text = "終了"
	quit_btn.position = Vector2(sw * 0.5 - 100.0, sh * 0.58)
	quit_btn.size = Vector2(200.0, 56.0)
	quit_btn.add_theme_font_size_override("font_size", 22)
	quit_btn.pressed.connect(func(): get_tree().quit())
	root.add_child(quit_btn)
