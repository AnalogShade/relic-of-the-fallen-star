extends SceneTree
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var results: Array = []
func _initialize(): call_deferred("run")
func route(label: String):
	player.global_position = Vector3(-6.76,1.59,12.37)
	player.velocity = Vector3.ZERO
	player.water_jump_active = false
	player.swimming = false
	player.gliding = false
	player.get_node("CameraPivot").rotation.y = 0
	for i in 20: await process_frame
	Input.action_press("move_right")
	Input.action_press("move_forward",0.35)
	var start = Time.get_ticks_usec()
	var previous = start
	var times: Array[float] = []
	var points: Array = []
	var jumped = false
	var jump_time = 0.0
	while Time.get_ticks_usec()-start < 4500000:
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous = now
		var elapsed = (now-start)/1000000.0
		if player.global_position.x > -5.8 and not jumped:
			Input.action_press("jump")
			jumped = true
			jump_time = elapsed
		if jumped and elapsed-jump_time > 0.12: Input.action_release("jump")
		camera.global_position = player.global_position+Vector3(0,2.4,5)
		camera.look_at(player.global_position+Vector3(0,0,-4))
		points.append({"t":elapsed,"ms":times[-1],"pos":[player.position.x,player.position.y,player.position.z],"swimming":player.swimming,"water_depth":player.water_height-player.position.y})
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("jump")
	var total = 0.0
	var spikes = 0
	for t in times:
		total += t
		if t > 33.333: spikes += 1
	times.sort()
	var result = {"phase":label,"mean_ms":total/times.size(),"p95_ms":times[int(times.size()*0.95)],"max_ms":times[-1],"frames_over_33ms":spikes,"frames":times.size(),"end_position":points[-1].pos,"splash_count":player.water_footsteps.splash_count,"samples":points}
	results.append(result)
	var summary = result.duplicate()
	summary.erase("samples")
	print("MOTION_BENCH ",JSON.stringify(summary))
	FileAccess.open("res://../diagnostics/enemy_performance_20261026/motion.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 8: await process_frame
	player = world.get_node("Original/Player")
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 4000
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.time_of_day = 12.0
	cycle.set_process(false)
	await route("managed_stream_jump")
	world.get_node("EnemyActivity").free()
	await route("unmanaged_stream_jump")
	var activity = load("res://scripts/enemy_activity.gd").new()
	activity.name = "EnemyActivity"
	world.add_child(activity)
	await route("managed_stream_jump_repeat")
	world.queue_free()
	await process_frame
	quit()
