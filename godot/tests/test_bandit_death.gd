extends SceneTree

var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var packed := load("res://scenes/bandit.tscn") as PackedScene
	var world_state := (load("res://scenes/world/open_world.tscn") as PackedScene).get_state()
	var bandits: Array[Node] = []
	for i in range(world_state.get_node_count()):
		var instance := world_state.get_node_instance(i)
		if instance != null and instance.resource_path == packed.resource_path:
			var bandit = packed.instantiate()
			bandit.name = world_state.get_node_name(i)
			bandit.position.x = bandits.size() * 4.0
			world.add_child(bandit)
			bandit.set_physics_process(false)
			bandits.append(bandit)
	check(bandits.size() == 5, "All five world bandits use the updated shared scene")
	for bandit in bandits:
		check(bandit.corpse_lifetime == 8.0, str(bandit.name) + ": default corpse hold is eight seconds")
		var skeleton := bandit.visual.find_child("Skeleton3D", true, false) as Skeleton3D
		bandit.animator.play("Idle", 0.0)
		bandit.animator.advance(0.0)
		for side in ["Left", "Right"]:
			var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Arm")).origin
			var hand := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Hand")).origin
			check(hand.y < shoulder.y - 0.35 and absf(hand.x - shoulder.x) < 0.16, str(bandit.name) + ": " + side + " arm hangs beside body")
		check(bandit.animator.get_animation("Death_Fall_Back").loop_mode == Animation.LOOP_NONE, str(bandit.name) + ": death does not loop")
		# Death must interrupt an attack that has changed playback speed.
		bandit.animator.play("Punch", 0.0, 2.5)
		bandit.animator.advance(0.1)
		bandit.corpse_lifetime = 0.5
		bandit.corpse_fade_duration = 0.15
		bandit.take_damage(10000.0, bandit.global_position + Vector3.FORWARD)
		check(bandit.health == 0.0 and bandit.visible and not bandit.is_queued_for_deletion(), str(bandit.name) + ": lethal hit leaves a visible body")
		check(bandit.state == "dead" and not bandit.is_physics_processing(), str(bandit.name) + ": dead AI stops")
		check(not bandit.is_in_group("enemies") and bandit.collision_layer == 0, str(bandit.name) + ": corpse is not a target or obstacle")
		check(bandit.animator.current_animation == "Death_Fall_Back" and is_equal_approx(bandit.animator.get_playing_speed(), 1.0), str(bandit.name) + ": attack is replaced by death at normal speed")
		bandit.animator.advance(1.0)
		bandit.animator.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		var chest := skeleton.get_bone_global_pose(skeleton.find_bone("Spine")).origin
		var foot := skeleton.get_bone_global_pose(skeleton.find_bone("LeftFoot")).origin
		check(foot.y > chest.y + 0.1, str(bandit.name) + ": extended legs stay above torso at impact")
		bandit.take_damage(10000.0, Vector3.ZERO)
		check(bandit.animator.current_animation_position > 0.9, str(bandit.name) + ": repeated hits do not restart death")
		bandit.animator.advance(2.0)
		skeleton.force_update_all_bone_transforms()
		var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
		check(hips.y < 0.4, str(bandit.name) + ": final pose lies on ground")
	await process_frame
	await process_frame
	for bandit in bandits:
		check(bandit.get_node("CollisionShape3D").disabled and not bandit.health_label.visible and not bandit.combat.status_label.visible, str(bandit.name) + ": corpse collision and combat labels disabled")
		check(not bandit.animator.is_playing(), str(bandit.name) + ": final death pose holds")
	paused = true
	await create_timer(0.7, true).timeout
	check(bandits.all(func(b): return is_instance_valid(b)), "Pause preserves corpses and pauses cleanup timers")
	paused = false
	await create_timer(0.15).timeout
	check(bandits.all(func(b): return is_instance_valid(b) and b.visible), "Bodies remain visible during corpse hold")
	await create_timer(0.65).timeout
	check(bandits.all(func(b): return not is_instance_valid(b)), "All corpses fade and are freed after hold")
	print("BANDIT_DEATH_RESULT ", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
