extends SceneTree
var report = {"failures": [], "reached": 0}
func _initialize():
	call_deferred("run")
func wait_frames(n):
	for i in range(n): await physics_frame
func run():
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	await wait_frames(90)
	var player = world.get_node("Original/Player")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vigie_route.json"))
	var route = data.route
	route.append([64.0,75.0,44.341379])
	if "--descend" in OS.get_cmdline_user_args(): route.reverse()
	var start_index=200 if "--top" in OS.get_cmdline_user_args() else 0
	player.global_position = Vector3(route[start_index][0],route[start_index][2]+.7,-route[start_index][1])
	player.velocity = Vector3.ZERO
	await wait_frames(60)
	Input.action_press("move_forward")
	for idx in range(start_index+1,route.size()):
		var p = route[idx]
		var target = Vector3(p[0],p[2],-p[1])
		var reached = false
		for frame in range(180):
			var d = target-player.global_position
			d.y=0
			if d.length()<.22:
				reached=true
				break
			player.pivot.rotation.y=atan2(-d.x,-d.z)
			await wait_frames(1)
		if not reached:
			for k in player.get_slide_collision_count(): print("BLOCKER ",player.get_slide_collision(k).get_collider().get_path()," normal ",player.get_slide_collision(k).get_normal())
			report.failures.append({"index":idx,"position":str(player.global_position),"target":str(target)})
			break
		report.reached=idx
		if idx%25==0: print("REACHED ",idx)
	Input.action_release("move_forward")
	await wait_frames(20)
	report["on_floor"]=player.is_on_floor()
	report["final_position"]=str(player.global_position)
	FileAccess.open(("res://tests/vigie_descent_report.json" if "--descend" in OS.get_cmdline_user_args() else "res://tests/vigie_top_report.json" if start_index>0 else "res://tests/vigie_walk_report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WALK_REPORT ",JSON.stringify(report))
	world.queue_free()
	await wait_frames(3)
	quit()





