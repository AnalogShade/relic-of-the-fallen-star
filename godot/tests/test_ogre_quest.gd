extends SceneTree
const Access = preload("res://scripts/cave_access.gd")
var failures: Array[String] = []
var checks := 0
var world: Node3D
var player: CharacterBody3D
var bag: Node
var dm: Node
var guardian: Node3D
var cave: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", message)
	if not condition: failures.append(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func near(target: Node3D, radius := 1.2) -> bool:
	player.set_physics_process(false)
	for i in 12:
		var angle := i * TAU / 12.0
		player.global_position = target.global_position + Vector3(cos(angle)*radius, 0.5, sin(angle)*radius)
		player.velocity = Vector3.ZERO
		await frames(2)
		if bag.target == target: return true
	return false

func shot(name_text: String, eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	camera.global_position = eye
	camera.look_at(target)
	camera.make_current()
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../diagnostics/ogre_quest_20261021/" + name_text + ".png")

func throw_dart_at(point: Vector3) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cam := player.arm.get_node("Camera3D") as Camera3D
	cam.global_position = player.global_position + (player.global_position - point).normalized() * 5.0 + Vector3.UP * 3.0
	cam.look_at(point)
	cam.make_current()
	# Keep the normal camera rig, move the same free cursor used by the player.
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_RIGHT
	press_event.pressed = true
	player._unhandled_input(press_event)
	check(player.fireball_aiming and player.ranged_item == "sleep_dart", "Right press begins dart aiming before owning the relic")
	var motion := InputEventMouseMotion.new()
	motion.relative = cam.unproject_position(point) - player.fireball_cursor
	player._unhandled_input(motion)
	press_event.pressed = false
	player._unhandled_input(press_event)
	player.set_physics_process(true)
	await frames(45)
	player.set_physics_process(false)

func finish() -> void:
	var report := {"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var file := FileAccess.open("res://../diagnostics/ogre_quest_20261021/tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("OGRE QUEST RESULTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	bag = root.get_node("Inventory")
	dm = root.get_node("DialogueManager")
	bag.stacks.clear()
	bag.equipment.clear()
	bag.collected.clear()
	world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	player = get_first_node_in_group("player")
	cave = world.get_node("GrotteEntree")
	guardian = cave.get_node_or_null("OgreGuardian")
	check(guardian != null, "Guardian assembled in the actual main world")
	if not guardian:
		finish()
		return
	camera = Camera3D.new()
	world.add_child(camera)
	# Isolate the encounter from unrelated patrols during this deterministic suite.
	for enemy in get_nodes_in_group("enemies"):
		if enemy != guardian: enemy.set_physics_process(false)
	print("OGRE POSITION ", guardian.global_position, " CLIPS ", guardian.animator.get_animation_list())
	for clip in ["Idle_Respiration","Walk_Relaxed","Guardian_Kick","Guardian_Drowsy","Guardian_Sit_Sleep","Guardian_Sleep"]:
		check(guardian.animator.has_animation(clip), "Blender clip imported: " + clip)
	var plants := get_nodes_in_group("dream_fern")
	check(plants.size() >= 10, "Existing stream ferns have individual harvest anchors")
	var fern: Node3D = plants[0]
	var source: MeshInstance3D = world.get_node("Original/EnvironmentArt/OriginalGeometry/Undergrowth")
	var source_mesh := source.mesh
	check(await near(fern, 0.65), "Fern selected by the normal nearest-interaction system")
	check(not Access.has_fact(world, Access.MET), "Plants collectible before meeting the guardian or Maëlor")
	await shot("stream_ferns", fern.global_position+Vector3(3,2,4), fern.global_position+Vector3.UP*.25)
	await press("interact")
	check(bag.get_item_count(Access.FERN) == 2, "F key picks two fern fronds into inventory")
	check(source.visible and source.mesh == source_mesh and fern.visible, "Harvest leaves the original plant and mesh visible and intact")
	check(not fern.can_interact(), "Harvest cooldown prevents immediate repeated picking")
	await press("inventory")
	await shot("fern_inventory", fern.global_position+Vector3(3,2,4), fern.global_position)
	await press("inventory")
	check(not bag.can_craft(Access.DART), "Recipe unavailable until examined at the cauldron")

	var cauldron: Node3D = get_first_node_in_group("cauldron")
	check(await near(cauldron, 1.6), "Cauldron selected through existing F interaction")
	await press("interact")
	check(dm.is_open and Access.has_fact(world, Access.RECIPE), "Examining the cauldron discovers the local recipe before meeting ogre")
	check(not Access.has_fact(world, Access.MET), "Recipe discovery independent of guardian encounter")
	await key(KEY_SPACE)
	check(bag.is_open and bag.cooking_ui.visible, "Existing crafting menu opens after the found note")
	check(not bag.can_craft(Access.DART), "Missing mushroom prevents crafting")
	bag.add_item("mushroom", 1)
	await shot("cauldron_recipes", cauldron.global_position+Vector3(4,3,4),cauldron.global_position)
	# Click the actual recipe button signal, exercising the menu's bound recipe ID.
	var craft_button: Button
	for child in bag.cooking_ui.recipes.get_children():
		if child is Button and child.text == "Fabriquer": craft_button = child
	check(craft_button != null and not craft_button.disabled, "Craft button enabled when all ingredients are present")
	if craft_button: craft_button.pressed.emit()
	check(bag.get_item_count(Access.DART) == 10 and bag.get_item_count(Access.FERN) == 0 and bag.get_item_count("mushroom") == 0, "Crafting consumes ingredients once and adds ten darts")
	bag.set_open(false)

	player.global_position = guardian.global_position + cave.global_basis.z * 2.4 + Vector3.UP*.4
	await frames(3)
	check(bag.target == guardian and guardian.can_interact(), "Ogre reachable through ordinary F interaction")
	await press("interact")
	check(dm.is_open and dm.current_choices.size() == 3, "Guardian dialogue offers both responses and the owned dart")
	await shot("ogre_choices", cave.to_global(Vector3(6,4,8)),guardian.global_position+Vector3.UP*1.4)
	await key(KEY_1)
	check(not dm.is_open and guardian.state == "guard" and player.health == 100, "Choosing to leave causes no hostility or damage")
	await press("interact")
	await key(KEY_2)
	check(dm.is_open and "Je t'aurai prévenu" in dm.current_pages[0], "Insisting displays the exact warning")
	await key(KEY_SPACE)
	check(guardian.state == "kick", "Warning completion starts the Blender kick")
	var home: Vector3 = guardian.global_position
	var start: Vector3 = player.global_position
	player.set_physics_process(true)
	await frames(44)
	await shot("ogre_kick",cave.to_global(Vector3(6,4,8)),guardian.global_position+Vector3.UP)
	await frames(110)
	player.set_physics_process(false)
	check(player.health == 75, "Kick applies 25 damage at the impact frame")
	check(player.global_position.distance_to(start) > 3, "Collision-aware kick projects Naël away from the entrance")
	check(guardian.state == "guard" and guardian.global_position == home, "Ogre resumes guarding and never pursues")
	check(Access.has_fact(world, Access.REPELLED), "Being repelled is remembered")
	check(root.get_node("QuestManager").is_quest_active("cave_way_in"), "Kick starts the forest exploration mini-quest")
	# Low-health boundary: the same real animation cannot kill Naël.
	await frames(65)
	player.global_position = home + cave.global_basis.z*2.4 + Vector3.UP*.4
	player.health = 5
	guardian.start_kick()
	await frames(45)
	check(player.health == 1, "Kick remains nonlethal at five HP")
	await frames(90)
	player.guardian_knockback = 0
	player.health = 100
	player.velocity = Vector3.ZERO

	var sage: Node3D = world.get_node("MaelorHerboriste")
	player.global_position = sage.global_position + Vector3(2,0.5,0)
	await frames(35) # Let the existing NPC distance/LOD timer react to the teleport.
	check(await near(sage, 2.0), "Maëlor reachable after being repelled")
	await press("interact")
	check(dm.is_open and "D'anciennes leçons" == dm.current_title, "Maëlor's optional hint takes precedence over the ordinary quest dialogue")
	var hint_text := " ".join(dm.current_pages)
	check("particulièrement au sujet des plantes" in hint_text and not "chaudron" in hint_text and not "Fougère" in hint_text and not "fléchette" in hint_text, "Hint mentions plants without revealing ingredients, cauldron or solution")
	dm.hide_dialogue()
	check(Access.has_fact(world, Access.HINT), "Optional hint fact persisted")
	# Remove the hint to prove completion does not depend on it.
	bag.collected.erase(Access.HINT)
	var portal: Node3D = cave.get_node("Portal")
	player.global_position = portal.to_global(Vector3(0,-.6,1))
	check(not portal.can_interact(), "Cave portal refuses access while guardian is awake even if bypassing his body")
	check(guardian.barrier.collision_layer == 1, "Physical passage collision enabled while guarding")
	player.global_position = home + cave.global_basis.z*3.2 + Vector3.UP*.4
	await frames(3)
	bag.set_open(true)
	check(bag.use_item(Access.DART) and bag.equipped == Access.DART, "Inventory click equips darts without launching")
	check(bag.get_item_count(Access.DART) == 10 and guardian.state == "guard", "Equipping consumes nothing and leaves the guardian awake")
	bag.set_open(false)
	player.pivot.rotation.y = cave.global_rotation.y
	player.arm.rotation.x = -0.15
	await frames(3)
	await throw_dart_at(guardian.global_position + Vector3.UP * 1.8)
	check(bag.get_item_count(Access.DART) == 9, "Launching consumes exactly one dart")
	check(guardian.state == "drowsy" and Access.has_fact(world, Access.SEDATED), "Dart impact triggers drowsiness and records a recoverable state")
	var save_mgr := root.get_node("SaveManager")
	var save_path: String = save_mgr.save_game("Ogre quest automated test", "user://saves/ogre_quest_test.json")
	check(not save_path.is_empty(), "Can save during the somnolence transition")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.story_flags.get(Access.SEDATED, false) and saved.story_flags.get(Access.RECIPE, false), "Existing save format retains guardian and recipe facts")
	await frames(505)
	check(guardian.state == "sleeping" and guardian.health == 1000, "Ogre progressively becomes sleepy, sits and sleeps while alive")
	check(guardian.barrier.collision_layer == 0 and guardian.body_shape.disabled, "Sleep releases physical passage")
	check(root.get_node("QuestManager").is_quest_completed("cave_way_in"), "Sleeping guardian completes the mini-quest")
	player.global_position = portal.to_global(Vector3(0,-.6,1))
	player.velocity = Vector3.ZERO
	check(portal.can_interact(), "Cave entrance usable after sleep")
	check(not Access.has_fact(world, Access.HINT), "Solution completed without requiring Maëlor's hint")
	await shot("ogre_asleep", cave.to_global(Vector3(6,4,8)),guardian.global_position+Vector3.UP)
	portal.interact()
	await frames(90)
	check(root.get_node("CabinTravel").inside and current_scene.scene_file_path == "res://scenes/interiors/cave_room.tscn", "Portal actually transitions into the cave interior")
	root.get_node("CabinTravel").leave_cabin()
	await frames(90)
	check(current_scene == world and guardian.state == "sleeping", "Returning from cave preserves the sleeping guardian")
	check(await save_mgr.load_game_from_file(save_path), "Actual disk save reload succeeds")
	world = current_scene
	guardian = world.get_node("GrotteEntree/OgreGuardian")
	check(guardian.state == "sleeping" and guardian.barrier.collision_layer == 0, "Reload during sedation restores open passage and sleeping animation")
	check(bag.get_item_count(Access.DART) == 9, "Reload does not refund a used dart")
	# Old progress remains valid even with no guardian-specific facts.
	bag.collected.erase(Access.SEDATED)
	bag.add_item("first_echo")
	check(Access.passage_open(world), "Legacy saves with the relic keep cave access")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	finish()
