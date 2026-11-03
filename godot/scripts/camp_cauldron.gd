extends Node3D
## Chaudron au bout du camp des bandits permettant de préparer des recettes
## à partir des ingrédients de l'inventaire (poulet, champignons, fruits).

@export var recipe_id := "hunter_stew"
@export var reach := 3.2

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cauldron")

func can_interact() -> bool:
	if not is_visible_in_tree():
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
	return "Chaudron · Voir les recettes"

func interact() -> void:
	if not can_interact():
		return
	var inventory := get_node_or_null("/root/Inventory")
	if inventory:
		var access := preload("res://scripts/cave_access.gd")
		if not access.has_fact(self, access.RECIPE):
			access.remember(self, access.RECIPE)
			var pages: Array[String] = ["Un feuillet taché est coincé sous un bol, à côté de quelques tiges creuses.\n\n« Fléchette soporifique : faire macérer deux tiges de Fougère des songes avec un champignon des lueurs pour lier le suc. Enduire la pointe. Provoque un sommeil profond, sans poison mortel. »"]
			get_node("/root/DialogueManager").show_dialogue("Naël", "Un feuillet près du chaudron", pages, func():
				if is_instance_valid(self) and can_interact(): inventory.open_cooking(self)
			)
		else:
			inventory.open_cooking(self)
