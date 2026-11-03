extends CanvasLayer
## Gestionnaire universel de dialogues narratifs pour Relic of the Fallen Star.
## Affiche une boîte de dialogue élégante avec barre de défilement, pagination,
## typographie dorée et gestion des contrôles.

signal dialogue_started(speaker: String)
signal dialogue_page_changed(page_idx: int, total_pages: int)
signal dialogue_finished(speaker: String)

var is_open := false
var previous_mouse := Input.MOUSE_MODE_CAPTURED

var current_speaker := ""
var current_title := ""
var current_pages: Array[String] = []
var current_page_idx := 0
var current_callback: Callable = Callable()

var shade: ColorRect
var panel: PanelContainer
var speaker_label: Label
var title_label: Label
var rich_text: RichTextLabel
var scroll_container: ScrollContainer
var page_label: Label
var prev_btn: Button
var next_btn: Button
var close_btn: Button
var footer: HBoxContainer
var choices_box: VBoxContainer
var current_choices: Array[String] = []
var choice_callback := Callable()

# Palette graphique harmonisée
const GOLD := Color("d9ba7c")
const INK := Color("171e1d")
const SUB_GOLD := Color("8da79c")
const PARCHMENT := Color("e8e1cc")
const BORDER_COLOR := Color("45514a")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 85
	_build_ui()
	hide_dialogue()

func _style(bg: Color, border: Color, width := 1, radius := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

func _build_ui() -> void:
	# Ombrage léger en arrière-plan
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_PASS
	shade.gui_input.connect(_on_shade_gui_input)
	add_child(shade)
	
	# Panneau principal ancré en bas de l'écran (style RPG / Cinématique)
	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.add_theme_stylebox_override("panel", _style(INK, GOLD, 2, 8))
	add_child(panel)
	
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -320
	panel.offset_bottom = -25
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)
	
	# En-tête : Nom du personnage + Titre + Bouton fermer
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)
	
	var titles_vbox := VBoxContainer.new()
	titles_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles_vbox.add_theme_constant_override("separation", 2)
	header.add_child(titles_vbox)
	
	speaker_label = Label.new()
	speaker_label.text = "PERSONNAGE"
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.add_theme_color_override("font_color", GOLD)
	speaker_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	speaker_label.add_theme_constant_override("shadow_offset_x", 1)
	speaker_label.add_theme_constant_override("shadow_offset_y", 1)
	titles_vbox.add_child(speaker_label)
	
	title_label = Label.new()
	title_label.text = "Lieu ou rôle"
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", SUB_GOLD)
	titles_vbox.add_child(title_label)
	
	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 32)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", SUB_GOLD)
	close_btn.add_theme_color_override("font_hover_color", GOLD)
	close_btn.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT))
	close_btn.add_theme_stylebox_override("hover", _style(Color("2a3832"), GOLD, 1, 4))
	close_btn.add_theme_stylebox_override("pressed", _style(Color("3b4e46"), GOLD, 2, 4))
	close_btn.pressed.connect(hide_dialogue)
	header.add_child(close_btn)
	
	# Séparateur doré fin
	var sep := HSeparator.new()
	var separator_style := StyleBoxFlat.new()
	separator_style.bg_color = Color("2d3d38")
	separator_style.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", separator_style)
	main_vbox.add_child(sep)
	
	# Conteneur de défilement (ScrollContainer) avec le texte
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(scroll_container)
	
	rich_text = RichTextLabel.new()
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_text.add_theme_font_size_override("normal_font_size", 17)
	rich_text.add_theme_font_size_override("italics_font_size", 17)
	rich_text.add_theme_font_size_override("bold_font_size", 17)
	rich_text.add_theme_color_override("default_color", PARCHMENT)
	rich_text.add_theme_constant_override("line_separation", 6)
	rich_text.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.add_child(rich_text)
	
	# Barre inférieure de navigation
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 6)
	main_vbox.add_child(choices_box)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	main_vbox.add_child(footer)
	
	page_label = Label.new()
	page_label.text = "Page 1 / 1"
	page_label.add_theme_font_size_override("font_size", 14)
	page_label.add_theme_color_override("font_color", SUB_GOLD)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(page_label)
	
	prev_btn = _make_btn("◀  Précédent", 110)
	prev_btn.pressed.connect(_on_prev_pressed)
	footer.add_child(prev_btn)
	
	next_btn = _make_btn("Suivant  ▶  [ Espace ]", 175)
	next_btn.pressed.connect(_on_next_pressed)
	footer.add_child(next_btn)

func _make_btn(btn_text: String, min_w := 120) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(min_w, 36)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", PARCHMENT)
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _style(Color("1e2926"), BORDER_COLOR, 1, 4))
	btn.add_theme_stylebox_override("hover", _style(Color("2a3a35"), GOLD, 1, 4))
	btn.add_theme_stylebox_override("pressed", _style(Color("3b4e46"), GOLD, 2, 4))
	for state_name in ["normal", "hover", "pressed"]:
		var box := btn.get_theme_stylebox(state_name) as StyleBoxFlat
		box.content_margin_top = 7
		box.content_margin_bottom = 7
	return btn

func show_dialogue(speaker: String, title: String, pages: Array[String], on_finished: Callable = Callable()) -> void:
	if pages.is_empty():
		return
	_clear_choices()
	current_speaker = speaker
	current_title = title
	current_pages = pages
	current_page_idx = 0
	current_callback = on_finished
	
	speaker_label.text = speaker.to_upper()
	title_label.text = title
	
	if not is_open:
		previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	
	shade.visible = true
	panel.visible = true
	_update_page()
	dialogue_started.emit(speaker)

func _clear_choices() -> void:
	current_choices.clear()
	choice_callback = Callable()
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	choices_box.hide()
	panel.offset_top = -320
	footer.show()

func show_choices(speaker: String, title: String, pages: Array[String], options: Array[String], on_choice: Callable) -> void:
	show_dialogue(speaker, title, pages)
	current_choices = options.duplicate()
	choice_callback = on_choice
	for i in options.size():
		var button := _make_btn("%d · %s" % [i + 1, options[i]], 0)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(choose.bind(i))
		choices_box.add_child(button)
	_update_page()

func choose(index: int) -> void:
	if not is_open or index < 0 or index >= current_choices.size(): return
	if current_page_idx != current_pages.size() - 1: return
	var callback := choice_callback
	hide_dialogue()
	if callback.is_valid(): callback.call(index)

func _update_page() -> void:
	if current_page_idx < 0 or current_page_idx >= current_pages.size():
		return
	
	rich_text.text = current_pages[current_page_idx]
	page_label.text = "Page %d / %d" % [current_page_idx + 1, current_pages.size()]
	
	prev_btn.visible = current_page_idx > 0
	var choosing := not current_choices.is_empty() and current_page_idx == current_pages.size() - 1
	choices_box.visible = choosing
	footer.visible = not choosing
	next_btn.visible = not choosing
	panel.offset_top = -370 if choosing else -320
	if current_page_idx == current_pages.size() - 1:
		next_btn.text = "Terminer  ✓  [ Espace ]"
		next_btn.custom_minimum_size.x = 180
	else:
		next_btn.text = "Suivant  ▶  [ Espace ]"
		next_btn.custom_minimum_size.x = 175
		
	# Remettre l'ascenseur en haut de page
	scroll_container.scroll_vertical = 0
	dialogue_page_changed.emit(current_page_idx, current_pages.size())

func _on_prev_pressed() -> void:
	if current_page_idx > 0:
		current_page_idx -= 1
		_update_page()

func _on_next_pressed() -> void:
	if not current_choices.is_empty() and current_page_idx == current_pages.size() - 1: return
	if current_page_idx < current_pages.size() - 1:
		current_page_idx += 1
		_update_page()
	else:
		hide_dialogue()

func hide_dialogue() -> void:
	if not is_open:
		shade.visible = false
		panel.visible = false
		return
		
	is_open = false
	shade.visible = false
	panel.visible = false
	
	# Restaurer le mode de capture de la souris si aucun menu n'est ouvert
	var inv = get_node_or_null("/root/Inventory")
	var pause = get_node_or_null("/root/PauseMenu")
	var quest_mgr = get_node_or_null("/root/QuestManager")
	var is_inv_open: bool = inv and inv.is_open
	var is_pause_open: bool = pause and pause.is_open
	var is_journal_open: bool = quest_mgr and quest_mgr.is_journal_open
	
	if not is_inv_open and not is_pause_open and not is_journal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	var cb := current_callback
	current_callback = Callable()
	_clear_choices()
	var spk := current_speaker
	
	if cb.is_valid():
		cb.call()
		
	dialogue_finished.emit(spk)

func _on_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clic en dehors du dialogue n'interfère pas
		pass

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and not current_choices.is_empty():
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < current_choices.size():
			get_viewport().set_input_as_handled()
			choose(index)
			return
		
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		get_viewport().set_input_as_handled()
		_on_next_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide_dialogue()
