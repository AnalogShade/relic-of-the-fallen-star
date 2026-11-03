extends CanvasLayer
var bag: Node
var cauldron: Node3D
var recipes: VBoxContainer
var status: Label

func _ready() -> void:
	bag = get_parent()
	layer = 45
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.75)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 640
	panel.add_theme_stylebox_override("panel", bag.ui.style(bag.ui.ink, bag.ui.gold, 2))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	layout.add_child(bag.ui.label("PRÉPARATIONS AU CHAUDRON", 28, bag.ui.gold))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	recipes = VBoxContainer.new()
	recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes.add_theme_constant_override("separation", 12)
	scroll.add_child(recipes)
	status = bag.ui.label("", 16, Color("e8e1cc"))
	layout.add_child(status)
	var close := Button.new()
	close.text = "Fermer [ I ]"
	close.custom_minimum_size.y = 42
	close.pressed.connect(func(): bag.set_open(false))
	layout.add_child(close)
	bag.changed.connect(refresh)
	hide()

func open_menu(source: Node3D) -> void:
	cauldron = source
	status.text = ""
	show()
	refresh()

func refresh() -> void:
	if not visible: return
	for child in recipes.get_children():
		recipes.remove_child(child)
		child.queue_free()
	for recipe_id in bag.RECIPES:
		if not bag.recipe_discovered(str(recipe_id)): continue
		var recipe: Dictionary = bag.RECIPES[recipe_id]
		recipes.add_child(bag.ui.label(recipe.name, 22, bag.ui.gold))
		var heal := int(bag.ITEMS[recipe.result_id].get("heal", 0))
		var description: String = recipe.get("description", "1 portion · +%d PV en la mangeant" % heal)
		var text: Label = bag.ui.label(description, 16, Color("e8e1cc"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recipes.add_child(text)
		for ingredient in recipe.ingredients:
			var have: int = bag.get_any_item_count(ingredient.ids) if ingredient.type == "any" else bag.get_item_count(ingredient.id)
			var needed: int = int(ingredient.quantity)
			var color := Color("90c79a") if have >= needed else Color("eea08a")
			recipes.add_child(bag.ui.label("%s : %d requis · %d en sac%s" % [ingredient.label, needed, have, " · MANQUANT" if have < needed else ""], 17, color))
		var cook := Button.new()
		cook.text = recipe.get("verb", "Cuisiner") if bag.can_craft(recipe_id) else "Ingrédients manquants"
		cook.disabled = not bag.can_craft(recipe_id)
		cook.custom_minimum_size.y = 46
		cook.pressed.connect(_cook.bind(str(recipe_id)))
		recipes.add_child(cook)

func _cook(recipe_id: String) -> void:
	if not is_instance_valid(cauldron) or not cauldron.can_interact():
		bag.set_open(false)
		return
	if bag.craft_recipe(recipe_id):
		status.text = "%s ajouté au sac." % bag.ITEMS[bag.RECIPES[recipe_id].result_id].name
	else:
		status.text = "Préparation impossible : vérifiez les ingrédients et la place dans le sac."
	refresh()
