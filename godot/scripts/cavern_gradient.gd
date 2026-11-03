@tool
extends Node3D
## Ray-marched density following the cave's measured interior cross-sections.

## Depth into the tunnel where the density starts to grow, in metres.
@export_range(0.0, 3.0, 0.05) var debut_degrade := 0.2:
	set(value):
		debut_degrade = value
		_update_material()
## Depth into the tunnel at maximum density, in metres.
@export_range(0.1, 8.0, 0.05) var noir_complet := 4.8:
	set(value):
		noir_complet = value
		_update_material()
## Higher values keep the entrance clearer for longer.
@export_range(0.2, 4.0, 0.05) var douceur := 2.0:
	set(value):
		douceur = value
		_update_material()

## Extinction at maximum density. The front of the volume remains transparent.
@export_range(0.1, 8.0, 0.1) var densite := 3.2:
	set(value):
		densite = value
		_update_material()

func _ready() -> void:
	set_notify_transform(true)
	_update_material()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		_update_material()

func _update_material() -> void:
	var volume := get_node_or_null("VolumeObscurite") as MeshInstance3D
	if volume == null or not volume.material_override is ShaderMaterial or not is_inside_tree():
		return
	var material := volume.material_override as ShaderMaterial
	material.set_shader_parameter("volume_inverse", global_transform.affine_inverse())
	material.set_shader_parameter("debut_degrade", debut_degrade)
	material.set_shader_parameter("noir_complet", noir_complet)
	material.set_shader_parameter("douceur", douceur)
	material.set_shader_parameter("densite", densite)
