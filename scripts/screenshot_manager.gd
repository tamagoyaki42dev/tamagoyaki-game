extends Node

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_F12 \
			and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://tools")
		img.save_png("user://tools/screenshot.png")
		print("スクショ保存完了")
