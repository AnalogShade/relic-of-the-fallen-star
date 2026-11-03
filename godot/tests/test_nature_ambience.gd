extends SceneTree
## Test automatisé headless pour l'ambiance du ruisseau spatialisé et des oiseaux procéduraux.

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("--- Debut des tests de Nature Ambience (Ruisseau & Oiseaux) ---")
	
	# 1. Test du StreamAudioEmitter (Ruisseau 3D suiveur)
	var stream_emitter := preload("res://scripts/stream_audio_emitter.gd").new()
	root.add_child(stream_emitter)
	await process_frame
	await physics_frame
	
	var river_player: AudioStreamPlayer3D = stream_emitter.audio_player
	assert(river_player != null, "AudioStreamPlayer3D pour le ruisseau doit exister")
	assert(river_player.bus == "River", "Le ruisseau doit etre sur le bus River")
	assert(river_player.stream != null, "Le flux audio du ruisseau doit etre charge")
	
	# Verification de l'effet de Reverb sur le bus River
	var river_bus_idx := AudioServer.get_bus_index("River")
	assert(river_bus_idx != -1, "Le bus River doit exister dans l'AudioServer")
	var has_reverb := false
	for i in range(AudioServer.get_bus_effect_count(river_bus_idx)):
		if AudioServer.get_bus_effect(river_bus_idx, i) is AudioEffectReverb:
			has_reverb = true
			break
	assert(has_reverb, "Le bus River doit contenir un AudioEffectReverb pour la reverberation subtile")
	print("PASS: Bus River avec Reverb subtile verifie")
	
	if river_player.stream is AudioStreamWAV:
		var wav := river_player.stream as AudioStreamWAV
		assert(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Le ruisseau doit etre configure en LOOP_FORWARD (continu, pas de fade)")
		print("PASS: Le son du ruisseau est loopable sans interruption (LOOP_FORWARD)")
	
	# Verification de la spatialisation gauche / droite
	# Creer un joueur factice
	var dummy_player := Node3D.new()
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)
	
	# Joueur situe a l'Est du ruisseau (X = 12.0, Z = 0.0) sur la berge
	dummy_player.global_position = Vector3(12.0, 0.5, 0.0)
	for i in range(15):
		stream_emitter._process(0.1)
	var stream_pos_east := river_player.global_position
	var vol_on_bank := river_player.volume_db
	assert(stream_pos_east.x < dummy_player.global_position.x, "Quand le joueur est a droite/Est, le ruisseau est sur sa GAUCHE")
	print("PASS: Spatialisation gauche verifiee (joueur a l'Est, ruisseau a gauche: diff_x = %.2f, volume berge = %.1f dB)" % [stream_pos_east.x - dummy_player.global_position.x, vol_on_bank])
	
	# Joueur situe a l'Ouest du ruisseau (X = -12.0, Z = 0.0)
	dummy_player.global_position = Vector3(-12.0, 0.5, 0.0)
	for i in range(15):
		stream_emitter._process(0.1)
	var stream_pos_west := river_player.global_position
	assert(stream_pos_west.x > dummy_player.global_position.x, "Quand le joueur est a gauche/Ouest, le ruisseau est sur sa DROITE")
	print("PASS: Spatialisation droite verifiee (joueur a l'Ouest, ruisseau a droite: diff_x = %.2f)" % (stream_pos_west.x - dummy_player.global_position.x))
	
	# Joueur situe DIRECTEMENT dans le lit du ruisseau (X = stream_pos_east.x, Z = 0.0)
	dummy_player.global_position = Vector3(stream_pos_east.x, 0.04, 0.0)
	for i in range(25):
		stream_emitter._process(0.1)
	var vol_in_stream := river_player.volume_db
	assert(vol_in_stream < vol_on_bank - 1.5, "Le volume dans le lit du ruisseau (%.1f dB) doit etre inferieur au volume sur la berge (%.1f dB)" % [vol_in_stream, vol_on_bank])
	print("PASS: Attenuation legere du volume dans le lit du ruisseau verifiee (%.1f dB -> %.1f dB)" % [vol_on_bank, vol_in_stream])
	
	# 2. Test du ForestBirdsAmbience (Oiseaux proceduraux)
	var birds_ambience := preload("res://scripts/forest_birds_ambience.gd").new()
	root.add_child(birds_ambience)
	await process_frame
	
	var birds_player: AudioStreamPlayer3D = birds_ambience.audio_player
	assert(birds_player != null, "AudioStreamPlayer3D pour les oiseaux doit exister")
	assert(birds_player.bus == "SFX", "Les oiseaux doivent etre sur le bus SFX")
	assert(birds_ambience.bird_streams.size() == 5, "Les 5 variations de chants d'oiseaux doivent etre chargees (trouve : %d)" % birds_ambience.bird_streams.size())
	print("PASS: 5/5 variations de chants d'oiseaux correctement chargees")
	
	# Nettoyage
	stream_emitter.queue_free()
	birds_ambience.queue_free()
	dummy_player.queue_free()
	
	print("--- TOUS LES TESTS D'AMBIANCE NATURE SONT VALIDES AVEC SUCCES ! ---")
	quit(0)
