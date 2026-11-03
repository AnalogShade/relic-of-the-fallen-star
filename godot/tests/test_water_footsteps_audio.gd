extends SceneTree
## Test automatisé headless pour l'audio des pas dans l'eau (pas_riviere_05_pas_eau_vive.wav avec pitch varié).

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("--- Debut des tests audio des bruits de pas dans l'eau ---")

	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 1, 24)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	world.add_child(ground)

	var water := MeshInstance3D.new()
	water.name = "Water_Test"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(6, 20)
	water.mesh = water_mesh
	water.position.y = 0.18
	world.add_child(water)

	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.43, 1)
	world.add_child(player)

	for i in range(15):
		await physics_frame
		await process_frame

	# 1. Vérifier le chargement du sample pas_riviere_05_pas_eau_vive.wav
	assert(player.water_footstep_sound != null, "pas_riviere_05_pas_eau_vive.wav doit etre charge")
	assert(player.water_footstep_players.size() == 2, "2 lecteurs polyphoniques d'eau doivent exister")
	print("PASS: Sample pas_riviere_05_pas_eau_vive.wav charge et lecteurs configures sur le bus SFX")

	# 2. Vérifier que la marche dans l'eau déclenche le sample d'eau avec un pitch différent à chaque pas
	assert(player.is_on_floor() and not player.swimming, "Le joueur doit marcher dans l'eau peu profonde (sans nager)")
	player.velocity = Vector3(2.2, 0.0, 0.0)
	var pitches: Array[float] = []
	for i in range(12):
		player._play_footstep(i % 2)
		assert(player.water_footstep_player.playing, "Le lecteur de pas dans l'eau doit jouer au pas %d" % i)
		assert(not player.footstep_player.playing, "Le son de pas sur terre seche ne doit pas jouer dans l'eau")
		assert(player.water_footstep_player.volume_db <= -16.0, "Le volume de marche dans l'eau doit etre doux (<= -16.0 dB)")
		var p: float = player.water_footstep_player.pitch_scale
		if not pitches.is_empty():
			var diff := absf(p - pitches.back())
			assert(diff >= 0.03, "Deux pas consecutifs dans l'eau doivent avoir un pitch bien distinct (diff=%.3f)" % diff)
		pitches.append(p)

	var min_p: float = pitches.min()
	var max_p: float = pitches.max()
	assert(min_p >= 0.58 and max_p <= 0.80, "Le pitch de marche dans l'eau doit etre grave et naturel (entre 0.58 et 0.80, trouve: %.3f - %.3f)" % [min_p, max_p])
	assert(max_p - min_p >= 0.06, "L'etendue des variations de pitch doit etre naturelle (min=%.3f, max=%.3f)" % [min_p, max_p])
	print("PASS: 12 pas dans l'eau verifies avec pitch abaisse (de %.3f a %.3f) et volume doux" % [min_p, max_p])

	# 3. Vérifier que la nage (swimming = true) ne déclenche PAS les bruits de pas dans l'eau
	for wp in player.water_footstep_players:
		wp.stop()
	player.swimming = true
	player._play_footstep(0)
	var any_playing := false
	for wp in player.water_footstep_players:
		if wp.playing:
			any_playing = true
	assert(not any_playing, "Aucun bruit de pas dans l'eau ne doit jouer pendant la nage")
	print("PASS: Aucun bruit de pas declenche lorsque le personnage nage")

	# 4. Vérifier le retour sur la terre sèche (hors de l'eau)
	player.swimming = false
	player.global_position.x = 8.0
	await physics_frame
	player._play_footstep(0)
	assert(player.footstep_player.playing, "Le bruit de pas standard reprend sur la terre seche")
	print("PASS: Retour au son de pas normal sur terre seche valide")

	world.free()
	await process_frame
	print("--- TOUS LES TESTS AUDIO DE PAS DANS L'EAU SONT VALIDES AVEC SUCCES ! ---")
	quit(0)
