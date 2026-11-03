extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func run() -> void:
	var mm := root.get_node("MusicManager")
	await process_frame
	for path in ["res://scenes/interiors/cave_room.tscn", "res://scenes/interiors/cave_depths.tscn"]:
		var scene := load(path) as PackedScene
		check(scene != null and scene.get_state().get_node_groups(0).has("cave_music"), "Cave music group: " + path)
	var cave_player: AudioStreamPlayer = mm.get_node("CaveBGMPlayer")
	check(cave_player.stream is AudioStreamOggVorbis and cave_player.stream.loop, "Cave OGG loaded and loop enabled")
	check(not mm.get("_in_cave"), "Forest music initially active")
	var entrance := Node3D.new()
	entrance.add_to_group("cave_music")
	root.add_child(entrance)
	await create_timer(1.7).timeout
	check(mm.get("_in_cave") and cave_player.playing, "Entering cave starts cave music")
	check(is_equal_approx(cave_player.volume_db, -14.0), "Cave reaches configured music volume")
	check(mm.player.volume_db <= -90.0, "Forest fades out")
	var position := cave_player.get_playback_position()
	root.remove_child(entrance)
	var depths := Node3D.new()
	depths.add_to_group("cave_music")
	root.add_child(depths)
	await create_timer(0.2).timeout
	check(mm.get("_in_cave") and cave_player.get_playback_position() >= position, "Cave-to-depths preserves playback")
	mm.pause_music()
	check(cave_player.stream_paused and mm.player.stream_paused, "Pause affects both players")
	mm.resume_music()
	mm.set_volume_db(-20.0)
	check(is_equal_approx(cave_player.volume_db, -20.0), "Volume control affects cave music")
	root.remove_child(depths)
	await create_timer(1.7).timeout
	check(not mm.get("_in_cave") and not cave_player.playing, "Leaving cave stops cave after crossfade")
	check(is_equal_approx(mm.player.volume_db, -20.0), "Forest volume restored")
	root.add_child(entrance)
	await create_timer(0.2).timeout
	root.remove_child(entrance)
	await create_timer(0.2).timeout
	root.add_child(entrance)
	await create_timer(1.7).timeout
	check(mm.get("_in_cave") and cave_player.playing, "Rapid re-entry cancels old fade-out")
	mm.stop_music()
	check(not cave_player.playing and not mm.player.playing, "Stop affects both players")
	mm.play_music()
	check(cave_player.playing, "Play restarts cave music")
	root.remove_child(entrance)
	entrance.free()
	depths.free()
	print("Cave music failures: %d" % failures)
	quit(1 if failures else 0)
