extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures.append(message)

func run_tests() -> void:
	print("--- Debut des tests audio MusicManager ---")

	# Test 1 : Verification du fichier MP3
	var music_path := "res://assets/audio/music/main_music.mp3"
	check(ResourceLoader.exists(music_path), "Fichier musical present dans res://assets/audio/music/main_music.mp3")

	# Test 2 : Chargement du stream
	var stream := load(music_path)
	check(stream != null, "Chargement du flux audio reussi")
	check(stream is AudioStreamMP3, "Le flux audio est bien un AudioStreamMP3")

	# Test 3 : Verification du bouclage du stream
	if stream is AudioStreamMP3:
		check(stream.loop == true, "Le parametre loop du MP3 est bien active (true)")

	# Test 4 : Verification du singleton ou de l'instance MusicManager
	var mm: Node = root.get_node_or_null("MusicManager")
	if not mm:
		# Si lance hors SceneTree standard autoload, tester le script directement
		var script_res := load("res://scripts/music_manager.gd")
		check(script_res != null, "Script music_manager.gd charge")
		mm = Node.new()
		mm.set_script(script_res)
		root.add_child(mm)

	check(mm != null, "MusicManager instancie")
	
	# Attendre une frame pour laisser _ready s'executer
	await process_frame

	var player: AudioStreamPlayer = mm.get_node_or_null("BGMPlayer")
	check(player != null, "Lecteur BGMPlayer AudioStreamPlayer present")

	if player:
		check(player.volume_db == -14.0, "Volume regle a -14.0 dB (volume doux respecte : %s dB)" % player.volume_db)
		check(player.bus == "Music", "Bus audio Music configure")
		check(player.playing == true, "La musique est en cours de lecture (playing == true)")
		check(player.finished.is_connected(mm._on_music_finished), "Signal finished connecte pour boucle continue")

	print("--- Fin des tests audio : %d echecs ---" % failures.size())
	quit(0 if failures.is_empty() else 1)
