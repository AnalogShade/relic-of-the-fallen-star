extends Node3D
var failures: Array[String] = []
var checks := 0
var finished := false
var report := {}
var actor: CharacterBody3D
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title)
	print(("PASS " if ok else "FAIL ") + title)
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func reset_actor(height: float = 0.43) -> void:
	Input.action_release("jump")
	Input.action_release("move_forward")
	actor.global_position = Vector3(0,height,0)
	actor.velocity = Vector3.ZERO
	actor.gliding = false
	actor.jumped_this_air = false
	actor.coyote_time = 0
	actor.jump_buffer = 0
	actor.pivot.rotation.y = 0
	await frames(12 if height > 1.0 else 4)
func jump_height(speed: float) -> float:
	await reset_actor()
	await frames(35)
	actor.jump_speed = speed
	var floor_y := actor.position.y
	Input.action_press("jump")
	var top := floor_y
	for i in range(65):
		await frames(1)
		top = maxf(top, actor.position.y)
	Input.action_release("jump")
	check(not actor.gliding, "Holding the first jump does not deploy glide")
	return top - floor_y
func _ready() -> void:
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100,1,100)
	col.shape = shape
	col.position.y = -0.5
	floor.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.position.y = -0.5
	floor.add_child(mesh)
	add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.5
	add_child(sun)
	actor = preload("res://scenes/player.tscn").instantiate()
	actor.position = Vector3(0,0.45,0)
	add_child(actor)
	await frames(45)
	var animator: AnimationPlayer = actor.get_node("Nael").animator
	check(animator.has_animation("Nael_Glide") and animator.has_animation("Nael_Fall"), "New aerial animations imported")
	check(is_equal_approx(actor.speed,2.16), "Walking speed increased by eight percent")
	var low := await jump_height(6.5)
	var high := await jump_height(6.88)
	var ratio := high / low
	check(ratio > 1.10 and ratio < 1.15, "Measured jump height increases by ten to fifteen percent")
	await reset_actor(8)
	Input.action_press("jump")
	await frames(25)
	check(actor.gliding, "New airborne Space press deploys glide")
	check(actor.velocity.y >= -1.31 and actor.velocity.y < 0, "Gliding descends slowly without gaining height")
	check(animator.current_animation == "Nael_Glide", "Glide pose plays")
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	var torso_axis := (skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin - skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin).normalized()
	check(absf(torso_axis.y) < 0.10, "Glide body is horizontal")
	for side in ["Left", "Right"]:
		var fore := skeleton.get_bone_global_pose(skeleton.find_bone(side + "ForeArm")).basis.y.normalized()
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Hand")).basis.y.normalized()
		check(fore.dot(hand) > 0.99, side + " wrist aligns with forearm")
	var glide_y := actor.position.y
	await frames(60)
	check(actor.position.y < glide_y and actor.position.y > glide_y - 1.5, "Sustained glide loses about 1.3 metres per second")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/nael_glide.png")
	Input.action_release("jump")
	await frames(8)
	check(not actor.gliding and actor.velocity.y < -2.5, "Releasing Space resumes gravity")
	check(animator.current_animation == "Nael_Fall", "Release uses the falling pose instead of idle")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/nael_fall.png")
	Input.action_press("jump")
	await frames(10)
	check(actor.gliding, "Space can redeploy the glide during the same fall")
	await frames(250)
	check(actor.is_on_floor() and not actor.gliding, "Landing cancels glide even while Space is held")
	check(animator.current_animation == "Nael_Idle_Breathe", "Landing returns to grounded animation")
	await reset_actor()
	await frames(30)
	Input.action_press("jump")
	await frames(5)
	Input.action_release("jump")
	await frames(3)
	var up_before := actor.velocity.y
	Input.action_press("jump")
	await frames(2)
	check(actor.gliding and actor.velocity.y < up_before, "Second jump press deploys without an upward double-jump impulse")
	actor.respawn()
	check(not actor.gliding, "Respawn resets glide state")
	Input.action_release("jump")
	report = {"checks":checks,"failures":failures,"old_jump_height":low,"new_jump_height":high,"height_ratio":ratio}
	var file := FileAccess.open("res://tests/glide_validation_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	finished = true
	print("GLIDE_VALIDATION " + JSON.stringify(report))
