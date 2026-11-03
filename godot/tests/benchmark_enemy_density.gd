extends SceneTree
var world: Node3D
var added: Array[Node] = []
var enemies: Array[Node] = []
var grounds: Array[ShaderMaterial] = []
var waters: Array[Node3D] = []
var results: Array = []
func _initialize(): call_deferred("run")
func sample(label: String):
	for i in 12: await process_frame
	var frames: Array[float] = []
	var physics: Array[float] = []
	var cpu: Array[float] = []
	var previous = Time.get_ticks_usec()
	var started = previous
	while frames.size() < 90 or Time.get_ticks_usec() - started < 2000000:
		await process_frame
		var now = Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	frames.sort()
	physics.sort()
	cpu.sort()
	var total = 0.0
	for value in frames: total += value
	var result = {"phase":label,"mean_ms":total/frames.size(),"p95_ms":frames[int(frames.size()*0.95)],"physics_median_ms":physics[physics.size()/2],"process_median_ms":cpu[cpu.size()/2],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	results.append(result)
	print("BENCH ",JSON.stringify(result))
	FileAccess.open("res://../diagnostics/enemy_performance_20261026/benchmark_after.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
func set_enemies(nodes: Array[Node], processing: bool, visible: bool):
	for enemy in nodes:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if processing else Node.PROCESS_MODE_DISABLED
		enemy.visible = visible
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 8: await process_frame
	var player = world.get_node("Original/Player")
	player.global_position = Vector3(-1,0.1,9.7)
	player.set_physics_process(false)
	world.get_node("Original/HUD").hide()
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.time_of_day = 12.0
	cycle.set_process(false)
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-1,2.4,14.0)
	camera.look_at(Vector3(0,0.4,5))
	camera.current = true
	camera.far = 4000
	enemies.assign(get_nodes_in_group("enemies"))
	for enemy in enemies:
		if str(enemy.name).begins_with("Bandit_Renfort_") or str(enemy.name).begins_with("Araignee_Forestiere_"): added.append(enemy)
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		var m = mesh.material_override as ShaderMaterial
		if m and m.shader:
			if m.shader.resource_path in ["res://shaders/ground.gdshader","res://shaders/world_ground.gdshader"] and m not in grounds: grounds.append(m)
			if m.shader.resource_path == "res://shaders/stream_water.gdshader": waters.append(mesh)
	print("BENCH_SETUP added=",added.size()," enemies=",enemies.size()," grounds=",grounds.size())
	await sample("managed_near_stream")
	world.get_node("EnemyActivity").free()
	await sample("unmanaged_near_stream")
	var activity = load("res://scripts/enemy_activity.gd").new()
	activity.name = "EnemyActivity"
	world.add_child(activity)
	await sample("managed_near_stream_repeat")
	player.global_position = Vector3(-7,1.6,12)
	await sample("managed_stream_bank")
	player.global_position = Vector3(-1,0.1,9.7)
	await sample("managed_stream_reentry")
	world.queue_free()
	await process_frame
	quit()
