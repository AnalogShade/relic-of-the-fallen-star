extends Node3D

const ASSETS := "res://assets/environment/vegetation_corrompue/"
const PREFABS := "res://scenes/vegetation_corrompue/"
const OUTPUT := "res://scenes/world/foret_malefique.tscn"

var rng := RandomNumberGenerator.new()
var world: Node3D
var space_state: PhysicsDirectSpaceState3D
var excluded_rids: Array[RID] = []

func _ready() -> void:
	rng.seed = 20260919
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREFABS))
	
	print("--- Step 1: Building Prefabs ---")
	var prefabs := create_prefabs()
	
	print("--- Step 2: Instantiating World for Physics Sampling ---")
	world = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	world.get_node("Original/HUD").hide()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	
	for i in range(25): await get_tree().physics_frame
	space_state = world.get_world_3d().direct_space_state
	
	print("--- Step 3: Generating Corrupted Forest Layout ---")
	var foret := Node3D.new()
	foret.name = "ForetMalefique"
	
	var grp_arbres := Node3D.new(); grp_arbres.name = "ArbresMacabres"; foret.add_child(grp_arbres); grp_arbres.owner = foret
	var grp_sapins := Node3D.new(); grp_sapins.name = "SapinsCorrompus"; foret.add_child(grp_sapins); grp_sapins.owner = foret
	var grp_bois := Node3D.new(); grp_bois.name = "SouchesEtTroncs"; foret.add_child(grp_bois); grp_bois.owner = foret
	var grp_roches := Node3D.new(); grp_roches.name = "RochesMalefiques"; foret.add_child(grp_roches); grp_roches.owner = foret
	var grp_ronces := Node3D.new(); grp_ronces.name = "Ronces"; foret.add_child(grp_ronces); grp_ronces.owner = foret
	var grp_feuilles := Node3D.new(); grp_feuilles.name = "FeuillesMortes"; foret.add_child(grp_feuilles); grp_feuilles.owner = foret
	
	# Placement tracking
	var tree_points: Array[Vector2] = []
	var rock_points: Array[Vector2] = []
	
	# Zone boundaries: Western Hillside Clearing (opposite from beach, circled on left by user)
	# Zone boundaries: Western Hillside expanded to map boundaries
	# Extent X: [-282.0, -140.0], Z: [-280.0, -95.0]
	var x_min := -282.0
	var x_max := -140.0
	var z_min := -280.0
	var z_max := -95.0
	
	# 1. Main Canopy Trees: Large and medium macabre trees & leaning dead trees
	# Target: 75 dead deciduous trees
	var tree_types := ["arbre_macabre_grand", "arbre_macabre_moyen", "arbre_mort_penche"]
	var count_trees := 0
	for attempt in range(2500):
		if count_trees >= 75: break
		var px := rng.randf_range(x_min, x_max)
		var pz := rng.randf_range(z_min, z_max)
		var p2 := Vector2(px, pz)
		
		# Spacing from other trees
		var too_close := false
		for other in tree_points:
			if p2.distance_to(other) < 5.8:
				too_close = true
				break
		if too_close: continue
		
		var hit := safe_ground(p2, 2.0)
		if hit.is_empty(): continue
		
		var kind: String = tree_types[rng.randi() % tree_types.size()]
		var inst: Node3D = prefabs[kind].instantiate()
		inst.name = "%s_%02d" % [kind, count_trees + 1]
		grp_arbres.add_child(inst)
		inst.owner = foret
		
		inst.position = hit.position - Vector3.UP * 0.04
		inst.rotation.y = rng.randf_range(0, TAU)
		var sc := rng.randf_range(0.82, 1.18)
		inst.scale = Vector3(sc, sc * rng.randf_range(0.92, 1.08), sc)
		
		tree_points.append(p2)
		count_trees += 1
	
	# 2. Corrupted & Skeletal Pines
	# Target: 50 pines interspersed
	var pine_types := ["sapin_corrompu_grand", "sapin_squelettique_tordu"]
	var count_pines := 0
	for attempt in range(1800):
		if count_pines >= 50: break
		var px := rng.randf_range(x_min, x_max)
		var pz := rng.randf_range(z_min, z_max)
		var p2 := Vector2(px, pz)
		
		var too_close := false
		for other in tree_points:
			if p2.distance_to(other) < 4.8:
				too_close = true
				break
		if too_close: continue
		
		var hit := safe_ground(p2, 1.6)
		if hit.is_empty(): continue
		
		var kind: String = pine_types[rng.randi() % pine_types.size()]
		var inst: Node3D = prefabs[kind].instantiate()
		inst.name = "%s_%02d" % [kind, count_pines + 1]
		grp_sapins.add_child(inst)
		inst.owner = foret
		
		inst.position = hit.position - Vector3.UP * 0.04
		inst.rotation.y = rng.randf_range(0, TAU)
		var sc := rng.randf_range(0.80, 1.20)
		inst.scale = Vector3(sc, sc * rng.randf_range(0.95, 1.10), sc)
		
		tree_points.append(p2)
		count_pines += 1
	
	# 3. Corrupted Rock Monoliths, Plateaus & Shards
	var monolith_count := 0
	for attempt in range(600):
		if monolith_count >= 12: break
		var px := rng.randf_range(x_min + 5, x_max - 5)
		var pz := rng.randf_range(z_min + 5, z_max - 5)
		var p2 := Vector2(px, pz)
		var too_close := false
		for other in rock_points:
			if p2.distance_to(other) < 14.0: too_close = true; break
		for other in tree_points:
			if p2.distance_to(other) < 3.8: too_close = true; break
		if too_close: continue
		var hit := safe_ground(p2, 2.0)
		if hit.is_empty(): continue
		
		var inst: Node3D = prefabs["roche_malefique_monolithe"].instantiate()
		inst.name = "RocheMonolithe_%02d" % [monolith_count + 1]
		grp_roches.add_child(inst)
		inst.owner = foret
		inst.position = hit.position - Vector3.UP * 0.1
		inst.rotation.y = rng.randf_range(0, TAU)
		inst.rotation.x = rng.randf_range(-0.08, 0.08)
		inst.rotation.z = rng.randf_range(-0.08, 0.08)
		var sc := rng.randf_range(0.90, 1.35)
		inst.scale = Vector3.ONE * sc
		rock_points.append(p2)
		monolith_count += 1

	var plateau_count := 0
	for attempt in range(600):
		if plateau_count >= 20: break
		var px := rng.randf_range(x_min + 4, x_max - 4)
		var pz := rng.randf_range(z_min + 4, z_max - 4)
		var p2 := Vector2(px, pz)
		var hit := safe_ground(p2, 2.2)
		if hit.is_empty(): continue
		var inst: Node3D = prefabs["roche_malefique_plateau"].instantiate()
		inst.name = "RochePlateau_%02d" % [plateau_count + 1]
		grp_roches.add_child(inst)
		inst.owner = foret
		inst.position = hit.position - Vector3.UP * 0.08
		inst.rotation.y = rng.randf_range(0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(0.85, 1.25)
		plateau_count += 1

	var eclats_count := 0
	for attempt in range(800):
		if eclats_count >= 30: break
		var px := rng.randf_range(x_min + 3, x_max - 3)
		var pz := rng.randf_range(z_min + 3, z_max - 3)
		var p2 := Vector2(px, pz)
		var hit := safe_ground(p2, 1.4)
		if hit.is_empty(): continue
		var inst: Node3D = prefabs["roche_eclats_amas"].instantiate()
		inst.name = "RocheEclats_%02d" % [eclats_count + 1]
		grp_roches.add_child(inst)
		inst.owner = foret
		inst.position = hit.position - Vector3.UP * 0.05
		inst.rotation.y = rng.randf_range(0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)
		eclats_count += 1

	# 4. Hollow & Gnarled Stumps + Fallen Split Logs
	var wood_types := ["souche_evidee_dechiquetee", "souche_basse_noueuse", "tronc_couche_eclate"]
	var wood_count := 0
	for attempt in range(1200):
		if wood_count >= 55: break
		var p2: Vector2
		if rng.randf() < 0.65 and tree_points.size() > 0:
			var base_tree: Vector2 = tree_points[rng.randi() % tree_points.size()]
			p2 = base_tree + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(2.8, 6.5)
		else:
			p2 = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(z_min, z_max))
		
		var hit := safe_ground(p2, 1.6)
		if hit.is_empty(): continue
		
		var kind: String = wood_types[rng.randi() % wood_types.size()]
		var inst: Node3D = prefabs[kind].instantiate()
		inst.name = "%s_%02d" % [kind, wood_count + 1]
		grp_bois.add_child(inst)
		inst.owner = foret
		inst.position = hit.position - Vector3.UP * 0.04
		inst.rotation.y = rng.randf_range(0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(0.85, 1.2)
		wood_count += 1

	# 5. Thorny Brambles (Ronces) around trees, rocks and stumps
	var ronces_count := 0
	for attempt in range(1500):
		if ronces_count >= 80: break
		var p2: Vector2
		if rng.randf() < 0.7 and tree_points.size() > 0:
			var base_tree: Vector2 = tree_points[rng.randi() % tree_points.size()]
			p2 = base_tree + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(1.8, 4.5)
		else:
			p2 = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(z_min, z_max))
		
		var hit := safe_ground(p2, 0.8)
		if hit.is_empty(): continue
		var inst: Node3D = prefabs["ronces_epineuses"].instantiate()
		inst.name = "Ronces_%02d" % [ronces_count + 1]
		grp_ronces.add_child(inst)
		inst.owner = foret
		inst.position = hit.position - Vector3.UP * 0.02
		inst.rotation.y = rng.randf_range(0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(0.75, 1.25)
		ronces_count += 1

	# 6. Dead Leaf Mounds, Drifts & Twigs Carpet
	var leaf_types := ["tas_feuilles_mortes_01", "nappe_feuilles_dispersees", "feuilles_mortes_brindilles"]
	var leaf_count := 0
	for attempt in range(2000):
		if leaf_count >= 130: break
		var p2: Vector2
		if rng.randf() < 0.8 and tree_points.size() > 0:
			var base_tree: Vector2 = tree_points[rng.randi() % tree_points.size()]
			p2 = base_tree + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(1.0, 4.2)
		else:
			p2 = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(z_min, z_max))
		
		var hit := safe_ground(p2, 0.5)
		if hit.is_empty(): continue
		var kind: String = leaf_types[rng.randi() % leaf_types.size()]
		var inst: Node3D = prefabs[kind].instantiate()
		inst.name = "%s_%02d" % [kind, leaf_count + 1]
		grp_feuilles.add_child(inst)
		inst.owner = foret
		inst.position = hit.position - Vector3.UP * 0.015
		inst.rotation.y = rng.randf_range(0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		leaf_count += 1

	print("SUMMARY: Placed ", count_trees, " macabre trees, ", count_pines, " corrupted pines, ",
		monolith_count, " monoliths, ", plateau_count, " plateaus, ", eclats_count, " rock clusters, ",
		wood_count, " stumps/logs, ", ronces_count, " brambles, ", leaf_count, " leaf carpets.")

	# Step 4: Pack and Save foret_malefique.tscn
	for i in range(10): await get_tree().process_frame
	var packed := PackedScene.new()
	var pack_err := packed.pack(foret)
	print("PACK ERR: ", pack_err)
	var save_err := ResourceSaver.save(packed, OUTPUT)
	print("SAVE SCENE ERR: ", save_err)
	
	foret.free()
	world.queue_free()
	print("BAKE_FORET_MALEFIQUE_COMPLETE")
	get_tree().quit()

func safe_ground(p: Vector2, radius: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 150.0, p.y), Vector3(p.x, -20.0, p.y), 1)
	var hit := space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < 0.74 or hit.position.y < 4.0:
		return {}
	
	# Strict map boundary safety buffer: no overhang into the void
	if hit.position.x < -283.5 or hit.position.z < -282.0:
		return {}
	
	# Avoid castle structures and moat
	var collider_path := str(hit.collider.get_path())
	if "Castle" in collider_path or "Chateau" in collider_path:
		return {}

	# Free space check
	var sq := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	sq.shape = sphere
	sq.transform.origin = hit.position + Vector3.UP * (radius + 0.1)
	sq.collision_mask = 1
	var overlaps = space_state.intersect_shape(sq, 1)
	for o in overlaps:
		var collider = o.get("collider")
		if collider != null:
			var path := str(collider.get_path())
			if "Castle" in path or "Chateau" in path:
				return {}
			if not "/Terrain" in path:
				return {}
	return hit

func create_prefabs() -> Dictionary:
	var dict := {}
	
	var configs = {
		"arbre_macabre_grand": {"type": "capsule", "r": 0.52, "h": 5.2, "cy": 2.6},
		"arbre_macabre_moyen": {"type": "capsule", "r": 0.44, "h": 4.2, "cy": 2.1},
		"arbre_mort_penche": {"type": "capsule", "r": 0.42, "h": 3.8, "cy": 1.9},
		"sapin_corrompu_grand": {"type": "capsule", "r": 0.46, "h": 5.6, "cy": 2.8},
		"sapin_squelettique_tordu": {"type": "capsule", "r": 0.38, "h": 4.6, "cy": 2.3},
		"souche_evidee_dechiquetee": {"type": "cylinder", "r": 0.95, "h": 1.6, "cy": 0.8},
		"souche_basse_noueuse": {"type": "cylinder", "r": 0.85, "h": 1.2, "cy": 0.6},
		"tronc_couche_eclate": {"type": "box", "size": Vector3(1.2, 0.9, 4.8), "cy": 0.45},
		"roche_malefique_monolithe": {"type": "cylinder", "r": 0.95, "h": 4.6, "cy": 2.3},
		"roche_malefique_plateau": {"type": "box", "size": Vector3(3.2, 1.4, 2.8), "cy": 0.7},
		"roche_eclats_amas": {"type": "box", "size": Vector3(2.4, 0.9, 2.2), "cy": 0.45},
		"ronces_epineuses": {"type": "none"},
		"tas_feuilles_mortes_01": {"type": "none"},
		"nappe_feuilles_dispersees": {"type": "none"},
		"feuilles_mortes_brindilles": {"type": "none"}
	}
	
	for slug in configs:
		var target_tscn = PREFABS + slug + ".tscn"
		var glb_path = ASSETS + slug + ".glb"
		
		var scene := Node3D.new()
		scene.name = slug.to_pascal_case()
		
		var art: Node3D = load(glb_path).instantiate()
		art.name = "Visual"
		scene.add_child(art)
		art.owner = scene
		
		var cfg = configs[slug]
		if cfg.type != "none":
			var body := StaticBody3D.new()
			body.name = "CollisionBody"
			body.collision_layer = 1
			body.collision_mask = 0
			scene.add_child(body)
			body.owner = scene
			
			var col := CollisionShape3D.new()
			col.name = "Shape"
			
			if cfg.type == "capsule":
				var cap := CapsuleShape3D.new()
				cap.radius = cfg.r
				cap.height = cfg.h
				col.shape = cap
				col.position.y = cfg.cy
			elif cfg.type == "cylinder":
				var cyl := CylinderShape3D.new()
				cyl.radius = cfg.r
				cyl.height = cfg.h
				col.shape = cyl
				col.position.y = cfg.cy
			elif cfg.type == "box":
				var bx := BoxShape3D.new()
				bx.size = cfg.size
				col.shape = bx
				col.position.y = cfg.cy
			
			body.add_child(col)
			col.owner = scene
		
		var packed := PackedScene.new()
		assert(packed.pack(scene) == OK)
		assert(ResourceSaver.save(packed, target_tscn) == OK)
		scene.free()
		
		dict[slug] = load(target_tscn)
		print("Prefab generated: ", target_tscn)
	
	return dict
