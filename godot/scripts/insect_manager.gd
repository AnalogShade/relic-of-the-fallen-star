class_name InsectManager
extends Node3D

## Gestionnaire global de l'écosystème d'insectes pour Relic of the fallen star.
## Coordonne l'apparition, la transition jour/nuit, le placement des papillons
## aux abords des buissons à baies/clairières, l'essaim de lucioles forestières
## et le budget d'éclairage dynamique pour préserver un framerate optimal.

@export_group("Fireflies Settings")
@export var ambient_fireflies_count: int = 32
@export var firefly_ambient_radius: float = 26.0
@export var max_active_firefly_lights: int = 4

@export_group("Butterflies Settings")
@export var enable_berry_bush_butterflies: bool = true
@export var max_bush_butterfly_groups: int = 12

var player: Node3D
var day_night_cycle: DayNightCycle

var _fireflies: Array[Luciole] = []
var _butterflies: Array[Papillon] = []
var _ambient_firefly_seeds: Array[Vector3] = []

var _current_night_weight: float = 0.0
var _current_day_weight: float = 1.0

var _light_budget_timer: float = 0.0
const LIGHT_BUDGET_INTERVAL: float = 0.15

const LUCIOLE_SCENE = preload("res://scenes/insects/luciole.tscn")
const PAPILLON_SCENE = preload("res://scenes/insects/papillon.tscn")


func _ready() -> void:
	# Retarder la résolution des références pour s'assurer que l'arbre de scène est prêt
	call_deferred("_setup_ecosystem")


func _setup_ecosystem() -> void:
	_find_world_references()
	_spawn_ambient_fireflies()
	_spawn_landmark_fireflies()
	_spawn_butterflies()
	_update_weights_from_cycle()


func _find_world_references() -> void:
	# Recherche du joueur
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null and get_parent() != null:
		var original := get_parent().get_node_or_null("Original")
		if original != null:
			player = original.get_node_or_null("Player") as Node3D
	if player == null and get_parent() != null:
		player = get_parent().get_node_or_null("Player") as Node3D
	if player == null and get_tree() != null and get_tree().root != null:
		player = get_tree().root.find_child("Player", true, false) as Node3D

	# Recherche du DayNightCycle
	if day_night_cycle == null and get_parent() != null:
		var original := get_parent().get_node_or_null("Original")
		if original != null:
			day_night_cycle = original.get_node_or_null("DayNightCycle") as DayNightCycle
	if day_night_cycle == null and get_parent() != null:
		day_night_cycle = get_parent().get_node_or_null("DayNightCycle") as DayNightCycle
	if day_night_cycle == null and get_tree() != null and get_tree().root != null:
		day_night_cycle = get_tree().root.find_child("DayNightCycle", true, false) as DayNightCycle

	if day_night_cycle != null and not day_night_cycle.time_changed.is_connected(_on_time_changed):
		day_night_cycle.time_changed.connect(_on_time_changed)


func _on_time_changed(_current_hour: float) -> void:
	_update_weights_from_cycle()


func _update_weights_from_cycle() -> void:
	var hour := 12.0
	if day_night_cycle != null:
		hour = day_night_cycle.time_of_day

	# Calcul du poids nocturne (0.0 le jour, 1.0 la nuit, transitions douces crépuscule/aube)
	# Crépuscule : 17.5h à 21.0h -> 0.0 vers 1.0
	# Nuit : 21.0h à 4.5h -> 1.0
	# Aube : 4.5h à 7.5h -> 1.0 vers 0.0
	# Jour : 7.5h à 17.5h -> 0.0
	if hour >= 21.0 or hour <= 4.5:
		_current_night_weight = 1.0
	elif hour > 17.5 and hour < 21.0:
		_current_night_weight = smoothstep(17.5, 21.0, hour)
	elif hour > 4.5 and hour < 7.5:
		_current_night_weight = 1.0 - smoothstep(4.5, 7.5, hour)
	else:
		_current_night_weight = 0.0

	# Poids diurne (inverse poétique)
	if hour >= 8.0 and hour <= 17.0:
		_current_day_weight = 1.0
	elif hour > 17.0 and hour < 19.5:
		_current_day_weight = 1.0 - smoothstep(17.0, 19.5, hour)
	elif hour > 5.5 and hour < 8.0:
		_current_day_weight = smoothstep(5.5, 8.0, hour)
	else:
		_current_day_weight = 0.0

	# Mise à jour des insectes
	for firefly in _fireflies:
		if is_instance_valid(firefly):
			firefly.night_weight = _current_night_weight

	for butterfly in _butterflies:
		if is_instance_valid(butterfly):
			butterfly.day_weight = _current_day_weight


func _spawn_ambient_fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 94821

	var fireflies_root := Node3D.new()
	fireflies_root.name = "AmbientFireflies"
	add_child(fireflies_root)

	for i in range(ambient_fireflies_count):
		var f := LUCIOLE_SCENE.instantiate() as Luciole
		f.name = "Firefly_Ambient_%02d" % i
		# 75% solaires (dorées), 25% célestes (bleutées)
		f.variant = "celeste" if (i % 4 == 3) else "solaire"
		f.roam_radius = rng.randf_range(1.8, 3.2)
		f.float_speed = rng.randf_range(0.7, 1.1)
		f.base_scale_val = rng.randf_range(0.85, 1.25)
		f.random_seed = rng.randi()

		var offset := Vector3(
			rng.randf_range(-firefly_ambient_radius, firefly_ambient_radius),
			rng.randf_range(1.0, 4.0),
			rng.randf_range(-firefly_ambient_radius, firefly_ambient_radius)
		)
		_ambient_firefly_seeds.append(offset)

		fireflies_root.add_child(f)
		_fireflies.append(f)

		var base_pos := player.global_position if player != null else Vector3.ZERO
		f.global_position = base_pos + offset
		f.home_position = f.global_position
		f.night_weight = _current_night_weight


func _spawn_landmark_fireflies() -> void:
	var landmarks_root := Node3D.new()
	landmarks_root.name = "LandmarkFireflies"
	add_child(landmarks_root)

	var spots := [
		# Clairière sacrée de la Relique
		{"pos": Vector3(6.8, 3.2, -9.4), "count": 6, "variant": "solaire", "radius": 3.8},
		{"pos": Vector3(7.2, 3.6, -8.6), "count": 3, "variant": "celeste", "radius": 2.5},
		# Ruisseau de la forêt
		{"pos": Vector3(12.5, 1.8, -2.5), "count": 3, "variant": "celeste", "radius": 2.2},
		{"pos": Vector3(15.0, 1.6, 5.5), "count": 3, "variant": "solaire", "radius": 2.5},
		# Entrée de la caverne mystérieuse
		{"pos": Vector3(38.5, 3.2, -47.5), "count": 4, "variant": "celeste", "radius": 3.0}
	]

	var idx := 0
	for spot in spots:
		var center: Vector3 = spot["pos"]
		var count: int = spot["count"]
		var var_type: String = spot["variant"]
		var rad: float = spot["radius"]

		for i in range(count):
			var f := LUCIOLE_SCENE.instantiate() as Luciole
			f.name = "Firefly_Landmark_%02d" % idx
			idx += 1
			f.variant = var_type
			f.roam_radius = rad * 0.7
			f.float_speed = randf_range(0.75, 1.15)
			f.base_scale_val = randf_range(0.9, 1.3)

			var ang := randf_range(0.0, TAU)
			var dist := randf_range(0.5, rad)
			var pos := center + Vector3(sin(ang) * dist, randf_range(0.5, 2.0), cos(ang) * dist)

			landmarks_root.add_child(f)
			_fireflies.append(f)

			f.global_position = pos
			f.home_position = pos
			f.night_weight = _current_night_weight

func _spawn_butterflies() -> void:
	var butterflies_root := Node3D.new()
	butterflies_root.name = "Butterflies"
	add_child(butterflies_root)

	var butterfly_index := 0
	var species_list := ["morpho", "monarque", "emeraude"]

	# 1. Autour des buissons à baies (ArbustesABaies)
	if enable_berry_bush_butterflies:
		var arbustes_node := get_tree().root.find_child("ArbustesABaies", true, false)
		if arbustes_node != null:
			var bushes: Array[Node3D] = []
			for child in arbustes_node.get_children():
				if child is Node3D:
					bushes.append(child as Node3D)

			var step := maxi(1, bushes.size() / max_bush_butterfly_groups)
			for i in range(0, bushes.size(), step):
				var bush := bushes[i]
				var bush_name := bush.name
				var group_size := 2 if (i % 2 == 0) else 1

				for g in range(group_size):
					var p := PAPILLON_SCENE.instantiate() as Papillon
					p.name = "Butterfly_Bush_%02d" % butterfly_index
					butterfly_index += 1

					# Choix de l'espèce assortie au buisson
					if "Bleuetier" in bush_name:
						p.species = "morpho" if g == 0 else "emeraude"
					elif "Framboisier" in bush_name:
						p.species = "monarque" if g == 0 else "morpho"
					else: # Buisson doré
						p.species = "monarque" if g == 0 else "emeraude"

					p.roam_radius = randf_range(1.6, 2.6)
					p.flight_speed = randf_range(1.1, 1.45)
					p.base_scale_val = randf_range(0.88, 1.18)

					butterflies_root.add_child(p)
					_butterflies.append(p)

					var offset := Vector3(randf_range(-1.2, 1.2), randf_range(0.8, 1.6), randf_range(-1.2, 1.2))
					p.global_position = bush.global_position + offset
					p.home_position = p.global_position
					p.day_weight = _current_day_weight

	# 2. Clairières et lisières de forêt ensoleillées
	var open_spots := [
		# Campement de l'herboriste Maelor
		{"pos": Vector3(-8.5, 3.8, 13.5), "species": "morpho", "radius": 2.2},
		{"pos": Vector3(-6.2, 3.6, 11.2), "species": "monarque", "radius": 2.0},
		# Sentier fleuri d'entrée de forêt
		{"pos": Vector3(-5.0, 3.5, 7.5), "species": "emeraude", "radius": 2.5},
		{"pos": Vector3(-12.0, 4.0, 5.0), "species": "morpho", "radius": 2.4},
		{"pos": Vector3(-2.0, 2.5, 18.0), "species": "monarque", "radius": 2.2}
	]

	for spot in open_spots:
		var p := PAPILLON_SCENE.instantiate() as Papillon
		p.name = "Butterfly_Open_%02d" % butterfly_index
		butterfly_index += 1

		p.species = spot["species"]
		p.roam_radius = spot["radius"]
		p.flight_speed = randf_range(1.1, 1.4)
		p.base_scale_val = randf_range(0.9, 1.2)

		butterflies_root.add_child(p)
		_butterflies.append(p)

		p.global_position = spot["pos"]
		p.home_position = spot["pos"]
		p.day_weight = _current_day_weight


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Si le joueur est actif, déplacer doucement l'enveloppe ambiante des lucioles avec lui
	if player != null and _current_night_weight > 0.001:
		_wrap_ambient_fireflies()

	# Contrôle périodique du budget d'éclairage des lucioles
	_light_budget_timer += delta
	if _light_budget_timer >= LIGHT_BUDGET_INTERVAL:
		_light_budget_timer = 0.0
		_update_light_budget()


func _wrap_ambient_fireflies() -> void:
	var p_pos := player.global_position
	var r := firefly_ambient_radius
	var count := mini(ambient_fireflies_count, _ambient_firefly_seeds.size())

	for i in range(count):
		var f := _fireflies[i]
		if not is_instance_valid(f):
			continue

		var seed_offset := _ambient_firefly_seeds[i]
		var target_x := p_pos.x + seed_offset.x
		var target_z := p_pos.z + seed_offset.z
		var target_y := p_pos.y + seed_offset.y

		# Enveloppage torique doux pour que les lucioles restent toujours autour du joueur en forêt
		var dx := f.home_position.x - p_pos.x
		var dz := f.home_position.z - p_pos.z

		if absf(dx) > r:
			f.home_position.x = p_pos.x - signf(dx) * (r * 0.95)
			f.global_position.x = f.home_position.x
		if absf(dz) > r:
			f.home_position.z = p_pos.z - signf(dz) * (r * 0.95)
			f.global_position.z = f.home_position.z

		# Suivi vertical progressif de la topographie
		f.home_position.y = lerpf(f.home_position.y, target_y, 0.05)


func _update_light_budget() -> void:
	if _current_night_weight <= 0.02 or player == null:
		# Éteindre toutes les lumières en journée pour zéro coût de calcul
		for f in _fireflies:
			if is_instance_valid(f) and f.light_budget_enabled:
				f.light_budget_enabled = false
		return

	var p_pos := player.global_position
	var candidates: Array[Dictionary] = []

	for f in _fireflies:
		if not is_instance_valid(f) or not f.visible:
			continue
		var dist_sq := f.global_position.distance_squared_to(p_pos)
		# Seules les lucioles dans un rayon de 14m sont éligibles à l'éclairage actif
		if dist_sq < 196.0:
			candidates.append({"firefly": f, "dist_sq": dist_sq})

	# Trier de la plus proche à la plus éloignée
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist_sq"] < b["dist_sq"]
	)

	var active_count := mini(candidates.size(), max_active_firefly_lights)
	var active_set: Dictionary = {}

	for i in range(active_count):
		var chosen: Luciole = candidates[i]["firefly"]
		active_set[chosen] = true
		if not chosen.light_budget_enabled:
			chosen.light_budget_enabled = true

	# Désactiver les autres
	for f in _fireflies:
		if is_instance_valid(f) and not active_set.has(f) and f.light_budget_enabled:
			f.light_budget_enabled = false
