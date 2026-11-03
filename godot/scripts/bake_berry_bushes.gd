@tool
extends SceneTree

const BLEUETIER := "res://assets/environment/vegetation/arbuste_bleuetier.glb"
const FRAMBOISIER := "res://assets/environment/vegetation/arbuste_ronce_framboises.glb"
const BUISSON_DORE := "res://assets/environment/vegetation/arbuste_buisson_dore.glb"
const OUTPUT_SCENE := "res://scenes/world/arbustes_a_baies.tscn"

func _initialize():
	call_deferred("bake")

func bake():
	print("--- RE-BAKING BERRY BUSHES CLEANLY ---")
	var world_scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	
	var space = world.get_world_3d().direct_space_state
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260915
	
	var models = [BLEUETIER, FRAMBOISIER, BUISSON_DORE]
	var loaded_scenes := {}
	for m in models:
		loaded_scenes[m] = load(m)
		
	# Root container node for all bushes
	var container := Node3D.new()
	container.name = "ArbustesABaies"
	container.set_script(load("res://scripts/arbustes_a_baies.gd"))
	
	# Zone definitions based on user sketch lines
	# Zone 1: Long curved path south of clearing to west river bank
	var pts_zone1 := [
		Vector2(-52, 16), Vector2(-44, 22), Vector2(-34, 25), 
		Vector2(-24, 24), Vector2(-15, 22), Vector2(-5, 19)
	]
	# Zone 2: Upper-west river bank near clearing
	var pts_zone2 := [Vector2(-10, 2), Vector2(-6, 4)]
	# Zone 3: North-west forest edge / castle path
	var pts_zone3 := [Vector2(-56, -12), Vector2(-54, -6)]
	# Zone 4: East river bank hook
	var pts_zone4 := [
		Vector2(8, 12), Vector2(16, 14), Vector2(22, 17), Vector2(18, 21)
	]
	# Zone 5: South-east woodland glades
	var pts_zone5 := [Vector2(34, 22), Vector2(40, 28), Vector2(48, 25)]
	
	var placed_positions: Array[Vector3] = []
	var type_counters := {
		"Bleuetier": 0,
		"Framboisier": 0,
		"BuissonDore": 0
	}
	
	# Helper to test ground and min distance
	var try_place_bush = func(candidate_xz: Vector2, preferred_model: int = -1) -> bool:
		for existing in placed_positions:
			if candidate_xz.distance_to(Vector2(existing.x, existing.z)) < 2.4:
				return false
				
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(candidate_xz.x, 150.0, candidate_xz.y),
			Vector3(candidate_xz.x, -10.0, candidate_xz.y),
			1
		)
		var hit = space.intersect_ray(q)
		if hit.is_empty():
			return false
		if hit.position.y < 0.6: # Avoid river water bed
			return false
		if hit.normal.y < 0.68: # Avoid excessively steep rock faces
			return false
			
		var model_path = models[preferred_model if preferred_model >= 0 else rng.randi() % models.size()]
		var scene_res = loaded_scenes[model_path]
		var inst: Node3D = scene_res.instantiate()
		
		# Naming cleanly per category
		var type_tag = "Bleuetier" if "bleuetier" in model_path else ("Framboisier" if "framboise" in model_path else "BuissonDore")
		type_counters[type_tag] += 1
		inst.name = "%s_%02d" % [type_tag, type_counters[type_tag]]
		
		# Scale variation (0.78x to 1.22x with slight vertical proportion variation)
		var scale_base = rng.randf_range(0.78, 1.22)
		var scale_y = scale_base * rng.randf_range(0.94, 1.08)
		var scale_vec = Vector3(scale_base, scale_y, scale_base)
		
		# Orientation variation (random Y rotation)
		var rot_y = rng.randf_range(0, TAU)
		var basis = Basis(Vector3.UP, rot_y)
		
		# Position slightly sunken into terrain so base sits firmly on ground
		var final_pos = hit.position - Vector3.UP * 0.04
		inst.transform = Transform3D(basis.scaled(scale_vec), final_pos)
		
		# Add to container as clean instance. DO NOT set c.owner on internal subnodes!
		container.add_child(inst)
		inst.owner = container
			
		placed_positions.append(final_pos)
		return true

	# 1. Populate Zone 1 (Long southern arc: ~18 bushes)
	print("Populating Zone 1 (Grand arc Sud-Ouest)...")
	for i in range(pts_zone1.size() - 1):
		var p1 = pts_zone1[i]
		var p2 = pts_zone1[i+1]
		var seg_len = p1.distance_to(p2)
		var steps = int(ceil(seg_len / 2.8))
		for s in range(steps):
			var t = (s + rng.randf_range(0.1, 0.9)) / float(steps)
			var center = p1.lerp(p2, t)
			for attempt in range(3):
				var offset = Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.5, 3.5))
				if try_place_bush.call(center + offset, rng.randi() % 3):
					break

	# 2. Populate Zone 2 (Berge Ouest clairière: ~4 bushes)
	print("Populating Zone 2 (Berge Ouest clairière)...")
	for p in pts_zone2:
		for attempt in range(4):
			var offset = Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
			try_place_bush.call(p + offset, 0) # Bleuetiers near river

	# 3. Populate Zone 3 (Lisière Nord-Ouest: ~4 bushes)
	print("Populating Zone 3 (Lisière Nord-Ouest)...")
	for p in pts_zone3:
		for attempt in range(4):
			var offset = Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			try_place_bush.call(p + offset, 1) # Framboisiers in forest edge

	# 4. Populate Zone 4 (Crochet Rive Est: ~8 bushes)
	print("Populating Zone 4 (Crochet Rive Est)...")
	for i in range(pts_zone4.size() - 1):
		var p1 = pts_zone4[i]
		var p2 = pts_zone4[i+1]
		var seg_len = p1.distance_to(p2)
		var steps = int(ceil(seg_len / 2.5))
		for s in range(steps):
			var t = (s + rng.randf_range(0.1, 0.9)) / float(steps)
			var center = p1.lerp(p2, t)
			var offset = Vector2(rng.randf_range(-2.8, 2.8), rng.randf_range(-2.8, 2.8))
			try_place_bush.call(center + offset, rng.randi() % 3)

	# 5. Populate Zone 5 (Clairières Sud-Est: ~6 bushes)
	print("Populating Zone 5 (Clairières Sud-Est)...")
	for p in pts_zone5:
		for attempt in range(3):
			var offset = Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			try_place_bush.call(p + offset, 2) # Buissons dorés

	print("Total bushes placed:", container.get_child_count())
	print("Counts:", type_counters)
	
	# Pack and save scene
	var packed := PackedScene.new()
	var err = packed.pack(container)
	if err == OK:
		ResourceSaver.save(packed, OUTPUT_SCENE)
		print("SUCCESS: Cleanly saved arbustes_a_baies.tscn to ", OUTPUT_SCENE)
	else:
		print("ERROR packing scene:", err)
		
	container.queue_free()
	world.queue_free()
	quit()
