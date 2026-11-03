extends SceneTree

func _initialize():call_deferred("run")

func run():
	var world=load("res://scenes/world/open_world.tscn").instantiate();root.add_child(world)
	for i in range(80):await process_frame
	world.get_node("Original/HUD").hide()
	var camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=450;camera.fov=60
	var views=[
		["godot_sommet",Vector3(83,62,-50),Vector3(64,48.6,-76)],
		["godot_assise_arriere",Vector3(43,53,-94),Vector3(64,44,-77)],
		["godot_parcours",Vector3(26,67,-34),Vector3(64,28,-74)]
	]
	for view in views:
		camera.position=view[1];camera.look_at(view[2])
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/ruin_foundation_20261024/"+view[0]+".png")
	print("SOMMET_REVIEW screenshots=3")
	world.free()
	call_deferred("quit")
