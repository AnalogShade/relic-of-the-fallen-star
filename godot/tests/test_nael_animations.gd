extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
func run_tests() -> void:
	var level = load("res://scenes/forest_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var p = level.get_node("Player")
	var ap: AnimationPlayer = p.get_node("Nael/AnimationPlayer")
	var skeleton: Skeleton3D = p.get_node("Nael").find_child("Skeleton3D", true, false)
	check(skeleton != null and skeleton.get_bone_count() == 24, "24 imported bones")
	for clip in ["Nael_Idle_Breathe", "Nael_Walk", "Nael_Run", "Nael_Jump", "Nael_FrontFlip", "Nael_FrontFlip_InPlace"]:
		check(ap.has_animation(clip), "Imported " + clip)
		if ap.has_animation(clip):
			check(ap.get_animation(clip).get_track_count() > 20, "Skeletal tracks for " + clip)
	await frames(100)
	check(ap.current_animation == "Nael_Idle_Breathe", "Idle when grounded and stationary")
	var start := p.global_position as Vector3
	key(KEY_W, true)
	await frames(25)
	check(ap.current_animation == "Nael_Walk", "Walking state")
	check(p.global_position.distance_to(start) > 0.4, "Walking moves the body")
	key(KEY_SHIFT, true)
	await frames(18)
	check(ap.current_animation == "Nael_Run", "Sprinting state")
	key(KEY_SHIFT, false)
	key(KEY_W, false)
	p.respawn()
	await frames(90)
	var floor_y: float = p.global_position.y
	key(KEY_SPACE, true)
	await frames(10)
	key(KEY_SPACE, false)
	check(ap.current_animation == "Nael_Fall", "First space triggers falling loop")
	check(p.global_position.y > floor_y + 0.5, "Physics drives aerial height")
	await frames(110)
	check(p.is_on_floor(), "Landing after front flip")
	check(ap.current_animation == "Nael_Idle_Breathe", "Returns to breathing after landing")
	for clip in ["Nael_Idle_Breathe", "Nael_Walk", "Nael_Run"]:
		check(ap.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, clip + " loops")
	check(ap.get_animation("Nael_FrontFlip_InPlace").loop_mode == Animation.LOOP_NONE, "Flip does not loop")
	print("ANIMATION_TEST_RESULT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
