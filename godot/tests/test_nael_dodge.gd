extends SceneTree
var failures: Array[String] = []
var actor
var level: Node3D
var enemy
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	level.add_child(body)
	return body
func reset_actor() -> void:
	actor.respawn()
	actor.position = Vector3(0,0.425,0)
	actor.pivot.rotation.y = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(4)
func key(code: int, pressed: bool, echo: bool = false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	Input.parse_input_event(e)
	await frames(1)
func run() -> void:
	level = Node3D.new();root.add_child(level);current_scene=level
	box(Vector3(0,-0.5,0), Vector3(80,1,80))
	actor = load("res://scenes/player.tscn").instantiate()
	actor.position.y = 0.425
	level.add_child(actor)
	await frames(15)
	# Warm up the effect shaders before timing the input/physics checks.
	actor.dodge.start("move_left")
	await frames(60)
	await reset_actor()
	var dodge = actor.dodge
	var ap: AnimationPlayer = actor.get_node("Nael").animator
	check(not ap.has_animation("Nael_Dodge_Left"), "Draft animations removed from game asset")
	check(ap.has_animation("esquive_front"), "Authored front charge imported")
	check(ap.get_animation("esquive_front").loop_mode == Animation.LOOP_NONE, "Front charge does not loop")
	check(is_equal_approx(ap.get_animation("esquive_front").length,8.0/30.0), "Front source timing preserved")
	check(ap.has_animation("esquive_back"), "Authored backstep imported")
	for clip in ["esquive_gauche", "esquive_droite"]:
		check(ap.has_animation(clip), clip+" imported")
		check(ap.get_animation(clip).loop_mode == Animation.LOOP_NONE, clip+" does not loop")
		check(is_equal_approx(ap.get_animation(clip).length, 25.0/30.0), clip+" source timing preserved")
		var animation := ap.get_animation(clip)
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or not str(animation.track_get_path(track)).ends_with(":Hips"):
				continue
			var first: Vector3 = animation.track_get_key_value(track, 0)
			var lateral_drift := 0.0
			for key_index in animation.track_get_key_count(track):
				var value: Vector3 = animation.track_get_key_value(track, key_index)
				lateral_drift = maxf(lateral_drift, absf(value.x - first.x))
			check(lateral_drift < 0.00001, clip+" has no duplicated lateral root motion")
	check(ap.get_animation("esquive_back").loop_mode == Animation.LOOP_NONE, "Backstep does not loop")
	check(is_equal_approx(ap.get_animation("esquive_back").length, 11.0/30.0), "Original 1–12 frame timing preserved")
	for action in dodge.ACTIONS:
		await reset_actor()
		check(dodge.start(action), action+" starts")
		var expected_clip: String = {"move_left":"esquive_gauche", "move_right":"esquive_droite", "move_backward":"esquive_back", "move_forward":"esquive_front"}[action]
		check(ap.assigned_animation == expected_clip, action+" uses only its intended animation")
		check(is_equal_approx(ap.speed_scale,2.0 if action == "move_backward" else (2.5 if action == "move_forward" else 1.0)), "Configured playback speed applied")
		var start: Vector3 = actor.position
		if action == "move_backward":
			await frames(1)
			check(actor.position.distance_to(start)>0.30, "Backstep bursts at full speed on its first physics frame")
			await frames(11)
		elif action == "move_forward":
			await frames(9)
			check(is_equal_approx(ap.current_animation_position,ap.get_animation("esquive_front").length), "Charge reaches final pose in about 0.11 seconds")
			var skeleton: Skeleton3D = actor.get_node("Nael/Armature/Skeleton3D")
			var pose := skeleton.get_bone_pose(skeleton.find_bone("Spine"))
			await frames(11)
			check(ap.assigned_animation == "esquive_front" and pose.is_equal_approx(skeleton.get_bone_pose(skeleton.find_bone("Spine"))), "Final charge pose held during remaining forward movement")
		else:
			await frames(40)
		var trail = actor.get_node("DodgeTrail")
		check(trail.samples.size() > 1 and trail.ribbon.get_surface_count() > 0, "Dodge emits motion ribbons")
		if DisplayServer.get_name() != "headless":
			check(not trail.ghosts.is_empty(), "Dodge emits posed silhouettes")
		var travel: Vector3 = actor.position - start
		var expected: Vector3 = {"move_left":Vector3.LEFT,"move_right":Vector3.RIGHT,"move_backward":Vector3.BACK,"move_forward":Vector3.FORWARD}[action]
		var distance: float = travel.dot(expected)
		check((distance > 11.55 and distance < 12.45) if action == "move_backward" else (distance > 4.5 and distance < 7.8), action+" tripled travel: "+str(travel))
		check(absf(angle_difference(actor.get_node("Nael").rotation.y, PI))<0.01, action+" keeps facing forward")
		check(not actor.start_claw() and not actor.start_fireball(), "Combat cannot overwrite maneuver")
		check(not dodge.start(action), "Cannot stack maneuvers")
		await frames(22)
		check(not dodge.active, "Maneuver ends and locomotion resumes")
		check(not trail.aura.visible and trail.samples.is_empty() and trail.ghosts.is_empty() and trail.ribbon.get_surface_count() == 0, "Motion trail fully fades after dodge")
	await reset_actor()
	await key(KEY_A,true);await key(KEY_A,false)
	await frames(1)
	check(not dodge.active and dodge.pending=="", "Single tap remains normal movement")
	await key(KEY_A,true,true)
	check(dodge.pending=="", "Keyboard repeat cannot dodge")
	await key(KEY_A,false)
	await key(KEY_A,true);await key(KEY_A,false)
	await frames(1)
	check(dodge.active, "Double tap triggers sidestep")
	await reset_actor()
	actor.get_node("Nael").rotation.y = PI
	var origin: Vector3 = actor.position
	await key(KEY_S,true)
	await frames(5)
	check(absf(angle_difference(actor.get_node("Nael").rotation.y,PI))<0.01, "First back tap does not turn before dodge")
	check(actor.position.z > origin.z + 0.01, "First tap still moves immediately")
	await key(KEY_S,false)
	await key(KEY_S,true)
	await frames(3)
	check(dodge.active and ap.assigned_animation == "esquive_back", "Double back tap plays authored dodge")
	check(absf(angle_difference(actor.get_node("Nael").rotation.y,PI))<0.01, "Back dodge never starts with a turn")
	await key(KEY_S,false)
	await reset_actor()
	actor.get_node("Nael").rotation.y = PI
	await key(KEY_S,true)
	await create_timer(0.35).timeout
	await frames(5)
	check(absf(angle_difference(actor.get_node("Nael").rotation.y,PI))>0.5, "Holding back resumes normal walking rotation")
	await key(KEY_S,false)
	await reset_actor()
	await key(KEY_S,true);await key(KEY_S,false)
	await create_timer(0.3).timeout
	await key(KEY_S,true);await key(KEY_S,false)
	await frames(1)
	check(not dodge.active, "Slow taps remain movement")
	await reset_actor()
	actor.position.y = 4
	await frames(2)
	check(not dodge.start("move_left"), "Airborne dodge rejected")
	await reset_actor()
	actor.swimming = true
	check(not dodge.start("move_left"), "Swimming dodge rejected")
	actor.swimming=false
	actor.rest_state="sitting"
	check(not dodge.start("move_left"), "Resting dodge rejected")
	actor.rest_state=""
	var inv = root.get_node("Inventory")
	inv.is_open=true
	check(not dodge.start("move_left"), "Inventory blocks dodge")
	inv.is_open=false
	dodge.start("move_left")
	inv.is_open=true
	await frames(2)
	check(not dodge.active, "Inventory cancels maneuver")
	inv.is_open=false
	await reset_actor()
	dodge.start("move_left")
	await frames(10)
	actor.damage_invulnerability=0
	var health: float = actor.health
	actor.take_damage(10,Vector3.RIGHT)
	check(actor.health==health, "Sidestep protects during its evasive phase")
	await frames(10)
	actor.take_damage(10,Vector3.RIGHT)
	check(actor.health==health-10 and not dodge.active, "Recovery vulnerable and hit cancels dodge")
	await reset_actor()
	var back_wall := box(Vector3(0,1,1.2), Vector3(4,3,0.2))
	dodge.start("move_backward")
	await frames(30)
	check(actor.position.z < 0.85, "Faster backstep cannot cross a wall")
	back_wall.queue_free()
	for side in ["move_left", "move_right"]:
		await reset_actor()
		var sign_x := -1.0 if side == "move_left" else 1.0
		var side_wall := box(Vector3(sign_x * 0.9, 1, 0), Vector3(0.2, 3, 4))
		dodge.start(side)
		await frames(62)
		check(absf(actor.position.x) < 0.65, side+" cannot cross a wall")
		side_wall.queue_free()
	await reset_actor()
	var wall := box(Vector3(0,1,-1.2),Vector3(4,3,0.2))
	dodge.start("move_forward")
	await frames(32)
	check(actor.position.z > -0.85, "Charge cannot cross a wall")
	wall.queue_free()
	await reset_actor()
	enemy=load("res://scenes/bandit.tscn").instantiate()
	enemy.position=Vector3(0,0,-1.1)
	level.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.combat.set_physics_process(false)
	await frames(2)
	dodge.start("move_forward")
	await frames(24)
	check(enemy.health == 85, "Charge deals exactly 15 damage once")
	check(enemy.get_meta("hit_recoil",Vector3.ZERO).z < -8, "Charge pushes enemy forward")
	await frames(24)
	check(enemy.health == 85, "Remaining charge frames do not repeat damage")
	await reset_actor()
	enemy.position=Vector3(0,0,-1.6)
	wall=box(Vector3(0,1,-0.8),Vector3(4,3,0.1))
	await frames(2)
	dodge.start("move_forward")
	await frames(40)
	check(enemy.health==85, "Wall blocks charge damage")
	wall.queue_free()
	await reset_actor()
	actor.pivot.rotation.y=PI/2
	dodge.start("move_forward")
	await frames(30)
	check(actor.position.x < -1.9 and absf(actor.position.z)<0.1, "Charge follows rotated camera")
	actor.respawn()
	check(not dodge.active and dodge.pending=="", "Respawn clears maneuver and input")
	print("DODGE_RESULT: ", failures.size(), " failures")
	level.free()
	await frames(2)
	quit(0 if failures.is_empty() else 1)
