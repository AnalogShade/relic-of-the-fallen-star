extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_test")
func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok: failures.append(text)
func run_test() -> void:
	var level = load("res://scenes/forest_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var rabbit = level.get_node("ForestRabbit")
	var ap: AnimationPlayer = rabbit.get_node("Model").find_child("AnimationPlayer", true, false)
	for clip in ["Rabbit_Idle", "Rabbit_Hop", "Rabbit_Sniff", "Rabbit_Graze"]:
		check(ap.has_animation(clip), "Imported " + clip)
		if ap.has_animation(clip):
			check(ap.get_animation(clip).get_track_count() > 10, "Skeletal tracks " + clip)
	var seen := {}
	var origin: Vector3 = rabbit.global_position
	var max_distance := 0.0
	var low_y := 100.0
	var grounded := 0
	for i in range(2400):
		await physics_frame
		seen[rabbit.state] = true
		var d := Vector2(rabbit.global_position.x - origin.x, rabbit.global_position.z - origin.z).length()
		max_distance = maxf(max_distance, d)
		if i > 90:
			low_y = minf(low_y, rabbit.global_position.y)
			if rabbit.is_on_floor(): grounded += 1
	for state in ["idle", "hop", "sniff", "graze"]:
		check(seen.has(state), "Autonomous state " + state)
	check(max_distance > 0.25, "Rabbit travels through the forest")
	check(max_distance < rabbit.roam_radius + 0.15, "Rabbit stays in safe roaming area")
	check(low_y > 0.0 and grounded > 2100, "Ground contact maintained")
	print("RABBIT_DISTANCE: ", max_distance)
	print("RABBIT_TEST_RESULT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
