@tool
extends Node3D

## Gère la variation procédurale des teintes et l'interaction de cueillette des baies.

func _ready() -> void:
	_apply_tint_variations()
	if not Engine.is_editor_hint():
		_setup_harvest_nodes()

func _setup_harvest_nodes() -> void:
	for child in get_children():
		if not child is Node3D:
			continue
		var bush_name: String = child.name
		var harvest = preload("res://scripts/berry_bush_harvest.gd").new()
		harvest.name = "Harvest"
		harvest.pickup_id = "bush/" + bush_name
		
		if "Bleuetier" in bush_name:
			harvest.item_id = "blueberry"
			harvest.item_name = "les bleuets"
			harvest.quantity = 5
		elif "Framboisier" in bush_name:
			harvest.item_id = "raspberry"
			harvest.item_name = "les framboises"
			harvest.quantity = 5
		elif "BuissonDore" in bush_name:
			harvest.item_id = "golden_berry"
			harvest.item_name = "les baies dorées"
			harvest.quantity = 5
			
		child.add_child(harvest)

func _apply_tint_variations() -> void:
	for child in get_children():
		if not child is Node3D:
			continue
		var seed_val = int(abs(child.position.x * 127.3 + child.position.z * 311.7) * 100.0)
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_val
		
		var tint_factor = rng.randf_range(0.88, 1.12)
		var warm_shift = rng.randf_range(-0.05, 0.05)
		
		for m in child.find_children("*", "MeshInstance3D", true, false):
			var mi = m as MeshInstance3D
			var count = mi.get_surface_override_material_count()
			if count == 0 and mi.mesh:
				count = mi.mesh.get_surface_count()
			for s in range(count):
				var mat = mi.get_active_material(s)
				if mat and mat is StandardMaterial3D:
					var dup = mat.duplicate() as StandardMaterial3D
					var c = dup.albedo_color
					dup.albedo_color = Color(
						clampf(c.r * tint_factor + warm_shift, 0.0, 1.0),
						clampf(c.g * tint_factor, 0.0, 1.0),
						clampf(c.b * tint_factor - warm_shift, 0.0, 1.0),
						1.0
					)
					mi.set_surface_override_material(s, dup)
