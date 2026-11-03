extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.7, 0)
	level.add_child(sun)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.12, 0.14, 0.18)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.6, 0.6, 0.7)
	settings.ambient_light_energy = 0.7
	env.environment = settings
	level.add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	floor_mesh.mesh = plane
	level.add_child(floor_mesh)
	var actor = load("res://scenes/player.tscn").instantiate()
	actor.position.y = 0.425
	level.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("Nael").set_process(false)
	actor.get_node("Nael").rotation.y = PI
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").current = false
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.position = Vector3(2.5, 1.7, -3.5)
	cam.look_at(Vector3(0,0.9,-0.4))
	cam.current = true
	for c in root.find_children("*", "CanvasLayer", true, false): c.hide()
	var ap: AnimationPlayer = actor.get_node("Nael").animator
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.play("Nael_Idle_Breathe")
	ap.advance(0)
	ap.speed_scale = 1
	cam.fov = 42
	cam.position = Vector3(4.3,2.3,-4.5)
	cam.look_at(Vector3(0,1.0,1.0))
	await process_frame
	var trail = actor.get_node("DodgeTrail")
	trail.set_process(false)
	ap.play("esquive_back",0.0)
	actor.dodge.active = true
	actor.dodge.direction = Vector3.BACK
	for f in range(34):
		var t := f/60.0
		var d := 2.85*(0.5-0.5*cos(PI*minf(t/0.28,1.0)))
		actor.position.z = d
		actor.velocity.z = 16.0*sin(PI*minf(t/0.28,1.0))
		ap.seek(minf(t*1.2,11.0/30.0),true)
		trail._process(1.0/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if f in [7,12,17,30]:
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../3D MODELS/MAIN CHARACTER/back_dodge_20261015/trail_%02d.png" % f))
	actor.dodge.active = false
	trail.clear_trail()
	level.free()
	quit()
