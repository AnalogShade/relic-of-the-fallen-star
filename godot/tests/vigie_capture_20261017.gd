extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var w=load("res://scenes/world/open_world.tscn").instantiate();root.add_child(w)
	for i in range(80): await process_frame
	var cam=Camera3D.new();w.add_child(cam);cam.position=Vector3(21,63,-34);cam.look_at(Vector3(63,25,-74));cam.current=true;cam.far=400;cam.fov=65
	w.get_node("Original/HUD").hide()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/vigie_exterior_20261017.png")
	var player=w.get_node("Original/Player")
	player.global_position=Vector3(64,44.85,-72.3);player.velocity=Vector3.ZERO
	cam.position=Vector3(77,50,-59);cam.look_at(Vector3(65,43,-69));cam.fov=58
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/vigie_entry_20261017.png")
	quit()


