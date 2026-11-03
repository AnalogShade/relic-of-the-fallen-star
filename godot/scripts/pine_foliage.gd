@tool
extends RefCounted
## Shared fir model, including the approved short shoots around its upper trunk.
const PLACEMENTS := "res://scenes/world/sapins_chateau.tscn"
const RETAINED := "res://assets/environment/vegetation/castle_without_old_pines.res"
const COLLISION := "res://assets/environment/vegetation/castle_without_old_pines_shape.res"

static func apply(world: Node3D) -> void:
	var castle := world.get_node_or_null("Sectors/WesternPlains/ChateauDesPlaines/CastlePreserved") as MeshInstance3D
	if castle != null:
		castle.mesh = load(RETAINED) as Mesh
		for shape: CollisionShape3D in castle.find_children("*", "CollisionShape3D", true, false):
			shape.shape = load(COLLISION) as Shape3D
	if not world.has_node("SapinsChateau"):
		world.add_child((load(PLACEMENTS) as PackedScene).instantiate())
