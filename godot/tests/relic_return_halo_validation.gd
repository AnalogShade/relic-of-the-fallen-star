extends Node3D
var failures := 0
func check(value: bool, label: String) -> void:
	print(('PASS ' if value else 'FAIL ') + label)
	if not value: failures += 1
func _ready() -> void:
	call_deferred('run')
func run() -> void:
	var bag = get_node('/root/Inventory')
	bag.collected.erase('cave/first_echo')
	bag.collected.erase('cave/echo_chest_open')
	var cave = load('res://scenes/interiors/cave_depths.tscn').instantiate()
	cave.enable_enemies = false
	get_tree().root.add_child(cave)
	get_tree().current_scene = cave
	var halo = cave.get_node('RelicReturnHalo')
	var actor = cave.get_node('Player')
	actor.position = halo.position + Vector3(0, .1, 0)
	await get_tree().physics_frame
	check(not halo.visible and not halo.can_interact(), 'halo locked before collection')
	bag.collected['cave/echo_chest_open'] = true
	await get_tree().process_frame
	check(not halo.activated, 'opening chest does not unlock return')
	bag.collected['cave/first_echo'] = true
	await get_tree().create_timer(1.4).timeout
	check(halo.visible and halo.can_interact(), 'collected relic reveals usable halo')
	var travel = get_node('/root/CabinTravel')
	check(not travel.busy and get_tree().current_scene == cave, 'standing in halo does not auto travel')
	actor.position.x += 2.2
	check(not halo.can_interact(), 'outside circle cannot activate')
	actor.position = halo.position + Vector3(0, .1, 0)
	bag.set_open(true)
	check(not halo.can_interact(), 'inventory blocks return')
	bag.set_open(false)
	var space = cave.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(halo.position + Vector3.UP, halo.position - Vector3.UP, 1))
	check(not hit.is_empty() and absf(hit.position.y + 7.0) < .1, 'halo sits on accessible floor')
	actor.pivot.rotation.y = 0.65
	actor.arm.rotation.x = -.65
	actor.arm.spring_length = 8.0
	if DisplayServer.get_name() != 'headless':
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png('res://tests/relic_return_halo.png')
	Input.action_press('interact')
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release('interact')
	await get_tree().create_timer(1.5).timeout
	check(travel.room != null and travel.room.name == 'CaveRoom', 'F returns to cave entrance')
	check(bag.collected.has('cave/first_echo'), 'return preserves relic completion')
	print('HALO FAILURES ', failures)
	get_tree().quit(0 if failures == 0 else 1)
