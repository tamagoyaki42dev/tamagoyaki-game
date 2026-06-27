@tool
extends EditorPlugin

const SAVE_PATH: String = "res://tools/screenshot.png"

func _save_external_data() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = DisplayServer.screen_get_image(0)
	img.save_png(ProjectSettings.globalize_path(SAVE_PATH))
