extends SceneTree

var failures := 0
var checks := 0
var progression: Node
var save_manager: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func run() -> void:
	progression = root.get_node("Progression")
	save_manager = root.get_node("SaveManager")
	check(progression.level == 1 and progression.maximum_health() == 100.0, "Base stats preserve existing balance")
	progression.add_experience(99)
	check(progression.level == 1 and progression.experience == 99, "Partial XP stays below threshold")
	progression.add_experience(1)
	check(progression.level == 2 and progression.points == 2 and progression.experience == 0, "Exact threshold grants two points")
	progression.add_experience(360)
	check(progression.level == 4 and progression.points == 6 and progression.experience == 10, "Multiple levels retain overflow XP")
	check(not progression.spend_point("invalid"), "Unknown attribute cannot spend points")
	for key in ["strength", "vitality", "speed", "magic", "vitality", "vitality"]:
		check(progression.spend_point(key), "Spend earned point: " + key)
	check(not progression.spend_point("strength"), "Cannot overspend points")
	check(is_equal_approx(progression.physical_multiplier(), 1.05) and is_equal_approx(progression.magic_multiplier(), 1.05), "Physical and magical bonuses stay independent")
	check(progression.maximum_health() == 130.0 and progression.movement_multiplier() > 1.0, "Vitality and speed affect their own stats")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	world.scene_file_path = "res://tests/progression_room.tscn"
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	await process_frame
	await process_frame
	player.restore_health(125.0)
	check(player.health == 125.0 and player.health_label.text == "Vie : 125 / 130", "Player restores HP above the old ceiling")
	player.heal(100.0)
	check(player.health == 130.0, "Healing respects vitality maximum")
	root.get_node("Inventory").ui.refresh()
	check(root.get_node("Inventory").ui.health_display.text == "SANTÉ : 130 / 130 PV", "Inventory displays vitality maximum")
	var target = load("res://scenes/bandit.tscn").instantiate()
	target.position = player.position + Vector3(0, 0, 1.25)
	world.add_child(target)
	target.set_physics_process(false)
	target.combat.set_process(false)
	player.get_node("Nael").rotation.y = 0
	await physics_frame
	player.apply_claw_hit()
	check(is_equal_approx(target.health, 73.75), "Claw hit applies strength bonus to real enemy")
	player.active_axe_strike = true
	player.apply_claw_hit()
	check(is_equal_approx(target.health, 37.0), "Melee axe applies strength bonus")
	player.active_axe_strike = false
	target.free()
	player.health = 101.0
	var inventory = root.get_node("Inventory")
	inventory.add_item("blueberry", 2)
	check(inventory.consume_item("blueberry") and player.health > 101.0, "Food works above 100 HP")
	player.respawn()
	check(player.health == 130.0, "Respawn restores increased maximum")
	player.fireball_target = Vector3(0, 1, -10)
	player.fireball_target_locked = true
	player.spawn_fireball()
	var projectile = world.get_child(world.get_child_count() - 1)
	check(is_equal_approx(projectile.damage, 42.0), "Launched fireball uses magic damage bonus")
	projectile.queue_free()
	var path: String = save_manager.save_game("Progression automated test", "user://progression_test.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var normalized: Dictionary = save_manager.normalize_save_data(data)
	check(normalized.player.health == 130.0 and normalized.progression.attributes.vitality == 3, "JSON save preserves bonus health and attributes")
	var saved: Dictionary = progression.save_to_dict()
	progression.load_from_dict({})
	check(progression.level == 1 and progression.points == 0, "Legacy save resets progression instead of inheriting current stats")
	progression.load_from_dict(saved)
	check(progression.level == 4 and progression.attributes.vitality == 3, "Progression round trip restores allocated points")
	check(save_manager.normalize_save_data({"player": {"health": 120}}).player.health == 100.0, "Legacy save uses original HP ceiling")
	check(save_manager.normalize_save_data({"progression": {"points": 5}}).is_empty(), "Invalid point budget rejected")
	check(save_manager.normalize_save_data({"progression": {"level": -1}}).is_empty(), "Invalid level rejected")
	check(save_manager.normalize_save_data({"progression": {"experience": 100}}).is_empty(), "Unnormalized XP rejected")
	for archetype in ["bandit", "araignee", "golem"]:
		var enemy = load("res://scenes/%s.tscn" % archetype).instantiate()
		world.add_child(enemy)
		enemy.set_physics_process(false)
		var before: int = progression.experience
		var expected: int = {"bandit": 40, "araignee": 30, "golem": 60}[archetype]
		enemy.take_damage(100000.0, Vector3.ZERO)
		check(progression.experience == before + expected, archetype + " death grants XP")
		enemy.take_damage(100000.0, Vector3.ZERO)
		progression.reward_enemy(enemy, expected)
		check(progression.experience == before + expected, archetype + " corpse cannot grant XP twice")
	var bag = root.get_node("Inventory")
	var ui = bag.ui
	bag.set_open(true)
	ui.show_character()
	check(ui.character_view.visible and not ui.inventory_view.visible, "Inventory opens character page")
	ui.character_view.get_node("AttributesButton").pressed.emit()
	check(bag.is_open and ui.progression_view.visible and not ui.character_view.visible, "Character button opens attributes inside inventory")
	progression.add_experience(250)
	var previous_vitality: int = progression.attributes.vitality
	ui.progression_view.buttons.vitality.pressed.emit()
	check(progression.attributes.vitality == previous_vitality + 1 and progression.points == 1, "Attribute button spends exactly one point from inventory")
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/progression_inventory_20261025/attributes.png")
	ui.progression_view.back_requested.emit()
	check(ui.character_view.visible and not ui.progression_view.visible, "Attributes return to character page")
	ui.show_inventory()
	check(ui.inventory_view.visible and not ui.character_view.visible, "Character returns to inventory")
	ui.show_attributes()
	bag.set_open(false)
	check(not ui.panel.visible and not ui.progression_view.visible, "Closing inventory closes attribute screen")
	bag.set_open(true)
	check(ui.inventory_view.visible and not ui.progression_view.visible, "Reopening inventory starts with bag contents")
	bag.set_open(false)
	var pause = root.get_node("PauseMenu")
	pause.open()
	check(paused and pause.main_view.visible, "Pause menu still opens independently")
	pause.resume()
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/progression_inventory_20261025/hud.png")
	check(await save_manager.load_game_from_file(path), "Real save file loads into a fresh scene")
	var restored = get_first_node_in_group("player")
	check(progression.level == 4 and progression.attributes.vitality == 3 and progression.points == 0, "Loading replaces current progression with saved progression")
	check(restored.health == 130.0 and restored.max_health == 130.0, "Fresh player receives saved vitality before HP restoration")
	DirAccess.remove_absolute(path)
	print("PROGRESSION_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
