@tool
extends Node3D
## Current Blender composition with three simplified collision bodies.
## Toggle to restore the original tower, stairs and their original collision.
@export var nouvelles_marches: bool = true:
	set(value):
		nouvelles_marches = value
		if is_inside_tree():
			_apply_appearance()

func _ready() -> void:
	_apply_appearance()

func _apply_appearance() -> void:
	apply_visuals(self, nouvelles_marches)
	for branch_name in ["Art", "MarchesNaturelles", "RuineSommet"]:
		var branch := get_node_or_null(NodePath(branch_name))
		if branch:
			_set_collisions(branch, not nouvelles_marches if branch_name == "Art" else nouvelles_marches)

## Also used by the title's script-free landscape, before entering the scene tree.
static func apply_visuals(vigie: Node, use_new_model: bool) -> void:
	var old_art := vigie.get_node_or_null("Art") as Node3D
	if old_art != null:
		old_art.visible = not use_new_model
	for mesh in vigie.find_children("VigieAscent*", "MeshInstance3D", true, false):
		mesh.visible = false
	for pattern in ["VigieSteps*", "VigieLandings*", "VigieMoss*"]:
		for mesh in vigie.find_children(pattern, "MeshInstance3D", true, false):
			mesh.visible = not use_new_model
	var replacement := vigie.get_node_or_null("MarchesNaturelles") as Node3D
	if replacement != null:
		replacement.visible = use_new_model
	var summit := vigie.get_node_or_null("RuineSommet") as Node3D
	if summit != null:
		summit.visible = use_new_model

func _set_collisions(branch: Node, enabled: bool) -> void:
	for shape in branch.find_children("*", "CollisionShape3D", true, false):
		shape.set_deferred("disabled", not enabled)
