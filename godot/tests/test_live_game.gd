extends SceneTree

func _initialize() -> void:
	call_deferred("run_live_test")

func run_live_test() -> void:
	print("=== Lancement reel du jeu (open_world.tscn) avec le moteur audio ===")
	
	# Chargement de la scene principale du jeu
	var res := change_scene_to_file("res://scenes/world/open_world.tscn")
	if res != OK:
		print("Erreur de chargement de la scene : ", res)
		quit(1)
		return

	# Laisser le jeu tourner pendant plusieurs secondes en observant la musique
	var frames_total := 180 # ~3 secondes a 60 FPS
	for f in range(frames_total):
		await process_frame
		
		# Afficher l'etat toutes les 30 frames (~0.5s)
		if f % 30 == 0:
			var mm: Node = root.get_node_or_null("MusicManager")
			if mm and mm.player:
				var pos: float = mm.player.get_playback_position()
				var playing: bool = mm.player.playing
				var vol: float = mm.player.volume_db
				print("[Frame %03d] Musique active: %s | Position lecture: %.2f s | Volume: %.1f dB" % [f, playing, pos, vol])
			else:
				print("[Frame %03d] En attente de l'Autoload MusicManager..." % f)

	# Capture d'ecran en direct du jeu en cours d'execution
	await RenderingServer.frame_post_draw
	var vp := root.get_viewport()
	if vp:
		var tex := vp.get_texture()
		if tex:
			var img := tex.get_image()
			if img:
				img.save_png("res://tests/live_game_with_music.png")
				print("Capture d'ecran sauvegardee dans tests/live_game_with_music.png")

	var final_mm: Node = root.get_node_or_null("MusicManager")
	if final_mm and final_mm.player and final_mm.player.playing and final_mm.player.get_playback_position() > 0.0:
		print("=== SUCCES : Le jeu tourne et la musique est activement en cours de lecture ! ===")
		quit(0)
	else:
		print("=== ATTENTION : La musique ne semble pas avoir progresse ===")
		quit(1)
