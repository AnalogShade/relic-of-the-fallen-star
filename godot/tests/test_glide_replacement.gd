extends SceneTree

var failures: Array[String] = []
var actor: CharacterBody3D
var animator: AnimationPlayer

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level

	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	collider.position.y = -0.5
	floor_body.add_child(collider)
	level.add_child(floor_body)

	actor = load("res://scenes/player.tscn").instantiate()
	actor.position = Vector3(0, 0.5, 0)
	level.add_child(actor)
	animator = actor.get_node("Nael/AnimationPlayer")

	await frames(30)

	# 1. Check all animations are preserved
	var expected_clips := [
		"Nael_Idle_Breathe", "Nael_Walk", "Nael_Run",
		"Nael_Jump", "Nael_Jump_InPlace", "Nael_FrontFlip",
		"Nael_FrontFlip_InPlace", "Nael_Glide", "Nael_Fall", "Nael_Claw"
	]
	for clip in expected_clips:
		check(animator.has_animation(clip), "Animation present: " + clip)

	# 2. Check glide animation parameters
	var glide: Animation = animator.get_animation("Nael_Glide")
	check(is_equal_approx(glide.length, 61.0 / 30.0), "Glide duration is approx 2.033s (61 frames @ 30fps)")
	check(glide.loop_mode == Animation.LOOP_LINEAR, "Glide animation loops")
	check(glide.get_track_count() >= 20, "Glide has full skeletal tracks (%d tracks)" % glide.get_track_count())

	# 3. Dynamic animation verification: sample poses at different times in Nael_Glide
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	check(skeleton != null, "Skeleton3D found")

	animator.play("Nael_Glide")
	animator.seek(0.1, true)
	var left_arm_bone: int = skeleton.find_bone("LeftArm")
	var left_leg_bone: int = skeleton.find_bone("LeftLeg")
	var arm_rot_0: Quaternion = skeleton.get_bone_pose_rotation(left_arm_bone)
	var leg_rot_0: Quaternion = skeleton.get_bone_pose_rotation(left_leg_bone)

	animator.seek(1.0, true)
	var arm_rot_mid: Quaternion = skeleton.get_bone_pose_rotation(left_arm_bone)
	var leg_rot_mid: Quaternion = skeleton.get_bone_pose_rotation(left_leg_bone)

	var arm_movement: float = arm_rot_0.angle_to(arm_rot_mid)
	var leg_movement: float = leg_rot_0.angle_to(leg_rot_mid)
	print("Arm rotation delta: %f rad, Leg rotation delta: %f rad" % [arm_movement, leg_movement])
	check(arm_movement > 0.001 or leg_movement > 0.001, "Glide animation has dynamic limb movement")

	# 4. State machine transitions
	actor.position = Vector3(0, 0.5, 0)
	actor.velocity = Vector3.ZERO
	await frames(15)
	check(animator.current_animation == "Nael_Idle_Breathe", "Idle on ground")

	# Airborne glide activation
	actor.position.y = 20.0
	actor.velocity = Vector3.ZERO
	await frames(10)
	check(animator.current_animation == "Nael_Fall", "Airborne fall state")

	Input.action_press("jump")
	await frames(3)
	check(actor.air_jump_used and animator.current_animation == "Nael_FrontFlip_InPlace", "First airborne press triggers air jump")
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(15)
	check(actor.gliding, "Holding jump in air triggers gliding state")
	check(animator.current_animation == "Nael_Glide", "Gliding plays Nael_Glide")

	# Gliding release
	Input.action_release("jump")
	await frames(15)
	check(not actor.gliding, "Releasing jump cancels gliding")
	check(animator.current_animation == "Nael_Fall", "Cancelling glide returns to Nael_Fall")

	# Re-deploy
	Input.action_press("jump")
	await frames(15)
	check(actor.gliding and animator.current_animation == "Nael_Glide", "Re-deploying glide plays Nael_Glide")
	Input.action_release("jump")

	# Landing
	actor.position = Vector3(0, 0.5, 0)
	actor.velocity = Vector3.ZERO
	await frames(30)
	check(actor.is_on_floor(), "Player landed on floor")
	check(animator.current_animation == "Nael_Idle_Breathe", "Landing restores Nael_Idle_Breathe")

	print("GLIDE_REPLACEMENT_TEST_RESULT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
