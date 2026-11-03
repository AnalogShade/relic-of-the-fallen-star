extends CanvasLayer
## Menu pause persistant avec Continuer, Sauvegarder (avec nom de partie personnalisé),
## Charger une partie et Quitter.

var is_open := false
var previous_mouse := Input.MOUSE_MODE_CAPTURED
signal title_options_closed
var from_title := false

var panel: PanelContainer
var main_view: VBoxContainer
var save_view: VBoxContainer
var load_view: VBoxContainer
var options_view: VBoxContainer
var controls_view: VBoxContainer

var continue_button: Button
var options_button: Button
var controls_button: Button
var save_name_input: LineEdit
var save_status_label: Label
var saves_list_container: VBoxContainer
var load_saves_list_container: VBoxContainer

var music_check: CheckBox
var music_slider: HSlider
var music_vol_lbl: Label
var sfx_check: CheckBox
var sfx_slider: HSlider
var sfx_vol_lbl: Label
var options_back_btn: Button
var controls_back_btn: Button

var selected_save_path := ""
var load_confirm_btn: Button
var delete_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	var inventory_ui = get_node("/root/Inventory").ui
	var gold: Color = inventory_ui.gold
	
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.65)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.add_theme_stylebox_override("panel", inventory_ui.style(inventory_ui.ink, gold, 2))
	center.add_child(panel)
	
	_build_main_view(inventory_ui, gold)
	_build_save_view(inventory_ui, gold)
	_build_load_view(inventory_ui, gold)
	_build_options_view(inventory_ui, gold)
	_build_controls_view(inventory_ui, gold)
	
	show_main_view()
	hide()

func make_button(text: String, inventory_ui: CanvasLayer, font_sz := 19, min_h := 50) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = min_h
	button.add_theme_font_size_override("font_size", font_sz)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("e8e1cc"))
	button.add_theme_stylebox_override("normal", inventory_ui.style(Color("202a28"), Color("45514a")))
	button.add_theme_stylebox_override("hover", inventory_ui.style(Color("35463d"), inventory_ui.gold))
	button.add_theme_stylebox_override("pressed", inventory_ui.style(Color("40594b"), inventory_ui.gold, 2))
	button.add_theme_stylebox_override("disabled", inventory_ui.style(Color("161d1b"), Color("2a3330")))
	var focus: StyleBoxFlat = inventory_ui.style(Color.TRANSPARENT, inventory_ui.gold, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	return button

func make_line_edit(placeholder: String, inventory_ui: CanvasLayer) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size.y = 48
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", Color("e8e1cc"))
	edit.add_theme_color_override("placeholder_color", Color("5c6b65"))
	edit.add_theme_stylebox_override("normal", inventory_ui.style(Color("101615"), Color("45514a"), 1))
	edit.add_theme_stylebox_override("focus", inventory_ui.style(Color("16201e"), inventory_ui.gold, 2))
	return edit

func _build_main_view(inventory_ui: CanvasLayer, gold: Color) -> void:
	main_view = VBoxContainer.new()
	main_view.add_theme_constant_override("separation", 16)
	panel.add_child(main_view)
	
	var title: Label = inventory_ui.label("PAUSE", 28, gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_view.add_child(title)
	
	var subtitle: Label = inventory_ui.label("NAËL   /   RELIC OF THE FALLEN STAR", 13, Color("8da79c"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_view.add_child(subtitle)
	
	main_view.add_child(HSeparator.new())
	
	continue_button = make_button("Continuer", inventory_ui)
	main_view.add_child(continue_button)
	continue_button.pressed.connect(resume)
	
	var save_btn := make_button("Sauvegarder la partie", inventory_ui)
	main_view.add_child(save_btn)
	save_btn.pressed.connect(show_save_view)
	
	var load_btn := make_button("Charger une partie", inventory_ui)
	main_view.add_child(load_btn)
	load_btn.pressed.connect(show_load_view)
	
	options_button = make_button("Options", inventory_ui)
	main_view.add_child(options_button)
	options_button.pressed.connect(show_options_view)
	
	var quit_button := make_button("Quitter le jeu", inventory_ui)
	main_view.add_child(quit_button)
	quit_button.pressed.connect(func(): get_tree().quit())
	
	var hint: Label = inventory_ui.label("Échap  ·  Reprendre l’aventure", 14, Color("8da79c"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_view.add_child(hint)

func _build_save_view(inventory_ui: CanvasLayer, gold: Color) -> void:
	save_view = VBoxContainer.new()
	save_view.add_theme_constant_override("separation", 14)
	panel.add_child(save_view)
	
	var title: Label = inventory_ui.label("SAUVEGARDER LA PARTIE", 24, gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_view.add_child(title)
	
	var subtitle: Label = inventory_ui.label("Entrez un nom pour votre sauvegarde", 13, Color("8da79c"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_view.add_child(subtitle)
	
	save_view.add_child(HSeparator.new())
	
	save_name_input = make_line_edit("Nom de la partie...", inventory_ui)
	save_view.add_child(save_name_input)
	
	var lbl_recent: Label = inventory_ui.label("Sauvegardes existantes (cliquez pour écraser) :", 12, Color("7a8f86"))
	save_view.add_child(lbl_recent)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	save_view.add_child(scroll)
	
	saves_list_container = VBoxContainer.new()
	saves_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(saves_list_container)
	
	save_status_label = inventory_ui.label("", 14, Color("70eed8"))
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_view.add_child(save_status_label)
	
	var btns_row := HBoxContainer.new()
	btns_row.add_theme_constant_override("separation", 12)
	save_view.add_child(btns_row)
	
	var confirm_save_btn := make_button("Enregistrer", inventory_ui, 18, 46)
	confirm_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns_row.add_child(confirm_save_btn)
	confirm_save_btn.pressed.connect(_on_save_confirmed)
	
	var back_btn := make_button("Retour", inventory_ui, 18, 46)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns_row.add_child(back_btn)
	back_btn.pressed.connect(show_main_view)

func _build_load_view(inventory_ui: CanvasLayer, gold: Color) -> void:
	load_view = VBoxContainer.new()
	load_view.add_theme_constant_override("separation", 14)
	panel.add_child(load_view)
	
	var title: Label = inventory_ui.label("CHARGER UNE PARTIE", 24, gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_view.add_child(title)
	
	var subtitle: Label = inventory_ui.label("Sélectionnez la partie que vous souhaitez reprendre", 13, Color("8da79c"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_view.add_child(subtitle)
	
	load_view.add_child(HSeparator.new())
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	load_view.add_child(scroll)
	
	load_saves_list_container = VBoxContainer.new()
	load_saves_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_saves_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(load_saves_list_container)
	
	var btns_row := HBoxContainer.new()
	btns_row.add_theme_constant_override("separation", 10)
	load_view.add_child(btns_row)
	
	load_confirm_btn = make_button("Charger la partie", inventory_ui, 18, 46)
	load_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns_row.add_child(load_confirm_btn)
	load_confirm_btn.disabled = true
	load_confirm_btn.pressed.connect(_on_load_confirmed)
	
	delete_btn = make_button("Supprimer", inventory_ui, 16, 46)
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.disabled = true
	btns_row.add_child(delete_btn)
	delete_btn.pressed.connect(_on_delete_confirmed)
	
	var back_btn := make_button("Retour", inventory_ui, 18, 46)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns_row.add_child(back_btn)
	back_btn.pressed.connect(show_main_view)

func _build_options_view(inventory_ui: CanvasLayer, gold: Color) -> void:
	options_view = VBoxContainer.new()
	options_view.add_theme_constant_override("separation", 14)
	panel.add_child(options_view)
	
	var title: Label = inventory_ui.label("OPTIONS", 24, gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_view.add_child(title)
	
	var subtitle: Label = inventory_ui.label("RÉGLAGES AUDIO & JEU", 13, Color("8da79c"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_view.add_child(subtitle)
	
	options_view.add_child(HSeparator.new())
	
	# --- Section Musique ---
	var music_box := VBoxContainer.new()
	music_box.add_theme_constant_override("separation", 8)
	options_view.add_child(music_box)
	
	var music_title: Label = inventory_ui.label("✦   MUSIQUE", 15, gold)
	music_box.add_child(music_title)
	
	music_check = CheckBox.new()
	music_check.text = "Activer la musique"
	music_check.add_theme_font_size_override("font_size", 15)
	music_check.add_theme_color_override("font_color", Color("e8e1cc"))
	music_check.add_theme_color_override("font_pressed_color", Color("e8e1cc"))
	music_check.add_theme_color_override("font_hover_color", gold)
	music_check.add_theme_color_override("font_hover_pressed_color", gold)
	music_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	music_box.add_child(music_check)
	
	var music_slider_row := HBoxContainer.new()
	music_slider_row.add_theme_constant_override("separation", 12)
	music_box.add_child(music_slider_row)
	
	var music_lbl: Label = inventory_ui.label("Volume :", 14, Color("a3b5ad"))
	music_lbl.custom_minimum_size.x = 65
	music_slider_row.add_child(music_lbl)
	
	music_slider = _make_styled_slider()
	music_slider_row.add_child(music_slider)
	
	music_vol_lbl = inventory_ui.label("80%", 14, Color("e8e1cc"))
	music_vol_lbl.custom_minimum_size.x = 48
	music_vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_slider_row.add_child(music_vol_lbl)
	
	options_view.add_child(HSeparator.new())
	
	# --- Section Effets Sonores ---
	var sfx_box := VBoxContainer.new()
	sfx_box.add_theme_constant_override("separation", 8)
	options_view.add_child(sfx_box)
	
	var sfx_title: Label = inventory_ui.label("✦   EFFETS SONORES (SFX)", 15, gold)
	sfx_box.add_child(sfx_title)
	
	sfx_check = CheckBox.new()
	sfx_check.text = "Activer les effets sonores"
	sfx_check.add_theme_font_size_override("font_size", 15)
	sfx_check.add_theme_color_override("font_color", Color("e8e1cc"))
	sfx_check.add_theme_color_override("font_pressed_color", Color("e8e1cc"))
	sfx_check.add_theme_color_override("font_hover_color", gold)
	sfx_check.add_theme_color_override("font_hover_pressed_color", gold)
	sfx_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sfx_box.add_child(sfx_check)
	
	var sfx_slider_row := HBoxContainer.new()
	sfx_slider_row.add_theme_constant_override("separation", 12)
	sfx_box.add_child(sfx_slider_row)
	
	var sfx_lbl: Label = inventory_ui.label("Volume :", 14, Color("a3b5ad"))
	sfx_lbl.custom_minimum_size.x = 65
	sfx_slider_row.add_child(sfx_lbl)
	
	sfx_slider = _make_styled_slider()
	sfx_slider_row.add_child(sfx_slider)
	
	sfx_vol_lbl = inventory_ui.label("80%", 14, Color("e8e1cc"))
	sfx_vol_lbl.custom_minimum_size.x = 48
	sfx_vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_slider_row.add_child(sfx_vol_lbl)
	
	options_view.add_child(HSeparator.new())
	
	controls_button = make_button("Commandes / Raccourcis clavier", inventory_ui, 18, 46)
	controls_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_view.add_child(controls_button)
	controls_button.pressed.connect(show_controls_view)
	
	options_back_btn = make_button("Retour", inventory_ui, 18, 46)
	options_back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_view.add_child(options_back_btn)
	options_back_btn.pressed.connect(show_main_view)
	
	music_check.toggled.connect(_on_music_check_toggled)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_check.toggled.connect(_on_sfx_check_toggled)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)

func _make_styled_slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 24
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1a2422")
	track.border_color = Color("384741")
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	
	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Color("3d5446")
	grabber_area.set_corner_radius_all(3)
	grabber_area.content_margin_top = 4
	grabber_area.content_margin_bottom = 4
	
	var grabber_area_hl := StyleBoxFlat.new()
	grabber_area_hl.bg_color = Color("50725e")
	grabber_area_hl.set_corner_radius_all(3)
	grabber_area_hl.content_margin_top = 4
	grabber_area_hl.content_margin_bottom = 4
	
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", grabber_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area_hl)
	return slider

func _build_controls_view(inventory_ui: CanvasLayer, gold: Color) -> void:
	controls_view = VBoxContainer.new()
	controls_view.add_theme_constant_override("separation", 12)
	panel.add_child(controls_view)
	
	var title: Label = inventory_ui.label("COMMANDES DU JEU", 24, gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_view.add_child(title)
	
	var subtitle: Label = inventory_ui.label("RACCOURCIS CLAVIER & SOURIS", 13, Color("8da79c"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_view.add_child(subtitle)
	
	controls_view.add_child(HSeparator.new())
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 350
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_view.add_child(scroll)
	
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	
	_add_controls_category(content, inventory_ui, gold, "✦   DÉPLACEMENT & EXPLORATION", [
		["Marcher", "WASD / ZQSD"],
		["Courir (Sprint)", "MAJ (Shift)"],
		["Sauter / Salto avant", "ESPACE"],
		["Esquive rapide (Roulade)", "Double appui A / D / S"],
		["Charge avant", "Double appui W / Z"],
		["Orienter la caméra", "Mouvement Souris"],
		["Zoomer / Dézoomer", "Molette Souris"],
	])
	
	_add_controls_category(content, inventory_ui, gold, "✦   COMBAT & ACTIONS", [
		["Attaque aux griffes (Combo)", "Clic Gauche"],
		["Lancer la hache (équipée)", "CTRL + Clic Gauche"],
		["Souffle igné (Boule de feu)", "Clic Droit (Maintenir & relâcher)"],
		["Onde primordiale (fragment du lac)", "Q · Recharge : 7 s"],
		["Ramasser / Cueillir / Interagir", "F"],
	])
	
	_add_controls_category(content, inventory_ui, gold, "✦   MENUS & INTERFACE", [
		["Sac de voyage (Inventaire)", "I"],
		["Journal de quêtes", "J"],
		["Menu Pause & Options", "ÉCHAP"],
		["Réapparaître au dernier point", "R"],
	])
	
	controls_view.add_child(HSeparator.new())
	
	controls_back_btn = make_button("Retour aux options", inventory_ui, 18, 46)
	controls_back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_view.add_child(controls_back_btn)
	controls_back_btn.pressed.connect(show_options_view)

func _add_controls_category(parent: VBoxContainer, inventory_ui: CanvasLayer, gold: Color, cat_title: String, bindings: Array) -> void:
	var cat_box := VBoxContainer.new()
	cat_box.add_theme_constant_override("separation", 6)
	parent.add_child(cat_box)
	
	var cat_lbl: Label = inventory_ui.label(cat_title, 14, gold)
	cat_box.add_child(cat_lbl)
	
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 4)
	cat_box.add_child(grid)
	
	for item in bindings:
		var action_name: String = item[0]
		var key_text: String = item[1]
		
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style: StyleBoxFlat = inventory_ui.style(Color("16201e", 0.65), Color("2e3b36", 0.45), 1)
		row_style.content_margin_left = 12
		row_style.content_margin_right = 12
		row_style.content_margin_top = 6
		row_style.content_margin_bottom = 6
		row_panel.add_theme_stylebox_override("panel", row_style)
		
		var inner_row := HBoxContainer.new()
		row_panel.add_child(inner_row)
		
		var action_lbl: Label = inventory_ui.label(action_name, 14, Color("dcd5c0"))
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_row.add_child(action_lbl)
		
		var key_badge := PanelContainer.new()
		var badge_style: StyleBoxFlat = inventory_ui.style(Color("222f2b"), Color("496054"), 1)
		badge_style.content_margin_left = 10
		badge_style.content_margin_right = 10
		badge_style.content_margin_top = 3
		badge_style.content_margin_bottom = 3
		key_badge.add_theme_stylebox_override("panel", badge_style)
		
		var key_lbl: Label = inventory_ui.label(key_text, 13, gold)
		key_badge.add_child(key_lbl)
		inner_row.add_child(key_badge)
		
		grid.add_child(row_panel)

func show_options_view() -> void:
	main_view.hide()
	save_view.hide()
	load_view.hide()
	if controls_view:
		controls_view.hide()
	options_view.show()
	_sync_options_from_settings()
	if options_back_btn:
		options_back_btn.grab_focus()

func show_controls_view() -> void:
	main_view.hide()
	save_view.hide()
	load_view.hide()
	if options_view:
		options_view.hide()
	if controls_view:
		controls_view.show()
	if controls_back_btn:
		controls_back_btn.grab_focus()

func _sync_options_from_settings() -> void:
	var audio_settings = get_node_or_null("/root/AudioSettings")
	if not audio_settings: return
	
	music_check.set_pressed_no_signal(audio_settings.music_enabled)
	music_slider.set_value_no_signal(audio_settings.music_volume)
	music_vol_lbl.text = "%d%%" % int(round(audio_settings.music_volume * 100))
	music_slider.editable = audio_settings.music_enabled
	
	sfx_check.set_pressed_no_signal(audio_settings.sfx_enabled)
	sfx_slider.set_value_no_signal(audio_settings.sfx_volume)
	sfx_vol_lbl.text = "%d%%" % int(round(audio_settings.sfx_volume * 100))
	sfx_slider.editable = audio_settings.sfx_enabled

func _on_music_check_toggled(toggled_on: bool) -> void:
	var audio_settings = get_node_or_null("/root/AudioSettings")
	if audio_settings:
		audio_settings.set_music_enabled(toggled_on)
	music_slider.editable = toggled_on

func _on_music_slider_changed(value: float) -> void:
	var audio_settings = get_node_or_null("/root/AudioSettings")
	if audio_settings:
		audio_settings.set_music_volume(value)
	music_vol_lbl.text = "%d%%" % int(round(value * 100))

func _on_sfx_check_toggled(toggled_on: bool) -> void:
	var audio_settings = get_node_or_null("/root/AudioSettings")
	if audio_settings:
		audio_settings.set_sfx_enabled(toggled_on)
	sfx_slider.editable = toggled_on

func _on_sfx_slider_changed(value: float) -> void:
	var audio_settings = get_node_or_null("/root/AudioSettings")
	if audio_settings:
		audio_settings.set_sfx_volume(value)
	sfx_vol_lbl.text = "%d%%" % int(round(value * 100))

func show_main_view() -> void:
	if from_title:
		resume()
		return
	main_view.show()
	save_view.hide()
	load_view.hide()
	if options_view:
		options_view.hide()
	if controls_view:
		controls_view.hide()
	if continue_button:
		continue_button.grab_focus()

func show_save_view() -> void:
	main_view.hide()
	save_view.show()
	load_view.hide()
	if options_view:
		options_view.hide()
	if controls_view:
		controls_view.hide()
	save_status_label.text = ""
	
	# Pré-remplir le nom de sauvegarde par défaut
	var save_mgr = get_node_or_null("/root/SaveManager")
	var loc: String = save_mgr.get_current_location_name() if save_mgr else "Forêt des lueurs"
	var date_dict := Time.get_datetime_dict_from_system()
	save_name_input.text = "%s (%02d:%02d)" % [loc, date_dict.hour, date_dict.minute]
	save_name_input.grab_focus()
	save_name_input.select_all()
	
	_refresh_saves_list_for_saving()

func show_load_view() -> void:
	main_view.hide()
	save_view.hide()
	load_view.show()
	if options_view:
		options_view.hide()
	if controls_view:
		controls_view.hide()
	selected_save_path = ""
	load_confirm_btn.disabled = true
	delete_btn.disabled = true
	
	_refresh_saves_list_for_loading()

func _refresh_saves_list_for_saving() -> void:
	for child in saves_list_container.get_children():
		child.queue_free()
		
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr: return
	
	var saves: Array[Dictionary] = save_mgr.list_saves()
	var inventory_ui = get_node("/root/Inventory").ui
	
	if saves.is_empty():
		var empty_lbl = inventory_ui.label("Aucune sauvegarde enregistrée pour le moment.", 13, Color("5c6b65"))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		saves_list_container.add_child(empty_lbl)
		return
		
	for save in saves:
		var btn := Button.new()
		btn.text = "%s  ·  %s" % [save.get("save_name", "Sauvegarde"), save.get("datetime_string", "")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 36
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color("c5beab"))
		btn.add_theme_stylebox_override("normal", inventory_ui.style(Color("1b2321"), Color("2e3b36"), 1))
		btn.add_theme_stylebox_override("hover", inventory_ui.style(Color("26332f"), inventory_ui.gold, 1))
		btn.pressed.connect(func():
			save_name_input.text = save.get("save_name", "")
		)
		saves_list_container.add_child(btn)

func _refresh_saves_list_for_loading() -> void:
	for child in load_saves_list_container.get_children():
		child.queue_free()
		
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr: return
	
	var saves: Array[Dictionary] = save_mgr.list_saves()
	var inventory_ui = get_node("/root/Inventory").ui
	
	if saves.is_empty():
		var empty_lbl = inventory_ui.label("Aucune sauvegarde disponible.", 14, Color("5c6b65"))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		load_saves_list_container.add_child(empty_lbl)
		return
		
	for save in saves:
		var file_path: String = save.get("file_path", "")
		var item_btn := Button.new()
		item_btn.custom_minimum_size.y = 62
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Contenu de la carte
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.offset_left = 14
		vbox.offset_right = -14
		vbox.offset_top = 8
		vbox.offset_bottom = -8
		item_btn.add_child(vbox)
		
		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(top_row)
		
		var title := Label.new()
		title.text = save.get("save_name", "Sauvegarde")
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", inventory_ui.gold)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(title)
		
		var date_lbl := Label.new()
		date_lbl.text = save.get("datetime_string", "")
		date_lbl.add_theme_font_size_override("font_size", 12)
		date_lbl.add_theme_color_override("font_color", Color("8da79c"))
		top_row.add_child(date_lbl)
		
		var bottom_row := HBoxContainer.new()
		bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bottom_row)
		
		var loc: String = save.get("location_name", "Inconnu")
		var hp: int = int(save.get("player", {}).get("health", 100))
		var eq_list: Array = save.get("inventory", {}).get("equipment", [])
		var has_fireball := eq_list.has("first_echo")
		var fireball_tag := " · ✦ Souffle igné" if has_fireball else ""
		
		var info_lbl := Label.new()
		info_lbl.text = "%s  ·  %d PV%s" % [loc, hp, fireball_tag]
		info_lbl.add_theme_font_size_override("font_size", 13)
		info_lbl.add_theme_color_override("font_color", Color("a3b5ad"))
		bottom_row.add_child(info_lbl)
		
		# Styles
		var normal_style = inventory_ui.style(Color("1b2321"), Color("35463d"), 1)
		var selected_style = inventory_ui.style(Color("263730"), inventory_ui.gold, 2)
		var hover_style = inventory_ui.style(Color("23302b"), Color("5c7365"), 1)
		
		item_btn.add_theme_stylebox_override("normal", normal_style)
		item_btn.add_theme_stylebox_override("hover", hover_style)
		item_btn.add_theme_stylebox_override("pressed", selected_style)
		item_btn.add_theme_stylebox_override("focus", selected_style)
		
		item_btn.pressed.connect(func():
			selected_save_path = file_path
			load_confirm_btn.disabled = false
			delete_btn.disabled = false
			# Mettre à jour l'apparence visuelle des boutons
			for other in load_saves_list_container.get_children():
				if other is Button:
					other.add_theme_stylebox_override("normal", normal_style)
			item_btn.add_theme_stylebox_override("normal", selected_style)
		)
		load_saves_list_container.add_child(item_btn)

func _on_save_confirmed() -> void:
	var name_text := save_name_input.text.strip_edges()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr: return
	
	var saved_path: String = save_mgr.save_game(name_text)
	if not saved_path.is_empty():
		save_status_label.add_theme_color_override("font_color", Color("70eed8"))
		save_status_label.text = "✓ Partie sauvegardée avec succès !"
		_refresh_saves_list_for_saving()
		
		# Revenir au menu principal après un court délai
		var t := create_tween()
		t.tween_interval(1.0)
		t.tween_callback(show_main_view)
	else:
		save_status_label.add_theme_color_override("font_color", Color("ee7070"))
		save_status_label.text = "Erreur lors de la sauvegarde."

func _on_load_confirmed() -> void:
	if selected_save_path.is_empty(): return
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr: return
	
	# Fermer le menu pause
	resume()
	
	# Charger la partie
	save_mgr.load_game_from_file(selected_save_path)

func _on_delete_confirmed() -> void:
	if selected_save_path.is_empty(): return
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr: return
	
	save_mgr.delete_save(selected_save_path)
	selected_save_path = ""
	load_confirm_btn.disabled = true
	delete_btn.disabled = true
	_refresh_saves_list_for_loading()

func _input(event: InputEvent) -> void:
	if not is_open and get_tree().current_scene and get_tree().current_scene.is_in_group("title_screen"):
		return
	if get_node("/root/CabinTravel").confirmation_open: return
	if event.is_action_pressed("release_mouse"):
		get_viewport().set_input_as_handled()
		if event.is_echo(): return
		if is_open:
			if controls_view and controls_view.visible:
				show_options_view()
			elif save_view.visible or load_view.visible or (options_view and options_view.visible):
				show_main_view()
			else:
				resume()
		else:
			open()

func open() -> void:
	if is_open or get_tree().paused: return
	var bag := get_node("/root/Inventory")
	bag.set_open(false)
	previous_mouse = Input.mouse_mode
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_main_view()
	show()

func resume() -> void:
	if not is_open: return
	var return_to_title := from_title
	from_title = false
	is_open = false
	hide()
	show_main_view()
	if continue_button:
		continue_button.release_focus()
	Input.mouse_mode = previous_mouse
	get_tree().paused = false
	if return_to_title:
		title_options_closed.emit()

func open_title_options() -> void:
	if is_open: return
	previous_mouse = Input.MOUSE_MODE_VISIBLE
	from_title = true
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_options_view()
	show()
