## タイトル画面 — scenes/title_screen.tscn にアタッチ
extends Node

const GAME_TITLE := "Perrant"
const GAME_TITLE_RUBY := "ペラント"
const _ENEMY_INFO_SCENE := "res://scenes/enemy_info.tscn"

var _settings_panel: Control

func _ready() -> void:
	AudioManager.play_bgm(AudioManager.BGM_MENU)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sw: float = vp.x
	var sh: float = vp.y

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.10)
	root.add_child(bg)

	var title := Label.new()
	title.text = GAME_TITLE
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(sw * 0.5 - 300.0, sh * 0.28)
	title.size = Vector2(600.0, 80.0)
	root.add_child(title)

	var ruby := Label.new()
	ruby.text = GAME_TITLE_RUBY
	ruby.add_theme_font_size_override("font_size", 20)
	ruby.add_theme_color_override("font_color", Color(0.85, 0.80, 0.60))
	ruby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ruby.position = Vector2(sw * 0.5 - 300.0, sh * 0.28 + 82.0)
	ruby.size = Vector2(600.0, 24.0)
	root.add_child(ruby)

	var cx: float = sw * 0.5
	var y: float = sh * 0.55

	_btn(root, "はじめる", Vector2(cx, y), func() -> void:
		AudioManager.play_se(AudioManager.SE_START)
		GameState.ensure_init()
		GameState.battle_index = 0
		get_tree().change_scene_to_file(_ENEMY_INFO_SCENE))
	y += 70.0

	_btn(root, "設定", Vector2(cx, y), func() -> void:
		_settings_panel.visible = true)
	y += 70.0

	_btn(root, "終了", Vector2(cx, y), func() -> void:
		get_tree().quit())

	_settings_panel = _build_settings_panel(root, sw, sh)

func _btn(parent: Node, text: String, pos: Vector2, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos - Vector2(100.0, 22.0)
	b.size = Vector2(200.0, 48.0)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(callback)
	parent.add_child(b)

func _build_settings_panel(parent: Control, sw: float, sh: float) -> Control:
	var panel := Panel.new()
	panel.position = Vector2(sw * 0.5 - 220.0, sh * 0.5 - 100.0)
	panel.size = Vector2(440.0, 200.0)
	panel.visible = false
	parent.add_child(panel)

	var label := Label.new()
	label.text = "音量"
	label.position = Vector2(30.0, 30.0)
	label.size = Vector2(120.0, 32.0)
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioManager.master_volume
	slider.position = Vector2(30.0, 70.0)
	slider.size = Vector2(380.0, 24.0)
	slider.value_changed.connect(func(v: float) -> void: AudioManager.set_master_volume(v))
	panel.add_child(slider)

	var close_btn := Button.new()
	close_btn.text = "閉じる"
	close_btn.position = Vector2(170.0, 130.0)
	close_btn.size = Vector2(100.0, 40.0)
	close_btn.pressed.connect(func() -> void: panel.visible = false)
	panel.add_child(close_btn)

	return panel
