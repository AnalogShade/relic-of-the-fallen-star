extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var actor = level.get_node("Original/Player")
	for i in range(100): await process_frame
	actor.set_physics_process(false)
	actor.get_node("Nael").set_process(false)
	var trail = actor.get_node("DodgeTrail")
	trail.set_process(false)
	var animator: AnimationPlayer = actor.get_node("Nael").animator
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.play("esquive_front",0.0)
	var start: Vector3 = actor.global_position
	actor.dodge.active = true
	actor.dodge.charging = true
	actor.dodge.direction = (actor.pivot.global_basis * Vector3.FORWARD).normalized()
	actor.get_node("Nael").rotation.y = actor.pivot.rotation.y + PI
	for f in range(35):
		var t := f/60.0
		var u := clampf((t-0.04)/0.32,0.0,1.0)
		var d: float = 11.0*0.32/PI*(1.0-cos(PI*u))
		var prev_u := clampf((t-1.0/60.0-0.04)/0.32,0.0,1.0)
		var previous: float = 11.0*0.32/PI*(1.0-cos(PI*prev_u))
		actor.global_position = start + actor.dodge.direction*d
		actor.velocity = actor.dodge.direction*(d-previous)*60.0
		animator.seek(minf(t*2.5,8.0/30.0),true)
		trail._process(1.0/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if f in [4,8,12,30]:
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../3D MODELS/MAIN CHARACTER/front_dodge_20261015/daylight_%02d.png" % f))
	trail.clear_trail()
	level.free()
	quit()
