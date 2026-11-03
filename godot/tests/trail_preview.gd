extends Node3D

func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(12): await get_tree().physics_frame
	world.get_node("Original/Player").set_physics_process(false)
	world.get_node("Original/Player").hide()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false): c.hide()
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 65
	var views = [
		["junction", Vector3(40, 6, -31), Vector3(28, 3, -54)],
		["cave", Vector3(39, 6, -37), Vector3(40.95, 4, -46.97)],
		["camp", Vector3(29, 6, -48), Vector3(22, 3, -60)]
	]
	for v in views:
		camera.position = v[1]
		camera.look_at(v[2])
		for i in range(30): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/trail_" + v[0] + ".png")
	print("TRAIL_PREVIEW_COMPLETE")
	world.queue_free()
	camera.queue_free()
	for i in range(4): await get_tree().process_frame
	get_tree().quit()
