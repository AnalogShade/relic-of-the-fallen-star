extends Node3D

func _ready() -> void:
	var world: Node3D=load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player=world.get_node("Original/Player")
	player.set_physics_process(false)
	player.hide()
	for c in get_tree().root.find_children("*","CanvasLayer",true,false): c.hide()
	var camera:=Camera3D.new()
	add_child(camera)
	camera.position=Vector3(10,14,-43)
	camera.look_at(Vector3(22,2,-60))
	camera.fov=58
	camera.current=true
	for i in range(60): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/camp_overview.png")
	camera.position=Vector3(19,4.2,-53)
	camera.look_at(Vector3(22.4,3.2,-62))
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/camp_entrance.png")
	print("CAMP_PREVIEW_COMPLETE")
	world.queue_free()
	camera.queue_free()
	for i in range(4): await get_tree().process_frame
	get_tree().quit()
