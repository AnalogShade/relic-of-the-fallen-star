extends SceneTree
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func press(controls: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	controls._unhandled_key_input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(30): await physics_frame
	var player = world.get_node("Original/Player")
	var boss = world.get_node("LakeMonster")
	player.set_physics_process(false)
	boss.set_physics_process(false)
	var bag := root.get_node("Inventory")
	var controls = load("res://tests/lake_monster_preview_controls.gd").new()
	controls.player = player
	controls.boss = boss
	controls.hint = Label.new()
	world.add_child(controls.hint)
	world.add_child(controls)
	check(not bag.has_fireball_relic() and not player.start_fireball(), "Départ sans pouvoir : lancer refusé")
	press(controls, KEY_F9)
	check(bag.has_fireball_relic() and player.start_fireball(), "F9 active le vrai pouvoir de feu du personnage")
	press(controls, KEY_F9)
	check(not bag.has_fireball_relic() and not player.is_casting_spell and not player.start_fireball(), "F9 désactive le feu et annule le lancer en préparation")
	press(controls, KEY_F9)
	check(bag.has_fireball_relic(), "Pouvoir réactivable sans quitter le test")
	player.global_position = Vector3(31, 8, -213)
	boss._begin_emerge()
	boss._play("Idle", 0)
	boss._sync_mouth()
	boss.state = "idle"
	var body_shot = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
	world.add_child(body_shot)
	body_shot.global_position = boss.global_position
	body_shot._handle_hit(boss.carapace)
	check(boss.health == 320, "Boule de feu sur le corps : zéro dégât")
	for i in range(4):
		var shot = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
		world.add_child(shot)
		shot.global_position = boss.mouth_area.global_position
		shot._handle_hit(boss.mouth_area)
		check(boss.health == 320 - (i + 1) * 80, "Impact dans la gueule " + str(i + 1) + " : 80 dégâts")
		if i == 2: check(boss.state == "idle", "Monstre encore vivant après trois impacts")
	check(boss.state == "sinking" and bag.collected.has("story/lake_monster_defeated"), "Quatrième impact : victoire")
	press(controls, KEY_F8)
	check(boss.state == "dormant" and boss.health == 320 and player.health == 100 and not bag.collected.has("story/lake_monster_defeated"), "F8 réarme le combat avec tous les PV")
	check(bag.has_fireball_relic(), "F8 conserve le choix avec ou sans feu")
	press(controls, KEY_F9)
	press(controls, KEY_F8)
	check(not bag.has_fireball_relic(), "F8 permet aussi de recommencer sans feu")
	print("LAKE_PREVIEW_CONTROLS_RESULT: ", "PASS" if failures == 0 else "FAIL")
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
