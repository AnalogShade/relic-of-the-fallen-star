extends CanvasLayer
var panel: PanelContainer
var shade: ColorRect
var prompt: Label
var toast: Label
var details: Label
var count: Label
var resources: GridContainer
var tools_grid: GridContainer
var toast_time := 0.0
var gold := Color("d9ba7c")
var ink := Color("171e1d")
var bag: Node
var health_display: Label
var inventory_view: VBoxContainer
var character_view: VBoxContainer
var progression_view: VBoxContainer
var page_layout: VBoxContainer
var page_title: Label
var character_summary: Label

func style(color: Color, border: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(5)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _ready() -> void:
	bag = get_parent()
	layer = 40
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.65)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", style(ink, gold, 2))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -435
	panel.offset_right = 435
	panel.offset_top = -292
	panel.offset_bottom = 292
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	page_layout = layout
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := label("SAC DE VOYAGE", 28, gold)
	page_title = title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var character_button := make_button("Personnage", 16, 40)
	character_button.pressed.connect(show_character)
	header.add_child(character_button)
	var close := Button.new()
	close.text = "Fermer  [ I ]"
	close.pressed.connect(func(): bag.set_open(false))
	header.add_child(close)
	inventory_view = VBoxContainer.new()
	inventory_view.add_theme_constant_override("separation", 14)
	layout.add_child(inventory_view)
	layout = inventory_view
	var subheader := HBoxContainer.new()
	layout.add_child(subheader)
	var sub_title := label("NAËL   /   FORÊT DES LUEURS", 13, Color("8da79c"))
	sub_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subheader.add_child(sub_title)
	health_display = label("SANTÉ : 100 / 100 PV", 14, Color("68c287"))
	subheader.add_child(health_display)
	layout.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	layout.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	count = label("", 16, gold)
	left.add_child(count)
	resources = GridContainer.new()
	resources.columns = 6
	resources.add_theme_constant_override("h_separation", 6)
	resources.add_theme_constant_override("v_separation", 6)
	left.add_child(resources)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 290
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(label("ÉQUIPEMENT", 16, gold))
	tools_grid = GridContainer.new()
	tools_grid.columns = 3
	tools_grid.add_theme_constant_override("h_separation", 6)
	tools_grid.add_theme_constant_override("v_separation", 6)
	right.add_child(tools_grid)
	right.add_child(label("Cliquer pour équiper / ranger", 14, Color("8da79c")))
	details = label("", 16, Color("e8e1cc"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(285, 125)
	right.add_child(details)
	layout.add_child(HSeparator.new())
	layout.add_child(label("F  Cueillir, prendre ou cuisiner au chaudron     ·     Les ressources se regroupent par piles", 14, Color("8da79c")))
	prompt = label("", 23, Color("fff0c9"))
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.offset_top = -120
	prompt.offset_bottom = -78
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label("", 19, gold)
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -350
	toast.offset_right = 350
	toast.offset_top = 65
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var inv_btn := Button.new()
	inv_btn.text = "I   Sac"
	inv_btn.focus_mode = Control.FOCUS_NONE
	inv_btn.custom_minimum_size = Vector2(110, 32)
	inv_btn.add_theme_font_size_override("font_size", 14)
	inv_btn.add_theme_color_override("font_color", gold)
	inv_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	inv_btn.add_theme_stylebox_override("normal", style(Color("1a2422", 0.75), Color("45514a"), 1))
	inv_btn.add_theme_stylebox_override("hover", style(Color("253531", 0.9), gold, 1))
	inv_btn.add_theme_stylebox_override("pressed", style(Color("304840", 0.95), gold, 2))
	add_child(inv_btn)
	inv_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	inv_btn.offset_left = -155
	inv_btn.offset_top = -105
	inv_btn.offset_right = -35
	inv_btn.offset_bottom = -73
	inv_btn.pressed.connect(func():
		if not get_node("/root/CabinTravel").busy:
			bag.set_open(not bag.is_open))
	bag.changed.connect(refresh)
	refresh()
	set_open(false)

func slot(parent: GridContainer, id: String, quantity := 0, slot_index := -1) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(72, 72)
	button.focus_mode = Control.FOCUS_NONE
	var selected: bool = id != "" and bag.equipped == id
	button.add_theme_stylebox_override("normal", style(Color("304c40") if selected else Color("202a28"), gold if selected else Color("45514a"), 2 if selected else 1))
	button.add_theme_stylebox_override("hover", style(Color("35463d"), gold))
	button.add_theme_stylebox_override("pressed", style(Color("40594b"), gold, 2))
	parent.add_child(button)
	if id.is_empty(): return
	var icon := TextureRect.new()
	icon.texture = load(bag.ITEMS[id].icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 5
	icon.offset_right = -8
	icon.offset_bottom = -12
	var number := label(("✓ %d" % quantity if quantity > 0 else "ÉQUIPÉ") if selected else (str(quantity) if quantity > 0 else ""), 12, gold)
	button.add_child(number)
	number.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	number.offset_left = -62
	number.offset_top = -19
	number.offset_right = -5
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.tooltip_text = bag.ITEMS[id].name + "\n" + bag.ITEMS[id].description
	button.mouse_entered.connect(func(): show_details(id))
	button.pressed.connect(func():
		if bag.ITEMS[id].equipment or bag.ITEMS[id].get("equippable", false):
			bag.toggle_equipment(id)
		elif bag.ITEMS[id].get("usable", false):
			bag.use_item(id)
		elif bag.ITEMS[id].get("consumable", false):
			if slot_index >= 0:
				bag.consume_slot(slot_index)
			else:
				bag.consume_item(id)
		show_details(id))

func show_details(id: String) -> void:
	if id.is_empty() or not bag.ITEMS.has(id):
		details.text = "Survolez un objet pour l’examiner.\n\nCliquez sur un aliment pour le consommer et vous soigner."
		return
	details.text = bag.ITEMS[id].name + "\n\n" + bag.ITEMS[id].description
	if bag.equipped == id:
		details.text += "\n\n✓ Équipé" if id in ["first_echo", "primordial_wave"] else "\n\n✓ En main"
	elif bag.ITEMS[id].get("consumable", false):
		details.text += "\n\n▶ Clic : Consommer (+%d PV)" % int(bag.ITEMS[id].get("heal", 0))
	elif bag.ITEMS[id].get("equippable", false):
		details.text += "\n\n▶ Clic : Équiper"

func refresh() -> void:
	for grid in [resources, tools_grid]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	for i in range(bag.CAPACITY):
		if i < bag.stacks.size():
			slot(resources, bag.stacks[i].id, bag.stacks[i].quantity, i)
		else:
			slot(resources, "", 0, -1)
	for i in range(6):
		slot(tools_grid, bag.equipment[i] if i < bag.equipment.size() else "", 0, -1)
	count.text = "RESSOURCES    %d / %d    ·    OR : %d" % [bag.stacks.size(), bag.CAPACITY, bag.gold]
	details.text = "Survolez un objet pour l’examiner.\n\nCliquez sur un aliment pour le consommer et vous soigner."
	
	var player := bag.get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and health_display:
		var hp := int(player.health)
		health_display.text = "SANTÉ : %d / %d PV" % [hp, int(player.max_health)]
		if hp < player.max_health * 0.3:
			health_display.add_theme_color_override("font_color", Color("e06050"))
		elif hp < player.max_health * 0.7:
			health_display.add_theme_color_override("font_color", Color("e0b050"))
		else:
			health_display.add_theme_color_override("font_color", Color("68c287"))

func set_open(value: bool) -> void:
	panel.visible = value
	shade.visible = value
	show_inventory()
	if value: prompt.text = ""

func set_prompt(text: String) -> void:
	prompt.text = text

func notify(text: String) -> void:
	toast.text = text
	toast_time = 3.0

func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	toast.visible = toast_time > 0.0 and not bag.is_open

func make_button(text: String, font_size := 19, height := 50) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("e8e1cc"))
	button.add_theme_stylebox_override("normal", style(Color("202a28"), Color("45514a")))
	button.add_theme_stylebox_override("hover", style(Color("35463d"), gold))
	button.add_theme_stylebox_override("pressed", style(Color("40594b"), gold, 2))
	button.add_theme_stylebox_override("disabled", style(Color("161d1b"), Color("2a3330")))
	var focus := style(Color.TRANSPARENT, gold, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	return button

func show_inventory() -> void:
	inventory_view.show()
	if character_view: character_view.hide()
	if progression_view: progression_view.hide()
	page_title.text = "SAC DE VOYAGE"

func show_character() -> void:
	if not bag.is_open: return
	if not character_view:
		character_view = VBoxContainer.new()
		character_view.add_theme_constant_override("separation", 18)
		page_layout.add_child(character_view)
		character_summary = label("", 22, gold)
		character_view.add_child(character_summary)
		var attributes_button := make_button("Attributs")
		attributes_button.name = "AttributesButton"
		character_view.add_child(attributes_button)
		attributes_button.pressed.connect(show_attributes)
		var back := make_button("Retour au sac")
		character_view.add_child(back)
		back.pressed.connect(show_inventory)
	inventory_view.hide()
	if progression_view: progression_view.hide()
	page_title.text = "PERSONNAGE"
	character_summary.text = "NAËL · Niveau %d\nXP : %d / %d\nPoints d'attributs disponibles : %d" % [Progression.level, Progression.experience, Progression.experience_required(), Progression.points]
	character_view.show()
	character_view.get_node("AttributesButton").grab_focus()

func show_attributes() -> void:
	if not bag.is_open: return
	if not progression_view:
		progression_view = preload("res://scripts/progression_panel.gd").new()
		page_layout.add_child(progression_view)
		progression_view.back_requested.connect(show_character)
	inventory_view.hide()
	if character_view: character_view.hide()
	page_title.text = "ATTRIBUTS"
	progression_view.show()
	if Progression.points > 0: progression_view.buttons.strength.grab_focus()
