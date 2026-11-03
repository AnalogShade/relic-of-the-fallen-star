extends Node3D
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var actor := $World/Original/Player
	actor.global_position = Vector3(-45,28,18)
	actor.velocity = Vector3.ZERO
	actor.pivot.rotation.y = -0.9
	actor.arm.spring_length = 3.5
	await get_tree().create_timer(0.3).timeout
	Input.action_press("jump")
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/nael_glide_world.png")
	Input.action_release("jump")
