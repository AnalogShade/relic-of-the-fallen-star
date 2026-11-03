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

func run() -> void:
	print("--- WORLD SFX INTEGRATION TESTS ---")

	# 1. Test Ambience assets
	var amb_paths := [
		"res://assets/audio/ambience/wind_mountain_breeze.wav",
		"res://assets/audio/ambience/wind_forest_canopy.wav",
		"res://assets/audio/ambience/leaves_rustling_gentle.wav",
		"res://assets/audio/ambience/birds_morning_chorus.wav",
		"res://assets/audio/ambience/river_stream_pebbles.wav",
		"res://assets/audio/ambience/river_waterfall_mist.wav",
	]
	for p in amb_paths:
		var ok: bool = ResourceLoader.exists(p) or FileAccess.file_exists(p)
		check(ok, "Ambience asset exists: %s" % p.get_file())

	# 2. Test Interactions assets
	var inter_paths := [
		"res://assets/audio/sfx/interactions/door_open_wood_creak_01.wav",
		"res://assets/audio/sfx/interactions/door_slam_shut_01.wav",
		"res://assets/audio/sfx/interactions/chest_open_treasure_01.wav",
		"res://assets/audio/sfx/interactions/chest_open_relic_03.wav",
	]
	for p in inter_paths:
		var ok: bool = ResourceLoader.exists(p) or FileAccess.file_exists(p)
		check(ok, "Interaction asset exists: %s" % p.get_file())

	# 3. Test Campfire 3D audio in CozyFire
	var fire = preload("res://scripts/cozy_fire.gd").new()
	root.add_child(fire)
	var fire_audio: AudioStreamPlayer3D = fire.get_node_or_null("CampfireAudio") as AudioStreamPlayer3D
	check(fire_audio != null, "CampfireAudio 3D node created in CozyFire")
	if fire_audio:
		check(fire_audio.stream != null, "CampfireAudio stream loaded successfully")
		check(fire_audio.autoplay, "CampfireAudio autoplay is enabled")
	fire.queue_free()

	# 4. Test Spider Attack sounds
	var spider_scene = load("res://scenes/araignee.tscn")
	check(spider_scene != null, "araignee.tscn scene loaded")
	if spider_scene:
		var spider = spider_scene.instantiate()
		root.add_child(spider)
		check(spider.attack_sounds.size() >= 4, "Spider has at least 4 attack sounds loaded (actual: %d)" % spider.attack_sounds.size())
		spider.queue_free()

	print("WORLD_SFX_TEST_SUMMARY: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
