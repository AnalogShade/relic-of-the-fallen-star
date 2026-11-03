extends SceneTree

var failures: Array[String] = []
var actor: CharacterBody3D
var animator: AnimationPlayer

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)

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
	for clip in ["Nael_Idle_Breathe", "Nael_Walk", "Nael_Run", "Nael_Jump", "Nael_Jump_InPlace", "Nael_FrontFlip", "Nael_FrontFlip_InPlace", "Nael_Glide", "Nael_Fall"]:
		check(animator.has_animation(clip), "Original animation preserved: " + clip)
	var fall := animator.get_animation("Nael_Fall")
	# The existing export convention retains frame 1 at t=1/30, ending at frame 45.
	check(is_equal_approx(fall.length, 45.0 / 30.0), "New Blender fall duration: 1.5 seconds")
	check(fall.loop_mode == Animation.LOOP_LINEAR, "New fall loops")
	check(animator.current_animation == "Nael_Idle_Breathe", "Grounded idle")
	Input.action_press("move_forward")
	await frames(20)
	check(animator.current_animation == "Nael_Walk", "Walking preserved")
	Input.action_press("sprint")
	await frames(10)
	check(animator.current_animation == "Nael_Run", "Running preserved")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	Input.action_press("jump")
	await frames(5)
	Input.action_release("jump")
	check(animator.current_animation == "Nael_Fall", "First jump uses falling loop")
	var first_height: float = actor.position.y
	await frames(2)
	Input.action_press("jump")
	await frames(4)
	check(actor.air_jump_used and actor.velocity.y > 5.0, "Second press gives upward impulse")
	check(actor.position.y > first_height, "Air jump raises the body")
	check(animator.current_animation == "Nael_FrontFlip_InPlace", "Air jump plays front flip")
	Input.action_release("jump")
	await frames(2)
	var before_third: float = actor.velocity.y
	Input.action_press("jump")
	await frames(2)
	check(actor.velocity.y < before_third, "Third press cannot add another jump")
	Input.action_release("jump")
	actor.position.y = 20
	await frames(70)
	check(animator.current_animation == "Nael_Fall", "Finished flip transitions to replaced fall")
	actor.position.y = 20
	actor.velocity = Vector3.ZERO
	await frames(12)
	check(animator.current_animation == "Nael_Fall", "Free fall uses replaced clip")
	Input.action_press("jump")
	await frames(15)
	check(actor.gliding and animator.current_animation == "Nael_Glide", "Glide preserved")
	Input.action_release("jump")
	await frames(15)
	check(not actor.gliding and animator.current_animation == "Nael_Fall", "Releasing glide uses replaced fall")
	await frames(160)
	check(actor.is_on_floor() and animator.current_animation == "Nael_Idle_Breathe", "Landing restores idle")
	check(not actor.air_jump_used, "Landing restores air jump")
	print("FALL_REPLACEMENT_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
