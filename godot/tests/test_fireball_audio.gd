extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("--- Debut des tests audio de la Boule de Feu (Fireball) ---")
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	var scene = load("res://scenes/player.tscn").instantiate()
	root_node.add_child(scene)
	await process_frame
	await physics_frame
	
	# 1. Verification du lecteur et de la banque de sons
	assert(scene.fireball_audio_player != null, "fireball_audio_player doit exister")
	assert(scene.fireball_audio_player.bus == "SFX", "fireball_audio_player doit etre sur le bus SFX")
	assert(scene.fireball_sounds.size() == 1, "fireball_sounds doit contenir exactement le son choisi (trouve : %d)" % scene.fireball_sounds.size())
	assert(scene.fireball_sounds[0] != null, "Le flux audio doit etre valide")
	print("PASS: fireball_audio_player configure sur le bus SFX avec fireball_court_02_souffle_eclair")
	
	# 2. Declenchement du tir
	scene.spawn_fireball()
	await process_frame
	assert(scene.fireball_audio_player.playing, "fireball_audio_player doit etre en cours de lecture apres spawn_fireball")
	assert(scene.fireball_audio_player.stream == scene.fireball_sounds[0], "Le son joue doit etre fireball_court_02_souffle_eclair")
	print("PASS: Lecture declenchee avec succes lors du tir de la boule de feu (pitch: %.3f, vol: %.2f dB)" % [
		scene.fireball_audio_player.pitch_scale,
		scene.fireball_audio_player.volume_db
	])
	
	root_node.queue_free()
	print("--- TOUS LES TESTS AUDIO BOULE DE FEU SONT VALIDES AVEC SUCCES ! ---")
	quit(0)
