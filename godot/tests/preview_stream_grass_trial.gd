extends SceneTree
const TRIAL = preload("res://scripts/stream_grass_trial.gd")
const OUT = "res://../diagnostics/stream_grass_trial/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1400,900)
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 25: await physics_frame
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	cycle.time_of_day = 12
	for i in 5: await process_frame
	for node in world.find_children("*","Node",true,false):
		node.set_process(false)
		node.set_physics_process(false)
	for layer in root.find_children("*","CanvasLayer",true,false): layer.hide()
	TRIAL.apply(world)
	assert(world.has_node("StreamGrassTrial"))
	var layer := world.get_node("StreamGrassTrial")
	var children := layer.get_child_count()
	TRIAL.apply(world)
	assert(layer.get_child_count()==children,"Apply must be idempotent")
	# All repeated placements of each model use exactly the same Mesh resource.
	var count := 0
	for batch: MultiMeshInstance3D in layer.get_children():
		assert(batch.multimesh.mesh != null)
		count += batch.multimesh.instance_count
	assert(count == int(layer.get_meta("total")))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRIAL.DIRECTORY+"layout.json"))
	var r: Array = layout.rect
	var rect := Rect2(r[0],r[1],r[2],r[3])
	var outside_checked := 0
	for node: MultiMeshInstance3D in world.get_node("HerbesDetaillees").find_children("*","MultiMeshInstance3D",true,false):
		if not node.has_meta("stream_trial_original"):
			continue
		var original: MultiMesh = node.get_meta("stream_trial_original")
		var kept := 0
		for i in original.instance_count:
			var transform := original.get_instance_transform(i)
			var point: Vector3 = node.global_transform*transform.origin
			if not rect.has_point(Vector2(point.x,point.z)):
				assert(node.multimesh.get_instance_transform(kept).is_equal_approx(transform),"Outside trial changed")
				kept += 1
				outside_checked += 1
		assert(node.multimesh.instance_count == kept)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.far = 1200
	camera.fov = 60
	for shot in [
		{"name":"overview","position":Vector3(10,8,16),"target":Vector3(6,1.2,3)},
		{"name":"close","position":Vector3(9,2.5,7.5),"target":Vector3(6.7,1.2,4.8)},
		{"name":"path","position":Vector3(0,5,12),"target":Vector3(2,1.2,2)}]:
		camera.position = shot.position
		camera.look_at(shot.target)
		for enabled in [false,true]:
			TRIAL.set_enabled(world,enabled)
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+shot.name+("_after.png" if enabled else "_before.png"))
	print("STREAM_GRASS_VERIFIED total=",count," shared_mesh_batches=",children," outside_unchanged=",outside_checked," idempotent=true")
	world.queue_free()
	camera.queue_free()
	for i in 3: await process_frame
	quit()
