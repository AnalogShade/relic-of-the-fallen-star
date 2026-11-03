extends MeshInstance3D
## Deux cuisses puis deux poitrines, avec un départ entre chaque prise.
## Le modèle reste visible sur la broche.

@export var pickup_id := "camp/roast_chicken"
@export var reach := 2.6

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("camp_chicken")

var awaiting_departure := false
const PORTIONS := ["chicken", "chicken", "chicken_breast", "chicken_breast"]

func portions_taken() -> int:
	var inventory := get_node_or_null("/root/Inventory")
	if not inventory: return 0
	var state = inventory.collected.get(pickup_id, {})
	if state is Dictionary: return clampi(int(state.get("portions", 0)), 0, 4)
	return 0

func is_harvested() -> bool:
	return portions_taken() >= 4

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if awaiting_departure and player and player.global_position.distance_to(global_position) > reach + 1.0:
		awaiting_departure = false

func can_interact() -> bool:
	if not is_visible_in_tree():
		return false
	if is_harvested() or awaiting_departure:
		return false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return false
	if "rest_state" in player and player.rest_state != "":
		return false
	if "swimming" in player and player.swimming:
		return false
	if "is_attacking" in player and player.is_attacking:
		return false
	return player.global_position.distance_to(global_position) <= reach

func interaction_text() -> String:
	return "Prendre une %s (%d / 4)" % ["cuisse de poulet" if portions_taken() < 2 else "poitrine de poulet", portions_taken() + 1]

func interact() -> void:
	if not can_interact():
		return
	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or is_harvested():
		return
	var taken := portions_taken()
	var portion_id: String = PORTIONS[taken]
	if not inventory.add_item(portion_id, 1):
		if inventory.ui:
			inventory.ui.notify("Inventaire plein")
		return
	inventory.collected[pickup_id] = {"portions": taken + 1}
	awaiting_departure = true
	if inventory.ui:
		inventory.ui.notify("+ 1 %s · %s" % [inventory.ITEMS[portion_id].name, "Poulet épuisé" if taken == 3 else "Éloignez-vous pour reprendre une portion"])
