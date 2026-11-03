extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures.append(text)

func run_test() -> void:
	print("=== DEBUT DES TESTS DES INSECTES ===")

	# 1. Test unitaire de la Luciole
	var luciole_script = load("res://scripts/luciole.gd")
	check(luciole_script != null, "Script luciole.gd charge")
	
	var luciole_scene = load("res://scenes/insects/luciole.tscn")
	check(luciole_scene != null, "Scene luciole.tscn chargee")
	
	var luciole: Luciole = luciole_scene.instantiate() as Luciole
	root.add_child(luciole)
	
	check(luciole.variant == "solaire", "Luciole variante par defaut solaire")
	check(luciole._light != null, "Luciole OmniLight3D initialisee")
	check(luciole._anim_player != null, "Luciole AnimationPlayer present")
	if luciole._anim_player != null:
		check(luciole._anim_player.is_playing() or not luciole.visible, "Luciole animation configuree")

	# Test du changement de variante vers celeste
	luciole.variant = "celeste"
	check(luciole.variant == "celeste", "Luciole bascule en variante celeste")
	check(luciole._light.light_color == Luciole.COLOR_CELESTE, "Luciole couleur de lumiere celeste valide")

	# Test des poids jour / nuit sur la luciole
	luciole.night_weight = 0.0
	check(not luciole.visible, "Luciole invisible en plein jour (night_weight = 0)")
	check(not luciole._light.visible, "Lumiere luciole eteinte en plein jour")

	luciole.night_weight = 1.0
	check(luciole.visible, "Luciole visible en pleine nuit (night_weight = 1)")
	luciole.light_budget_enabled = true
	check(luciole._light.visible, "Lumiere luciole allumee avec budget autorise")
	luciole.light_budget_enabled = false
	check(not luciole._light.visible, "Lumiere luciole eteinte sans budget")

	# 2. Test unitaire du Papillon
	var papillon_scene = load("res://scenes/insects/papillon.tscn")
	check(papillon_scene != null, "Scene papillon.tscn chargee")

	var papillon: Papillon = papillon_scene.instantiate() as Papillon
	root.add_child(papillon)

	check(papillon.species == "morpho", "Papillon espece par defaut morpho")
	check(papillon._anim_player != null, "Papillon AnimationPlayer present")

	# Test des espèces
	for sp in ["monarque", "emeraude", "morpho"]:
		papillon.species = sp
		check(papillon.species == sp, "Papillon espece %s configuree" % sp)

	# Test jour / nuit sur le papillon
	papillon.day_weight = 1.0
	check(papillon.visible, "Papillon visible en plein jour (day_weight = 1)")

	papillon.day_weight = 0.0
	check(not papillon.visible, "Papillon masque en pleine nuit (day_weight = 0)")

	# 3. Test d'intégration avec l'OpenWorld
	print("--- Chargement de la scene open_world.tscn ---")
	var world_packed = load("res://scenes/world/open_world.tscn")
	check(world_packed != null, "open_world.tscn charge")

	var world: Node3D = world_packed.instantiate() as Node3D
	root.add_child(world)
	current_scene = world

	# Attendre quelques frames pour la résolution deferred (_configure_world et _setup_ecosystem)
	for f in range(25):
		await physics_frame

	var insect_mgr: InsectManager = world.get_node_or_null("InsectManager") as InsectManager
	check(insect_mgr != null, "InsectManager instancie dans OpenWorld")

	if insect_mgr != null:
		check(insect_mgr._fireflies.size() >= 32, "Au moins 32 lucioles instanciees (%d trouvees)" % insect_mgr._fireflies.size())
		check(insect_mgr._butterflies.size() >= 10, "Au moins 10 papillons instancies (%d trouves)" % insect_mgr._butterflies.size())

		var cycle: DayNightCycle = insect_mgr.day_night_cycle
		check(cycle != null, "DayNightCycle detecte et lie")

		if cycle != null:
			# Test Midi (12.0)
			cycle.time_of_day = 12.0
			for f in range(5):
				await physics_frame

			var active_fireflies := 0
			var active_butterflies := 0
			var active_lights := 0

			for fly in insect_mgr._fireflies:
				if fly.visible:
					active_fireflies += 1
				if fly._light != null and fly._light.visible:
					active_lights += 1

			for b in insect_mgr._butterflies:
				if b.visible:
					active_butterflies += 1

			check(active_fireflies == 0, "Midi : 0 luciole visible (%d)" % active_fireflies)
			check(active_lights == 0, "Midi : 0 lumiere de luciole active (%d)" % active_lights)
			check(active_butterflies > 0, "Midi : Papillons actifs (%d)" % active_butterflies)

			# Test Minuit (0.0)
			cycle.time_of_day = 0.0
			for f in range(15):
				await physics_frame

			active_fireflies = 0
			active_butterflies = 0
			active_lights = 0

			for fly in insect_mgr._fireflies:
				if fly.visible:
					active_fireflies += 1
				if fly._light != null and fly._light.visible:
					active_lights += 1

			for b in insect_mgr._butterflies:
				if b.visible:
					active_butterflies += 1

			check(active_fireflies > 20, "Minuit : Lucioles actives et lumineuses (%d)" % active_fireflies)
			check(active_butterflies == 0, "Minuit : 0 papillon visible (%d)" % active_butterflies)
			check(active_lights <= insect_mgr.max_active_firefly_lights, "Minuit : Budget lumiere respecte (%d <= %d)" % [active_lights, insect_mgr.max_active_firefly_lights])

	# Nettoyage
	luciole.queue_free()
	papillon.queue_free()
	world.queue_free()

	print("=== RESULTAT DU TEST DES INSECTES ===")
	print("Echecs : %d" % failures.size())
	for err in failures:
		print("  - " + err)

	quit(0 if failures.is_empty() else 1)
