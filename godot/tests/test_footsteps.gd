extends SceneTree
## Test automatisé headless pour les bruits de pas (fade-in, pitch & volume aléatoire).

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("--- Debut des tests des bruits de pas (Footsteps) ---")
	
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	assert(player_scene != null, "La scene player.tscn doit exister")
	
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	await physics_frame
	
	# 1. Verification du lecteur audio des pas
	assert(player.footstep_player != null, "Le footstep_player doit etre instancie")
	assert(player.footstep_player.bus == "SFX", "Le footstep_player doit etre route sur le bus SFX")
	print("PASS: FootstepPlayer present et configure sur le bus SFX")
	
	# 2. Verification du chargement des variations de pas_terre_07_poussiere_desert
	assert(player.footstep_sounds.size() == 4, "4 variations avec fade-in doivent etre chargees (trouve : %d)" % player.footstep_sounds.size())
	for i in range(player.footstep_sounds.size()):
		assert(player.footstep_sounds[i] != null, "Variation %d doit etre un AudioStream valide" % i)
	print("PASS: 4/4 variations de pas avec fade-in doux chargees avec succes")
	
	# 3. Verification marche (pitch grave 0.78-0.88, volume doux ~ -15.8 dB)
	player.velocity = Vector3(2.0, 0.0, 0.0) # Vitesse de marche
	var walk_pitches: Array[float] = []
	var walk_volumes: Array[float] = []
	var streams_played: Array[AudioStream] = []
	for i in range(10):
		player._play_footstep()
		walk_pitches.append(player.footstep_player.pitch_scale)
		walk_volumes.append(player.footstep_player.volume_db)
		streams_played.append(player.footstep_player.stream)
		
	var min_w_pitch: float = walk_pitches.min()
	var max_w_pitch: float = walk_pitches.max()
	assert(min_w_pitch >= 0.83 and max_w_pitch <= 0.95, "Le pitch de marche doit etre doux et chaud (entre 0.84 et 0.94, trouve: %.3f - %.3f)" % [min_w_pitch, max_w_pitch])
	var avg_w_vol: float = 0.0
	for v in walk_volumes: avg_w_vol += v
	avg_w_vol /= float(walk_volumes.size())
	assert(avg_w_vol <= -17.0, "Le volume de marche doit etre tres discret (-18.0 dB, trouve : %.2f dB)" % avg_w_vol)
	print("PASS: Marche verifiee (pitch chaud: %.3f a %.3f, volume tres feutre: %.2f dB)" % [min_w_pitch, max_w_pitch, avg_w_vol])
	
	# 4. Verification course (pitch standard 0.95-1.05, volume ~ -16.0 dB)
	player.velocity = Vector3(5.0, 0.0, 0.0) # Vitesse de course
	var run_pitches: Array[float] = []
	var run_volumes: Array[float] = []
	for i in range(10):
		player._play_footstep()
		run_pitches.append(player.footstep_player.pitch_scale)
		run_volumes.append(player.footstep_player.volume_db)
		
	var min_r_pitch: float = run_pitches.min()
	var max_r_pitch: float = run_pitches.max()
	assert(min_r_pitch >= 0.94 and max_r_pitch <= 1.06, "Le pitch de course doit etre equilibre (0.95 a 1.05, trouve: %.3f - %.3f)" % [min_r_pitch, max_r_pitch])
	var avg_r_vol: float = 0.0
	for v in run_volumes: avg_r_vol += v
	avg_r_vol /= float(run_volumes.size())
	assert(avg_r_vol <= -15.0 and avg_r_vol > avg_w_vol, "Le volume de course doit etre modere (-16.0 dB, trouve : %.2f dB vs %.2f dB)" % [avg_r_vol, avg_w_vol])
	print("PASS: Course verifiee (pitch standard: %.3f a %.3f, volume adapte: %.2f dB)" % [min_r_pitch, max_r_pitch, avg_r_vol])
	
	# Verifier que l'alternance fonctionne (au moins 2 streams distincts joues sur 10 pas)
	var unique_streams := {}
	for s in streams_played:
		unique_streams[s] = true
	assert(unique_streams.size() >= 2, "Plusieurs variations doivent etre utilisees alternativement (trouve : %d)" % unique_streams.size())
	print("PASS: Alternance des variations verifiee (%d sons differents alternes)" % unique_streams.size())
	
	# 4. Verification du declenchement par deplacement
	player.step_distance = 0.0
	player.velocity = Vector3(3.0, 0.0, 0.0) # Vitesse horizontale de marche
	# Avance de 0.5s a 3.0 m/s = 1.5m (> stride de 1.25m)
	player._process_footsteps(0.5)
	assert(player.footstep_player.playing, "Le pas doit se declencher lors de la marche apres avoir depasse la foulee")
	print("PASS: Declenchement automatique lors de la marche valide")
	
	player.queue_free()
	print("--- TOUS LES TESTS DE BRUITS DE PAS SONT VALIDES AVEC SUCCES ! ---")
	quit(0)
