extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)

func run() -> void:
	var level = Node3D.new()
	root.add_child(level)
	current_scene = level
	
	var player = load("res://scenes/player.tscn").instantiate()
	level.add_child(player)
	player.set_physics_process(false)
	
	for i in range(5):
		await process_frame
	
	var trail: MeshInstance3D = player.get_node_or_null("ClawTrail")
	check(trail != null, "ClawTrail node exists in player scene")
	check(trail.has_method("start_trail"), "ClawTrail implements start_trail")
	check(trail.has_method("stop_trail"), "ClawTrail implements stop_trail")
	check(trail.has_method("clear_trail"), "ClawTrail implements clear_trail")
	check(trail.has_method("burst"), "ClawTrail implements burst")
	check(trail.bone_name == "RightHand", "ClawTrail tracks RightHand bone by default")
	check(trail.trail_gradient != null, "ClawTrail has a stylized mauve gradient initialized")
	check(trail._skeleton != null, "ClawTrail automatically resolves Skeleton3D")
	check(trail._bone_idx >= 0, "ClawTrail finds valid RightHand bone index")
	
	# Test manual burst
	trail.burst(0.2)
	check(trail.emitting, "Burst activates trail emission")
	
	# Test point generation during hand motion (needs >= 2 slices to form ribbon quads)
	var ap: AnimationPlayer = player.get_node("Nael/AnimationPlayer")
	ap.play("Nael_Claw")
	ap.seek(0.20, true)
	await process_frame
	ap.seek(0.28, true)
	await process_frame
	
	check(trail._slices.size() >= 2, "Trail samples multiple slices during animation motion")
	check(trail._immediate_mesh.get_surface_count() > 0, "Trail mesh generates visible ribbon surfaces")
	
	# Test clear trail
	trail.clear_trail()
	check(trail._slices.is_empty(), "clear_trail empties slice history")
	check(trail._immediate_mesh.get_surface_count() == 0, "clear_trail clears all mesh surfaces")
	
	# Test preset switching
	trail.preset_mode = trail.PresetMode.QUAD_CLAW
	trail.burst(0.2)
	ap.seek(0.30, true)
	await process_frame
	check(trail._slices.size() > 0 and trail._slices[0].claw_tips.size() == 4, "QUAD_CLAW generates 4 claw tips")
	
	trail.preset_mode = trail.PresetMode.SINGLE_BLADE
	trail.clear_trail()
	trail.burst(0.2)
	ap.seek(0.35, true)
	await process_frame
	check(trail._slices.size() > 0 and trail._slices[0].claw_tips.size() == 1, "SINGLE_BLADE generates 1 blade tip")
	
	trail.preset_mode = trail.PresetMode.TRIPLE_CLAW
	trail.clear_trail()
	
	# Test integration with player cancel_claw
	player.is_attacking = true
	trail.burst(0.3)
	await process_frame
	player.cancel_claw()
	check(not player.is_attacking, "Player cancel_claw resets attacking state")
	check(trail._slices.is_empty(), "Player cancel_claw cleans up claw trail slices")
	
	print("CLAW_TRAIL_TEST_RESULT: %d failures" % failures.size())
	player.free()
	level.free()
	quit(0 if failures.is_empty() else 1)
