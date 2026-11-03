extends MeshInstance3D
var axe: Node3D
func _ready() -> void:
	var bag := get_node("/root/Inventory")
	if bag.axe_state.get("taken", false) or bag.equipment.has("axe"):
		remove_original_axe()
		return
	axe = preload("res://scripts/world_axe.gd").new()
	axe.source_billot = self
	add_child(axe)
	axe.position = Vector3(0.015, 0.185, 0.0)

func remove_original_axe() -> void:
	var replacement := preload("res://assets/items/billot_sans_hache.glb").instantiate()
	var part := replacement.find_child("Camp_Billot_Hache_Rochers", true, false) as MeshInstance3D
	if part: mesh = part.mesh
	replacement.free()

