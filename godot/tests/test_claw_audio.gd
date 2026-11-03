extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var level = Node3D.new()
	root.add_child(level)
	current_scene = level

	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50, 1, 50)
	collider.shape = shape
	floor_body.add_child(collider)
	level.add_child(floor_body)

	var actor = load("res://scenes/player.tscn").instantiate()
	level.add_child(actor)

	for i in range(10):
		await physics_frame
		await process_frame

	var player_node = actor.claw_audio_player
	assert(player_node != null, "claw_audio_player should be created")
	assert(player_node.stream != null, "claw_audio_player should have an audio stream loaded")
	print("AUDIO_STREAM_VERIFIED: ", player_node.stream, " (Length: ", player_node.stream.get_length(), "s)")

	assert(actor.start_claw(), "Claw attack should start")
	var sound_fired := false
	var animator: AnimationPlayer = actor.get_node("Nael/AnimationPlayer")

	while actor.is_attacking:
		await physics_frame
		await process_frame
		if actor.claw_sound_played:
			sound_fired = true
			print("SOUND_FIRED at anim_pos: ", animator.current_animation_position, " (Impact target: ", actor.CLAW_IMPACT_TIME, ")")
			break

	assert(sound_fired, "Claw sound should have fired during attack")
	print("CLAW_AUDIO_TEST_SUCCESS")
	quit(0)
