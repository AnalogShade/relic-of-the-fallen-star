extends SceneTree
## Run with --headless --path godot --script res://tests/test_pause_menu.gd.
class WorldProbe extends Node:
	var ticks := 0
	func _physics_process(_delta: float) -> void:
		ticks += 1

func _initialize() -> void:
	run.call_deferred()

func escape(echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func run() -> void:
	var menu := root.get_node("PauseMenu")
	var bag := root.get_node("Inventory")
	var audio_settings := root.get_node("AudioSettings")
	var probe := WorldProbe.new()
	root.add_child(probe)
	await physics_frame
	await process_frame
	assert(not menu.is_open and not paused)
	escape()
	assert(menu.is_open and paused and menu.visible)
	assert(menu.continue_button.has_focus())
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var ticks := probe.ticks
	await create_timer(0.1).timeout
	assert(probe.ticks == ticks, "The world must stop during pause")
	escape(true)
	assert(menu.is_open, "Key repeat must not close the menu")
	menu.continue_button.pressed.emit()
	assert(not paused and not menu.visible)
	await physics_frame
	await process_frame
	assert(probe.ticks > ticks, "Continue must resume the world")
	bag.set_open(true)
	escape()
	assert(not bag.is_open and menu.is_open and paused)
	var inventory_key := InputEventKey.new()
	inventory_key.physical_keycode = KEY_I
	inventory_key.pressed = true
	Input.parse_input_event(inventory_key)
	Input.flush_buffered_events()
	assert(not bag.is_open, "Inventory must not reopen during pause")
	escape()
	assert(not menu.is_open and not paused)
	escape()
	assert(menu.is_open and paused)

	# --- Test Options Menu ---
	print("Testing Options Menu...")
	assert(menu.options_button != null, "Options button must exist")
	menu.options_button.pressed.emit()
	assert(menu.options_view.visible, "Options view must be visible after clicking Options")
	assert(not menu.main_view.visible, "Main view must be hidden in Options")

	# Test AudioSettings initial state
	assert(audio_settings != null, "AudioSettings autoload must exist")
	var music_bus_idx := AudioServer.get_bus_index("Music")
	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	assert(music_bus_idx >= 0, "Music bus must exist")
	assert(sfx_bus_idx >= 0, "SFX bus must exist")

	# Test Music toggle
	menu.music_check.toggled.emit(false)
	assert(not audio_settings.music_enabled, "Music must be disabled in settings")
	assert(AudioServer.is_bus_mute(music_bus_idx), "Music bus must be muted")
	assert(not menu.music_slider.editable, "Music slider must be disabled when music is off")

	menu.music_check.toggled.emit(true)
	assert(audio_settings.music_enabled, "Music must be re-enabled in settings")
	assert(not AudioServer.is_bus_mute(music_bus_idx), "Music bus must not be muted")
	assert(menu.music_slider.editable, "Music slider must be enabled when music is on")

	# Test Music slider
	menu.music_slider.value_changed.emit(0.42)
	assert(is_equal_approx(audio_settings.music_volume, 0.42), "Music volume must update")
	assert(menu.music_vol_lbl.text == "42%", "Music volume label must display percentage")

	# Test SFX toggle
	menu.sfx_check.toggled.emit(false)
	assert(not audio_settings.sfx_enabled, "SFX must be disabled in settings")
	assert(AudioServer.is_bus_mute(sfx_bus_idx), "SFX bus must be muted")
	assert(not menu.sfx_slider.editable, "SFX slider must be disabled when SFX is off")

	menu.sfx_check.toggled.emit(true)
	assert(audio_settings.sfx_enabled, "SFX must be re-enabled in settings")
	assert(not AudioServer.is_bus_mute(sfx_bus_idx), "SFX bus must not be muted")
	assert(menu.sfx_slider.editable, "SFX slider must be enabled when SFX is on")

	# Test SFX slider
	menu.sfx_slider.value_changed.emit(0.75)
	assert(is_equal_approx(audio_settings.sfx_volume, 0.75), "SFX volume must update")
	assert(menu.sfx_vol_lbl.text == "75%", "SFX volume label must display percentage")

	# Test Retour button
	menu.options_back_btn.pressed.emit()
	assert(not menu.options_view.visible, "Options view must be hidden after Retour")
	assert(menu.main_view.visible, "Main view must be visible after Retour")

	# Test Escape from Options returns to main view
	menu.options_button.pressed.emit()
	assert(menu.options_view.visible)
	escape()
	assert(not menu.options_view.visible and menu.main_view.visible, "Escape from options must return to main view")

	# --- Test Commandes / Raccourcis Menu ---
	print("Testing Controls Menu...")
	menu.options_button.pressed.emit()
	assert(menu.options_view.visible)
	assert(menu.controls_button != null, "Controls button must exist in options view")
	
	menu.controls_button.pressed.emit()
	assert(menu.controls_view.visible, "Controls view must be visible after clicking controls button")
	assert(not menu.options_view.visible, "Options view must be hidden in controls view")
	assert(not menu.main_view.visible, "Main view must be hidden in controls view")
	
	# Test Retour aux options button
	assert(menu.controls_back_btn != null, "Controls back button must exist")
	menu.controls_back_btn.pressed.emit()
	assert(not menu.controls_view.visible, "Controls view must be hidden after Retour")
	assert(menu.options_view.visible, "Options view must be visible after returning from controls")
	
	# Test Escape from controls view returns to options view
	menu.controls_button.pressed.emit()
	assert(menu.controls_view.visible)
	escape()
	assert(not menu.controls_view.visible and menu.options_view.visible, "Escape from controls must return to options view")
	escape()
	assert(not menu.options_view.visible and menu.main_view.visible, "Second escape must return to main view")

	print("ALL OPTIONS, CONTROLS AND PAUSE TESTS PASSED SUCCESSFULLY!")
	quit(0)
