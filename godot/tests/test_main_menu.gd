extends SceneTree
## Render and exercise the title flow without modifying any user's save files.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var title = current_scene
	assert(not title.menu_ready and not title.stage.visible, "Menu must stay hidden during startup")
	assert(title.loading_label.visible and title.loading_label.text == "Chargement en cours…")
	assert(not title.new_button.has_focus(), "Hidden menu must not receive keyboard focus")
	title._show_options()
	title._show_load()
	assert(not root.get_node("PauseMenu").is_open and not title.load_panel.visible)
	title.set_process(false)
	await capture("title_startup_preview.png")
	title.set_process(true)
	for i in range(600):
		await process_frame
		if title.menu_ready: break
	assert(title.camera != null, "3D landscape must finish loading")
	assert(title.menu_ready and title.stage.visible and not title.loading_label.visible, "Menu must replace the loading message after the first 3D frame")
	var music_manager = root.get_node("MusicManager")
	var title_music: AudioStreamPlayer = title.menu_music
	assert(title_music.playing, "Title music must play on the title screen")
	assert(not music_manager.player.playing and not music_manager.cave_player.playing, "Gameplay music must be stopped during title")
	var vigie = title.landscape.get_node("Vigie")
	assert(not vigie.get_node("Art").is_visible_in_tree(), "Old tower must stay hidden in the title backdrop")
	assert(vigie.get_node("RuineSommet").is_visible_in_tree(), "New summit ruin must be visible")
	assert(vigie.get_node("MarchesNaturelles").is_visible_in_tree(), "New ascent must be visible")
	await create_timer(1.3).timeout
	assert(get_nodes_in_group("player").is_empty(), "Title backdrop must not spawn gameplay")
	assert(not root.get_node("QuestManager").ui_layer.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	# A real cursor may hover another entry while the landscape loads.
	title.new_button.grab_focus()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	assert(title.menu.get_child(1).has_focus(), "Arrow keys must select menu entries")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	assert(not root.get_node("PauseMenu").is_open, "Escape on title must not open gameplay pause")
	title.new_button.grab_focus()
	await capture("title_menu_preview.png")
	title._show_options()
	var pause_menu = root.get_node("PauseMenu")
	assert(pause_menu.options_view.visible and pause_menu.from_title)
	pause_menu.show_controls_view()
	assert(pause_menu.controls_view.visible)
	pause_menu.show_options_view()
	await capture("title_options_preview.png")
	pause_menu.show_main_view()
	assert(not paused and not pause_menu.is_open and not pause_menu.from_title)
	assert(title.menu.get_child(2).has_focus())
	title._show_load()
	assert(title.load_panel.visible and not title.menu.visible)
	await capture("title_load_preview.png")
	title._close_load()
	assert(title.menu.visible and not title.load_panel.visible)
	root.size = Vector2i(960, 540)
	await process_frame
	assert(title.stage.scale.x > 0)
	root.get_node("Inventory").gold = 123
	root.get_node("Inventory").collected["story/test_title"] = true
	title._new_game()
	for i in range(600):
		await process_frame
		if current_scene and current_scene != title: break
	assert(current_scene and current_scene.scene_file_path == "res://scenes/world/open_world.tscn")
	assert(not is_instance_valid(title_music), "New Game must destroy the title music player")
	assert(music_manager.player.playing, "Gameplay music must resume after New Game")
	await process_frame
	await physics_frame
	assert(root.get_node("Inventory").gold == 0)
	assert(not root.get_node("Inventory").collected.has("story/test_title"))
	assert(get_first_node_in_group("player") != null)
	assert(root.get_node("QuestManager").ui_layer.visible)
	root.get_node("PauseMenu").open()
	assert(root.get_node("PauseMenu").main_view.visible)
	root.get_node("PauseMenu").resume()
	# A real round-trip through the title loader, using a disposable test save.
	var save_manager = root.get_node("SaveManager")
	var player = get_first_node_in_group("player")
	player.restore_health(67.0)
	root.get_node("Inventory").gold = 42
	var test_path := "user://title_menu_roundtrip_test.json"
	assert(save_manager.save_game("Title regression", test_path) == test_path)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var loader = current_scene
	for i in range(600):
		await process_frame
		if loader.menu_ready: break
	assert(loader.menu_ready, "Returning to title must wait for the backdrop too")
	var load_title_music: AudioStreamPlayer = loader.menu_music
	assert(load_title_music.playing and not music_manager.player.playing, "Returning to title must play only title music")
	loader._load_game(test_path)
	await save_manager.game_loaded
	assert(current_scene.scene_file_path == "res://scenes/world/open_world.tscn")
	assert(not is_instance_valid(load_title_music), "Loading a save must destroy the title music player")
	assert(music_manager.player.playing, "Gameplay music must resume after loading")
	assert(root.get_node("Inventory").gold == 42)
	assert(is_equal_approx(get_first_node_in_group("player").health, 67.0))
	DirAccess.remove_absolute(test_path)
	print("TITLE_MENU_TEST_OK: landscape, keyboard, options, controls, return, save round-trip, new game, HUD and pause")
	quit()

func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + file)
