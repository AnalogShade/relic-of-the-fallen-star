extends Node
## Shared by the forest and cabin players. State lasts for this play session.
signal changed
const CAPACITY := 24
const STACK_LIMIT := 99
const ITEMS := {
	"primordial_wave": {"name": "Éclat de l’Onde primordiale", "description": "Deuxième fragment du Premier Souffle, libéré du Dévoreur du lac.\nQ : déployer une nova de 9 m qui repousse et blesse les ennemis.\nBrise les carapaces corrompues de la Forêt Maléfique.\nRecharge : 7 secondes. Le fragment agit depuis l’équipement, même rangé.", "icon": "res://assets/ui/items/primordial_wave.svg", "equipment": true},
	"bread": {"name": "Pain du marché", "description": "Un pain à la croûte dorée du marché du château.\nNourrissant, redonne 18 PV.", "icon": "res://assets/ui/items/bread.svg", "equipment": false, "consumable": true, "heal": 18.0},
	"dream_fern": {"name": "Fougère des songes", "description": "Quelques tiges cueillies sur les fougères du ruisseau.\nLeur suc amer possède des propriétés soporifiques. Maëlor en parlait dans ses leçons.", "icon": "res://assets/ui/items/dream_fern.svg", "equipment": false},
	"sleep_dart": {"name": "Fléchette soporifique", "description": "Endort l'ogre sans le tuer.\nClic : équiper / ranger.\nClic droit maintenu : viser.\nRelâcher : lancer une fléchette.", "icon": "res://assets/ui/items/sleep_dart.svg", "equipment": false, "equippable": true, "usable": true},
	"axe": {"name": "Hache du camp", "description": "Clic gauche : frapper.\nCtrl + clic gauche : lancer.\nF près de la hache : la récupérer.", "icon": "res://assets/ui/items/axe.svg", "equipment": true},
	"first_echo": {"name": "Éclat du Premier Écho", "description": "Un fragment ardent aux reflets flamboyants.\nUn écho de souffle igné y vibre intensément.\nMaintenez le clic droit pour viser. Relâchez pour lancer la boule de feu.", "icon": "res://assets/ui/items/first_echo.svg", "equipment": true},
	"trout": {"name": "Truite du ruisseau", "description": "Un poisson fraîchement pêché.\nNourrissant, redonne 8 PV.\nUne ressource pour les futures recettes.", "icon": "res://assets/ui/items/trout.svg", "equipment": false, "consumable": true, "heal": 8.0},
	"mushroom": {"name": "Champignon des lueurs", "description": "Récolté dans les sous-bois.\nComestible, redonne 3 PV.\nUne ressource pour les futures recettes.", "icon": "res://assets/ui/items/mushroom.svg", "equipment": false, "consumable": true, "heal": 3.0},
	"blueberry": {"name": "Bleuets sauvages", "description": "De petites baies sucrées cueillies sur un bleuetier.\nComestibles, redonnent 4 PV.", "icon": "res://assets/ui/items/blueberry.svg", "equipment": false, "consumable": true, "heal": 4.0},
	"raspberry": {"name": "Framboises des bois", "description": "Des baies parfumées cueillies sur une ronce sauvage.\nComestibles, redonnent 4 PV.", "icon": "res://assets/ui/items/raspberry.svg", "equipment": false, "consumable": true, "heal": 4.0},
	"golden_berry": {"name": "Baies dorées", "description": "Des baies lumineuses et tonifiantes.\nComestibles, redonnent 5 PV.", "icon": "res://assets/ui/items/golden_berry.svg", "equipment": false, "consumable": true, "heal": 5.0},
	"chicken": {"name": "Cuisse de poulet rôti", "description": "Une cuisse de poulet dorée à la broche sur le feu de camp.\nSavoureuse, redonne 12 PV.\nUn ingrédient de choix pour cuisiner au chaudron.", "icon": "res://assets/ui/items/chicken.svg", "equipment": false, "consumable": true, "heal": 12.0},
	"chicken_breast": {"name": "Poitrine de poulet rôti", "description": "Une poitrine dorée à la broche.\nRedonne 12 PV et peut servir au ragoût forestier.", "icon": "res://assets/ui/items/chicken.svg", "equipment": false, "consumable": true, "heal": 12.0},
	"hunter_stew": {"name": "Ragoût forestier au poulet", "description": "Un savoureux ragoût mijoté au chaudron avec du poulet rôti, des champignons des lueurs et des fruits sauvages.\nPlat réconfortant, redonne 35 PV.", "icon": "res://assets/ui/items/hunter_stew.svg", "equipment": false, "consumable": true, "heal": 35.0},
	"fishing_rod": {"name": "Canne à pêche", "description": "Une canne en noisetier et son moulinet.\nCliquez pour équiper ou ranger cet outil.", "icon": "res://assets/ui/items/fishing_rod.svg", "equipment": true}
}
const FRUIT_IDS := ["blueberry", "raspberry", "golden_berry"]
const RECIPES := {
	"sleep_dart": {
		"id": "sleep_dart", "name": "Fléchettes soporifiques ×10", "result_id": "sleep_dart", "result_quantity": 10,
		"discovery_flag": "story/cave_guardian/recipe", "verb": "Fabriquer",
		"description": "Une décoction soporifique sur une tige creuse. Les tiges de support sont près du chaudron.",
		"ingredients": [
			{"type": "item", "id": "dream_fern", "quantity": 2, "label": "Tiges de Fougère des songes"},
			{"type": "item", "id": "mushroom", "quantity": 1, "label": "Champignon des lueurs"}
		]
	},
	"hunter_stew": {
		"id": "hunter_stew",
		"name": "Ragoût forestier au poulet",
		"result_id": "hunter_stew",
		"result_quantity": 1,
		"ingredients": [
			{"type": "any", "ids": ["chicken", "chicken_breast"], "quantity": 1, "label": "Cuisse ou poitrine de poulet"},
			{"type": "item", "id": "mushroom", "quantity": 1, "label": "Champignon"},
			{"type": "any", "ids": ["blueberry", "raspberry", "golden_berry"], "quantity": 1, "label": "Bleuets, framboises ou baies dorées"}
		]
	}
}
var stacks: Array[Dictionary] = []
var gold := 0

func add_gold(amount: int) -> void:
	if amount <= 0: return
	gold += amount
	changed.emit()

func buy_item(id: String, price: int) -> bool:
	if price <= 0 or gold < price: return false
	if not add_item(id): return false
	gold -= price
	changed.emit()
	return true

var equipment: Array[String] = []
var collected: Dictionary = {}
var equipped := ""
var axe_state: Dictionary = {}
var is_open := false
var target: Node3D
var ui: CanvasLayer
var cooking_ui: CanvasLayer
var previous_mouse := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	ui = preload("res://scripts/inventory_ui.gd").new()
	ui.name = "InventoryUI"
	add_child(ui)
	cooking_ui = preload("res://scripts/cooking_ui.gd").new()
	add_child(cooking_ui)

func add_item(id: String, quantity := 1) -> bool:
	if not ITEMS.has(id) or quantity <= 0: return false
	if ITEMS[id].equipment:
		if quantity != 1 or equipment.has(id) or equipment.size() >= 6: return false
		equipment.append(id)
	else:
		var space := (CAPACITY - stacks.size()) * STACK_LIMIT
		for stack in stacks:
			if stack.id == id: space += STACK_LIMIT - int(stack.quantity)
		if quantity > space: return false
		var remaining := quantity
		for stack in stacks:
			if stack.id != id: continue
			var moved := mini(STACK_LIMIT - int(stack.quantity), remaining)
			stack.quantity += moved
			remaining -= moved
		while remaining > 0:
			var moved := mini(STACK_LIMIT, remaining)
			stacks.append({"id": id, "quantity": moved})
			remaining -= moved
	changed.emit()
	return true

func get_item_count(id: String) -> int:
	var total := 0
	for stack in stacks:
		if stack.id == id:
			total += int(stack.quantity)
	return total

func get_any_item_count(ids: Array) -> int:
	var total := 0
	for stack in stacks:
		if stack.id in ids:
			total += int(stack.quantity)
	return total

func remove_item(id: String, quantity := 1) -> bool:
	if quantity <= 0 or get_item_count(id) < quantity:
		return false
	var remaining := quantity
	var i := stacks.size() - 1
	while i >= 0 and remaining > 0:
		if stacks[i].id == id:
			var take := mini(int(stacks[i].quantity), remaining)
			stacks[i].quantity -= take
			remaining -= take
			if stacks[i].quantity <= 0:
				stacks.remove_at(i)
		i -= 1
	if equipped == id and get_item_count(id) == 0:
		equipped = ""
	changed.emit()
	return true

func remove_any_item(ids: Array, quantity := 1) -> bool:
	if quantity <= 0 or get_any_item_count(ids) < quantity:
		return false
	var remaining := quantity
	for i in range(stacks.size()):
		if remaining <= 0:
			break
		if stacks[i].id in ids:
			var take := mini(int(stacks[i].quantity), remaining)
			stacks[i].quantity -= take
			remaining -= take
	var j := stacks.size() - 1
	while j >= 0:
		if stacks[j].quantity <= 0:
			stacks.remove_at(j)
		j -= 1
	changed.emit()
	return true

func can_craft(recipe_id := "hunter_stew") -> bool:
	if not RECIPES.has(recipe_id):
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	if not recipe_discovered(recipe_id): return false
	for ing in recipe.ingredients:
		var req_qty: int = int(ing.get("quantity", 1))
		if ing.get("type", "item") == "any":
			if get_any_item_count(ing.get("ids", [])) < req_qty:
				return false
		else:
			if get_item_count(str(ing.get("id", ""))) < req_qty:
				return false
	return true

func recipe_discovered(recipe_id: String) -> bool:
	if not RECIPES.has(recipe_id): return false
	var flag: String = RECIPES[recipe_id].get("discovery_flag", "")
	return flag.is_empty() or bool(collected.get(flag, false))

func use_item(id: String) -> bool:
	if id != "sleep_dart" or get_item_count(id) <= 0: return false
	toggle_equipment(id)
	return true

func get_missing_ingredients(recipe_id := "hunter_stew") -> Array[String]:
	var missing: Array[String] = []
	if not RECIPES.has(recipe_id):
		return missing
	var recipe: Dictionary = RECIPES[recipe_id]
	for ing in recipe.ingredients:
		var req_qty: int = int(ing.get("quantity", 1))
		var have := 0
		if ing.get("type", "item") == "any":
			have = get_any_item_count(ing.get("ids", []))
		else:
			have = get_item_count(str(ing.get("id", "")))
		if have < req_qty:
			missing.append(str(ing.get("label", ing.get("id", ""))))
	return missing

func craft_recipe(recipe_id := "hunter_stew") -> bool:
	if not can_craft(recipe_id):
		var missing := get_missing_ingredients(recipe_id)
		if ui and not missing.is_empty():
			ui.notify("Ingrédients manquants : " + ", ".join(missing))
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var result_id: String = str(recipe.get("result_id", recipe_id))
	var result_qty: int = int(recipe.get("result_quantity", 1))
	var before: Array[Dictionary] = stacks.duplicate(true)
	for ing in recipe.ingredients:
		var req_qty: int = int(ing.get("quantity", 1))
		if ing.get("type", "item") == "any":
			remove_any_item(ing.get("ids", []), req_qty)
		else:
			remove_item(str(ing.get("id", "")), req_qty)
	if not add_item(result_id, result_qty):
		stacks = before
		changed.emit()
		if ui: ui.notify("Inventaire plein : libérez une place pour la préparation")
		return false
	if ui:
		var heal_val := int(ITEMS[result_id].get("heal", 0))
		var healing := " (+%d PV)" % heal_val if heal_val > 0 else ""
		ui.notify("Recette préparée : + %d %s%s" % [result_qty, ITEMS[result_id].name, healing])
	changed.emit()
	return true

func toggle_equipment(id: String) -> void:
	if not equipment.has(id) and not (ITEMS.has(id) and ITEMS[id].get("equippable", false) and get_item_count(id) > 0): return
	equipped = "" if equipped == id else id
	changed.emit()

func has_fireball_relic() -> bool:
	if equipment.has("first_echo"): return true
	for stack in stacks:
		if stack.id == "first_echo": return true
	return false

func consume_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= stacks.size(): return false
	var id: String = stacks[slot_index].id
	return consume_item(id)

func consume_item(id: String) -> bool:
	if not ITEMS.has(id): return false
	var item_data: Dictionary = ITEMS[id]
	if not item_data.get("consumable", false): return false
	
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return false
	
	if player.health >= player.max_health:
		ui.notify("Santé déjà au maximum (%d / %d PV)" % [int(player.max_health), int(player.max_health)])
		return false
		
	var found_index := -1
	for i in range(stacks.size()):
		if stacks[i].id == id:
			found_index = i
			break
			
	if found_index == -1: return false
	
	stacks[found_index].quantity -= 1
	if stacks[found_index].quantity <= 0:
		stacks.remove_at(found_index)
		
	var heal_amount: float = float(item_data.get("heal", 3.0))
	player.heal(heal_amount)
	ui.notify("+ %d PV  (Consommé : %s)" % [int(heal_amount), item_data.name])
	changed.emit()
	return true


func open_cooking(cauldron: Node3D) -> void:
	set_open(true)
	ui.set_open(false)
	cooking_ui.open_menu(cauldron)

func set_open(value: bool) -> void:
	if value == is_open: return
	is_open = value
	if value:
		var qm = get_node_or_null("/root/QuestManager")
		if qm and qm.is_journal_open: qm.set_journal_open(false)
		var dlg = get_node_or_null("/root/DialogueManager")
		if dlg and dlg.is_open: dlg.hide_dialogue()
		previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		var qm = get_node_or_null("/root/QuestManager")
		var dlg = get_node_or_null("/root/DialogueManager")
		var other_open: bool = (qm and qm.is_journal_open) or (dlg and dlg.is_open)
		if not other_open:
			Input.mouse_mode = previous_mouse
	if not value: cooking_ui.hide()
	ui.set_open(value)

func _input(event: InputEvent) -> void:
	# Escape belongs to the pause menu, including while the bag is open.
	if event.is_action("release_mouse"): return
	if event.is_action_pressed("inventory") and not event.is_echo():
		if not get_node("/root/CabinTravel").busy: set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and (event is InputEventMouseMotion or event is InputEventKey):
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	target = null
	var dlg = get_node_or_null("/root/DialogueManager")
	var is_dlg: bool = dlg != null and dlg.is_open
	var qm = get_node_or_null("/root/QuestManager")
	var is_jrn: bool = qm != null and qm.is_journal_open
	if is_open or get_node("/root/CabinTravel").busy or is_dlg or is_jrn:
		ui.set_prompt("")
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return
	var best := INF
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate.can_interact(): continue
		var distance: float = player.global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			target = candidate
	ui.set_prompt("F  ·  " + target.interaction_text() if target else "")
	if target and Input.is_action_just_pressed("interact"):
		target.interact()
