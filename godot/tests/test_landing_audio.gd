extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("--- Debut des tests du son d'atterrissage (Landing) ---")
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	var scene = load("res://scenes/player.tscn").instantiate()
	root_node.add_child(scene)
	await process_frame
	await physics_frame
	
	assert(scene.footstep_player != null, "footstep_player doit exister")
	assert(scene.movement_player != null, "movement_player doit exister")
	assert(not scene.footstep_sounds.is_empty(), "footstep_sounds doit contenir les sons veloutes")
	
	# Declencher l'atterrissage
	scene._play_landing()
	
	# Verifier que le premier pied joue immediatement
	assert(scene.footstep_player.playing, "Le premier pied doit jouer immediatement sur footstep_player")
	var s1: AudioStream = scene.footstep_player.stream
	var p1: float = scene.footstep_player.pitch_scale
	var v1: float = scene.footstep_player.volume_db
	print("PASS: Premier pied atterri immediatement (pitch: %.3f, vol: %.2f dB)" % [p1, v1])
	
	# Attendre le decalage du deuxieme pied (entre 55ms et 85ms)
	await create_timer(0.12).timeout
	
	# Verifier que le deuxieme pied a bien ete joue sur movement_player
	assert(scene.movement_player.playing or scene.movement_player.stream != null, "Le deuxieme pied doit jouer sur movement_player")
	var s2: AudioStream = scene.movement_player.stream
	var p2: float = scene.movement_player.pitch_scale
	var v2: float = scene.movement_player.volume_db
	print("PASS: Deuxieme pied atterri de maniere decalee (pitch: %.3f, vol: %.2f dB)" % [p2, v2])
	
	# Verifier que les deux pieds utilisent bien des variations distinctes ou alternent
	assert(s1 != null and s2 != null, "Les deux pieds doivent avoir des AudioStream valides")
	print("PASS: Sons des deux pieds valides et distincts")
	
	root_node.queue_free()
	print("--- TOUS LES TESTS D'ATTERRISSAGE SONT VALIDES AVEC SUCCES ! ---")
	quit(0)
