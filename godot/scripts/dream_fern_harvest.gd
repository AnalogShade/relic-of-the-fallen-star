extends "res://scripts/collectible.gd"
## Only a few fronds are picked. The existing fern geometry is never hidden or edited.

func _ready() -> void:
	item_id = "dream_fern"
	quantity = 2
	reach = 1.9
	respawn_time = 180.0
	add_to_group("interactable")
	add_to_group("dream_fern")

func interaction_text() -> String:
	return "Cueillir · Fougère des songes"

func interact() -> void:
	if not can_interact(): return
	var bag := get_node("/root/Inventory")
	if not bag.add_item(item_id, quantity):
		bag.ui.notify("Inventaire plein")
		return
	bag.collected[pickup_id] = Time.get_unix_time_from_system() + respawn_time
	bag.ui.notify("+ 2 tiges · Fougère des songes")
	# is_harvested() uses this timestamp; no timer can accidentally hide the plant.
