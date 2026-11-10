extends Node3D
## Standalone title scene: the landscape has no actors, gameplay scripts or HUD.
const WORLD := "res://scenes/world/open_world.tscn"
const TITLE_FONT = preload("res://assets/ui/title/CinzelDecorative-Bold.ttf")
const MENU_FONT = preload("res://assets/ui/title/Cinzel.ttf")
const PAPER = preload("res://assets/ui/title/parchment.svg")
const GOLD := Color("edcf8d")
var camera: Camera3D
var landscape: Node3D
var stage: Control
var loading_label: Label
var menu: VBoxContainer
var load_panel: PanelContainer
var load_list: VBoxContainer
var new_button: Button
var status: Label
var fade: ColorRect
var elapsed := 0.0
var busy := false
var backdrop_pending := true
var startup_presented := false
var menu_ready := false
var hidden_layers: Array[CanvasLayer] = []
var previous_modes: Dictionary = {}
var menu_music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_menu_music()
	_suspend_game_ui()
	_build_ui()
	get_viewport().size_changed.connect(_resize)
	_resize()
	PauseMenu.title_options_closed.connect(_options_closed)
	ResourceLoader.load_threaded_request(WORLD)
	# Present the loading screen before scene instantiation can block the main thread.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	startup_presented = true

func _suspend_game_ui() -> void:
	for singleton in [Inventory, QuestManager]:
		previous_modes[singleton] = singleton.process_mode
		singleton.process_mode = Node.PROCESS_MODE_DISABLED
		for child in singleton.find_children("*", "CanvasLayer", true, false):
			if child.visible:
				hidden_layers.append(child)
				child.hide()

func _exit_tree() -> void:
	# This scene owns its music; it must never survive a new/load transition.
	if is_instance_valid(menu_music): menu_music.stop()
	if is_instance_valid(MusicManager): MusicManager.play_music()
	for singleton in previous_modes:
		if is_instance_valid(singleton): singleton.process_mode = previous_modes[singleton]
	for child in hidden_layers:
		if is_instance_valid(child): child.show()

func _start_menu_music() -> void:
	MusicManager.stop_music()
	menu_music = AudioStreamPlayer.new()
	menu_music.name = "TitleMusic"
	menu_music.bus = "Music"
	menu_music.stream = MusicManager.music_stream
	menu_music.volume_db = MusicManager.get_volume_db()
	add_child(menu_music)
	menu_music.play()

func _process(delta: float) -> void:
	elapsed += delta
	if backdrop_pending and startup_presented:
		var load_status := ResourceLoader.load_threaded_get_status(WORLD)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			backdrop_pending = false
			_build_landscape(ResourceLoader.load_threaded_get(WORLD) as PackedScene)
			_reveal_menu()
		elif load_status == ResourceLoader.THREAD_LOAD_FAILED or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			backdrop_pending = false
			loading_label.text = "Le décor n’a pas pu être chargé. Veuillez relancer le jeu."
	if camera:
		camera.position = Vector3(38.0 + sin(elapsed * 0.035) * 5.0, 28.0 + sin(elapsed * 0.06), 62.0)
		camera.look_at(Vector3(-23.0, 7.0, -40.0))
	stage.queue_redraw()

func _reveal_menu() -> void:
	# Keep the loading message until the camera's first 3D frame has been drawn.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var preview := preload("res://scenes/spells/fireball_projectile.tscn").instantiate()
		await preview.warm_up(self)
	else:
		await get_tree().process_frame
	loading_label.hide()
	stage.show()
	menu_ready = true
	new_button.grab_focus()

func _build_landscape(packed: PackedScene) -> void:
	landscape = packed.instantiate() as Node3D
	# The playable scene normally selects the replacement tower in _ready().
	# Apply its visual selection before removing scripts from the title backdrop.
	var vigie := landscape.get_node_or_null("Vigie")
	if vigie:
		preload("res://scripts/vigie_ascent.gd").apply_visuals(vigie, true)
	_strip_gameplay(landscape)
	preload("res://scripts/world_legacy_cleanup.gd").apply(landscape)
	preload("res://scripts/castle_moat_cleanup.gd").apply(landscape)
	add_child(landscape)
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://shaders/world_ground.gdshader")
	preload("res://scripts/hybrid_grass_material.gd").configure(ground)
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/water.gdshader")
	for mesh in landscape.find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		if label.begins_with("Terrain") or label.begins_with("CastleGround"):
			mesh.material_override = ground
		elif label.begins_with("Water"):
			mesh.material_override = water
		elif label.begins_with("Ripples") or label.begins_with("Paths"):
			mesh.hide()
	var world_environment := landscape.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment and world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate(true)
		world_environment.environment.fog_density = 0.0018
	var sun := landscape.find_child("Sun", true, false) as DirectionalLight3D
	if sun:
		sun.light_energy = 0.75
		sun.light_color = Color("ffe4b0")
	camera = Camera3D.new()
	camera.far = 1800.0
	camera.fov = 57.0
	add_child(camera)
	camera.make_current()

func _strip_gameplay(node: Node) -> void:
	# Strip BEFORE entering the tree, so no actor or quest _ready() can run.
	node.set_script(null)
	for group in node.get_groups(): node.remove_from_group(group)
	for child in node.get_children():
		if child is CanvasLayer or child is CharacterBody3D or child is Area3D or child is CollisionObject3D or child is CollisionShape3D or child is Camera3D or child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			child.free()
		else:
			_strip_gameplay(child)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){float left=1.0-smoothstep(0.12,0.83,UV.x); float edge=smoothstep(0.23,0.78,length((UV-vec2(0.5))*vec2(0.8,1.0))); COLOR=vec4(vec3(0.025,0.045,0.047),clamp(left*0.68+edge*0.52,0.0,0.88));}"
	material.shader = shader
	backdrop.material = material
	layer.add_child(backdrop)
	stage = Control.new()
	stage.name = "TitleArtwork"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1280, 720)
	stage.hide()
	layer.add_child(stage)
	stage.draw.connect(_draw_magic)
	var title := _label("Relic", 78, GOLD, TITLE_FONT)
	_place(title, Rect2(35, 105, 620, 105))
	var subtitle := _label("of the Fallen Star", 29, GOLD, TITLE_FONT)
	_place(subtitle, Rect2(35, 205, 620, 48))
	var chapter := _label("L ’ É C H O   D E S   É T O I L E S", 12, Color("c2c8b5"))
	_place(chapter, Rect2(35, 259, 620, 25))
	var paper := TextureRect.new()
	paper.texture = PAPER
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(paper, Rect2(88, 292, 520, 365))
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	_place(menu, Rect2(167, 365, 362, 196))
	new_button = _menu_button("Nouvelle partie", _new_game)
	menu.add_child(new_button)
	menu.add_child(_menu_button("Charger une partie", _show_load))
	menu.add_child(_menu_button("Options", _show_options))
	menu.add_child(_menu_button("Quitter", func(): get_tree().quit()))
	status = _label("Une étoile s’éteint. Une légende s’éveille.", 14, Color("d4d0b6"))
	_place(status, Rect2(30, 659, 640, 30))
	var hint := _label("↑ ↓  Choisir     ·     Entrée  Confirmer", 12, Color("9daea6"))
	_place(hint, Rect2(30, 693, 640, 22))
	var location := _label("F O R Ê T   D E S   L U E U R S", 13, Color("e0d9b7"))
	_place(location, Rect2(820, 647, 400, 28))
	var tagline := _label("Là où les fragments du ciel sommeillent…", 12, Color("b2c4b8"))
	_place(tagline, Rect2(820, 678, 400, 25))
	_build_load_panel()
	loading_label = _label("Chargement en cours…", 30, GOLD)
	loading_label.name = "LoadingLabel"
	layer.add_child(loading_label)
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _place(control: Control, rect: Rect2) -> void:
	stage.add_child(control)
	control.position = rect.position
	control.size = rect.size

func _label(text: String, font_size: int, color: Color, font: Font = MENU_FONT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.015, 0.025, 0.025, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 3 if font_size > 26 else 1)
	label.add_theme_constant_override("shadow_outline_size", 1 if font_size > 26 else 0)
	return label

func _menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("49321e"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.65, 0.43, 0.17, 0.19)
	hover.border_color = Color(0.48, 0.31, 0.13, 0.45)
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(action)
	button.focus_entered.connect(func(): button.text = "✦  " + text + "  ✦")
	button.focus_exited.connect(func(): button.text = text)
	button.mouse_entered.connect(button.grab_focus)
	return button

func _build_load_panel() -> void:
	load_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("162725")
	style.border_color = Color("b89551")
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	load_panel.add_theme_stylebox_override("panel", style)
	_place(load_panel, Rect2(100, 300, 495, 347))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	load_panel.add_child(column)
	column.add_child(_label("Reprendre l’aventure", 23, GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 204
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	load_list = VBoxContainer.new()
	load_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_list.add_theme_constant_override("separation", 8)
	scroll.add_child(load_list)
	var back := PauseMenu.make_button("Retour", Inventory.ui, 16, 40)
	back.pressed.connect(_close_load)
	column.add_child(back)
	load_panel.hide()

func _show_load() -> void:
	if busy or not menu_ready: return
	menu.hide()
	load_panel.show()
	for child in load_list.get_children():
		load_list.remove_child(child)
		child.queue_free()
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		var empty := _label("Aucune sauvegarde pour le moment.\nVotre légende reste à écrire.", 16, Color("d6c8a4"))
		empty.custom_minimum_size.y = 160
		load_list.add_child(empty)
	for save in saves:
		var text := "%s\n%s · %s" % [str(save.get("save_name", "Aventure")).left(35), str(save.get("location_name", "Forêt des lueurs")).left(32), save.get("datetime_string", "")]
		var button := PauseMenu.make_button(text, Inventory.ui, 14, 66)
		button.pressed.connect(_load_game.bind(str(save.file_path)))
		load_list.add_child(button)
	if load_list.get_child_count() > 0 and load_list.get_child(0) is Button:
		load_list.get_child(0).grab_focus()
	else:
		load_panel.get_child(0).get_child(2).grab_focus()

func _close_load() -> void:
	if busy or not menu_ready: return
	load_panel.hide()
	menu.show()
	menu.get_child(1).grab_focus()

func _show_options() -> void:
	if busy or not menu_ready: return
	PauseMenu.open_title_options()

func _options_closed() -> void:
	menu.get_child(2).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if busy or not menu_ready or PauseMenu.is_open: return
	if event.is_action_pressed("ui_cancel") and load_panel.visible:
		_close_load()
		get_viewport().set_input_as_handled()

func _new_game() -> void:
	if busy or not menu_ready: return
	busy = true
	status.text = "L’aventure commence…"
	await _fade_out()
	# The launcher's New Game never overwrites existing saves.
	Inventory.stacks.clear()
	Inventory.equipment.clear()
	Inventory.collected.clear()
	Inventory.equipped = ""
	Inventory.axe_state.clear()
	Inventory.gold = 0
	Inventory.changed.emit()
	QuestManager.load_from_dict({})
	Progression.load_from_dict({})
	var error := get_tree().change_scene_to_file(WORLD)
	if error != OK:
		_show_error("Le monde n’a pas pu être chargé. Réessayez.")

func _load_game(path: String) -> void:
	if busy or not menu_ready: return
	# Check before fading; rejected saves leave the title and current state intact.
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or SaveManager.normalize_save_data(data).is_empty():
		status.text = "Cette sauvegarde est illisible ou incompatible."
		return
	busy = true
	status.text = "Les souvenirs se réveillent…"
	await _fade_out()
	# SaveManager owns the asynchronous transition after this scene is freed.
	SaveManager.load_game_from_file(path)

func _fade_out() -> void:
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fade, "color:a", 1.0, 0.65)
	tween.tween_property(menu_music, "volume_db", -80.0, 0.65)
	await tween.finished
	menu_music.stop()

func _show_error(message: String) -> void:
	busy = false
	status.text = message
	menu_music.volume_db = MusicManager.get_volume_db()
	menu_music.play()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(fade, "color:a", 0.0, 0.3)

func _resize() -> void:
	if not is_inside_tree(): return
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(viewport.x / 1280.0, viewport.y / 720.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (viewport - Vector2(1280, 720) * factor) * 0.5

func _draw_magic() -> void:
	var center := Vector2(345, 76)
	var gold := Color(0.91, 0.77, 0.46, 0.6)
	stage.draw_arc(center, 30, 0, TAU, 80, Color(0.85, 0.72, 0.45, 0.3), 1.0, true)
	stage.draw_arc(center, 36, -2.7, -0.4, 50, gold, 1.0, true)
	var points := PackedVector2Array()
	for i in range(16):
		var angle := i * PI / 8.0 - PI / 2.0
		var radius := (33.0 if i % 4 == 0 else 22.0) if i % 2 == 0 else 7.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	stage.draw_colored_polygon(points, GOLD)
	stage.draw_circle(center, 4.0, Color("fff6d9"))
	for side in [-1, 1]:
		stage.draw_line(center + Vector2(side * 57, 0), center + Vector2(side * 165, 0), gold, 1.0, true)
		stage.draw_circle(center + Vector2(side * 174, 0), 2.5, gold)
	for i in range(36):
		var x := fposmod(i * 97.7 + sin(elapsed * 0.12 + i) * 17.0, 1260.0) + 10.0
		var y := fposmod(i * 63.3 - elapsed * (3.0 + i % 3), 720.0)
		var alpha := (sin(elapsed * 0.8 + i * 2.3) + 1.0) * 0.17
		stage.draw_circle(Vector2(x, y), 1.2 + float(i % 3) * 0.5, Color(0.9, 0.87, 0.58, alpha))
