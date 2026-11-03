extends Node3D
func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(20): await get_tree().physics_frame
	var npc: Node3D = world.get_node("MaelorHerboriste")
	var player: Node3D = world.get_node("Original/Player")
	player.set_physics_process(false)
	player.hide()
	player.global_position = npc.global_position + Vector3(0,0,6)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 55
	camera.global_position = npc.global_position + Vector3(-3,2.2,4)
	camera.look_at(npc.global_position + Vector3.UP * 0.9)
	for i in range(35): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/herbalist_preview.png")
	get_tree().quit()
