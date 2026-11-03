extends Node3D
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(-2.1875, 1.58, 2.3125)
	camera.look_at(Vector3(1.3125, 1.13, -1.25))
	camera.fov = 78
	camera.current = true
	$Room/Player.hide()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/cabin_room_preview.png")
