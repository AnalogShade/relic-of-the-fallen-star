extends Node3D
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(-57.75, 13.8174, 0.85)
	camera.look_at(Vector3(-54.95, 13.3674, -2.0))
	camera.fov = 78
	camera.current = true
	var hud := $World/Original.get_node_or_null("HUD")
	if hud: hud.hide()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/cabin_interior_preview.png")
