extends SceneTree

var failures: Array[String] = []

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		print("FAIL: ", msg)
		failures.append(msg)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func run() -> void:
	print("--- SFX INTEGRATION TESTS ---")

	# 1. SurfaceDetector tests
	var pos_gravel := Vector3(-56.0, 0.0, 5.0) # On known trail vertex
	var surf_gravel = SurfaceDetector.get_surface_at(pos_gravel)
	check(surf_gravel == SurfaceDetector.SurfaceType.GRAVEL, "SurfaceDetector identifies trail as GRAVEL")

	var pos_grass := Vector3(0.0, 0.0, 50.0) # Off-trail meadow
	var surf_grass = SurfaceDetector.get_surface_at(pos_grass)
	check(surf_grass == SurfaceDetector.SurfaceType.GRASS, "SurfaceDetector identifies ground as GRASS")

	# 2. Player SFX nodes & streams test
	var level = Node3D.new()
	root.add_child(level)
	current_scene = level

	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	floor_body.add_child(collider)
	level.add_child(floor_body)

	var actor = load("res://scenes/player.tscn").instantiate()
	actor.position = Vector3(0, 0.5, 0)
	level.add_child(actor)

	await frames(10)

	check(actor.claw_audio_player != null, "claw_audio_player exists")
	check(actor.footstep_player != null, "footstep_player exists")
	check(actor.movement_player != null, "movement_player exists")
	check(actor.voice_player != null, "voice_player exists")

	check(not actor.steps_twigs.is_empty(), "steps_twigs loaded (%d sounds)" % actor.steps_twigs.size())
	check(not actor.steps_grass.is_empty(), "steps_grass loaded (%d sounds)" % actor.steps_grass.size())
	check(not actor.steps_gravel.is_empty(), "steps_gravel loaded (%d sounds)" % actor.steps_gravel.size())
	check(not actor.claw_sounds.is_empty(), "claw_sounds loaded (%d sounds)" % actor.claw_sounds.size())
	check(not actor.voice_attack_sounds.is_empty(), "voice_attack_sounds loaded (%d sounds)" % actor.voice_attack_sounds.size())
	check(not actor.voice_damage_sounds.is_empty(), "voice_damage_sounds loaded (%d sounds)" % actor.voice_damage_sounds.size())
	check(not actor.voice_jump_sounds.is_empty(), "voice_jump_sounds loaded (%d sounds)" % actor.voice_jump_sounds.size())
	check(not actor.voice_land_sounds.is_empty(), "voice_land_sounds loaded (%d sounds)" % actor.voice_land_sounds.size())
	check(actor.jump_sound != null, "jump_sound loaded")
	check(actor.land_twigs != null, "land_twigs loaded")
	check(actor.land_grass != null, "land_grass loaded")
	check(actor.land_gravel != null, "land_gravel loaded")

	# 3. Test footstep trigger on locomotion
	actor.velocity = Vector3(3.0, 0.0, 0.0)
	actor._process_footsteps(0.2)
	check(actor.step_distance > 0.0, "Footstep accumulator advances on motion")
	actor._process_footsteps(0.6) # Exceeds stride (1.25m) -> triggers footstep sound!
	check(actor.footstep_player.playing, "Footstep sound triggers upon completing stride")

	# 4. Test jump sound & voice
	actor._play_jump()
	check(actor.movement_player.playing, "Jump sound triggered successfully")
	check(actor.voice_player.playing, "Jump voice grunt triggered successfully")

	# 5. Test landing sound & voice
	actor._play_landing()
	check(actor.movement_player.playing, "Landing sound triggered successfully")
	check(actor.voice_player.playing, "Landing voice grunt triggered successfully")

	# 6. Test damage voice reaction
	actor.take_damage(10.0, Vector3.ZERO)
	check(actor.voice_player.playing, "Damage voice grunt triggered on take_damage")

	# 7. Test claw swipe trigger & attack voice
	actor.start_claw()
	check(actor.voice_player.playing, "Attack voice grunt triggered on start_claw")
	while actor.is_attacking:
		await frames(1)
		if actor.claw_sound_played:
			break
	check(actor.claw_sound_played, "Claw swipe sound played during attack animation")

	var f := FileAccess.open("res://tests/test_results.txt", FileAccess.WRITE)
	if f:
		f.store_string("SFX_TEST_SUMMARY: %d failures\n" % failures.size())
		for msg in failures:
			f.store_string("FAIL: %s\n" % msg)
		f.close()
	print("SFX_TEST_SUMMARY: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
