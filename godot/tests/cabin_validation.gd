extends Node3D
var failures: Array[String] = []
var finished := false
var checks := 0
var report: Dictionary = {}
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print(("PASS: " if ok else "FAIL: ") + message)
func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame
func press_f() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = true
	Input.parse_input_event(event)
	await frames(4)
	event = InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = false
	Input.parse_input_event(event)
func settle_travel(travel: Node) -> void:
	for i in range(100):
		await get_tree().create_timer(0.05).timeout
		if not travel.busy: break
	check(not travel.busy, "Transition completes within five seconds")
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
	await frames(60)
	var travel := get_node("/root/CabinTravel")
	var world := $World
	var id := world.get_instance_id()
	var player := $World/Original/Player
	world.reparent(get_tree().root)
	get_tree().current_scene = world
	await press_f()
	await frames(6)
	check(not travel.inside, "F away from cabin does not change level")
	var entrance_x: float = world.get_node("Sectors/Tile_04_bois_du_foyer/CabinEntrance").global_position.x
	player.global_position = Vector3(entrance_x, 12.04, 4.2)
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = 0
	await frames(50)
	var exterior_position: Vector3 = player.global_position
	var door_query := PhysicsRayQueryParameters3D.create(Vector3(entrance_x, 13.2, 3.5), Vector3(entrance_x, 13.2, 0.8), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(door_query)
	check(not hit.is_empty(), "Exterior closed door has collision")
	await capture("res://tests/cabin_entrance.png")
	await press_f()
	await settle_travel(travel)
	check(travel.inside and travel.room != null, "F enters the separate cabin room")
	check(not world.is_inside_tree(), "Forest instance is preserved off the active tree")
	if travel.room == null:
		finish_report()
		return
	var room: Node3D = travel.room
	check(get_tree().current_scene == room, "Cabin becomes the current scene")
	var actor: CharacterBody3D = room.get_node("Player")
	await frames(40)
	check(actor.is_on_floor(), "Interior arrival stands on the floor")
	check(actor.global_position.y > 0.35 and actor.global_position.y < 0.6, "Interior spawn is above the planks")
	var fire := room.get_node("HearthFire")
	var energy_a: float = fire.light.light_energy
	var scale_a: float = fire.tongues[0].scale.y
	await frames(23)
	check(absf(fire.light.light_energy - energy_a) > 0.001, "Fire light flickers over time")
	check(absf(fire.tongues[0].scale.y - scale_a) > 0.001, "Flame shapes animate over time")
	check(fire.tongues.size() == 5, "Five animated flame tongues are present")
	actor.pivot.rotation.y = 0
	var start_z := actor.global_position.z
	Input.action_press("move_forward")
	await frames(65)
	Input.action_release("move_forward")
	await frames(12)
	check(actor.global_position.z < start_z - 1.2, "Character walks from doorway into the room")
	check(actor.is_on_floor(), "Character remains grounded while walking inside")
	var wall_ray := PhysicsRayQueryParameters3D.create(Vector3(0.7, 1, 0), Vector3(0.7, 1, -4), 1)
	check(not get_world_3d().direct_space_state.intersect_ray(wall_ray).is_empty(), "Room walls prevent walking out")
	var chair_ray := PhysicsRayQueryParameters3D.create(Vector3(-0.2, 0.85, -0.625), Vector3(-2.8, 0.85, -0.625), 1)
	check(not get_world_3d().direct_space_state.intersect_ray(chair_ray).is_empty(), "Armchair has physical collision")
	await capture("res://tests/cabin_room_gameplay.png")
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.position = Vector3(2.65, 1.65, 2.30)
	cam.look_at(Vector3(-0.25, 1.2, -1.0))
	cam.fov = 82
	cam.current = true
	actor.hide()
	await frames(5)
	await capture("res://tests/cabin_room_detail.png")
	actor.show()
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
	cam.queue_free()
	actor.global_position = Vector3(-0.6875, 0.46, 2.1)
	actor.velocity = Vector3.ZERO
	await frames(30)
	await press_f()
	await settle_travel(travel)
	check(not travel.inside and world.is_inside_tree(), "F returns from the cabin to the forest")
	check(world.get_instance_id() == id, "Return restores the same forest instance")
	check(get_tree().current_scene == world, "Forest is restored as current scene")
	check(player.global_position.distance_to(exterior_position) < 0.15, "Return restores the position outside the entrance")
	check(player.process_mode != Node.PROCESS_MODE_DISABLED, "Player controls resume after return")
	await press_f()
	await settle_travel(travel)
	check(travel.inside, "Second entry works without duplicate nodes")
	await frames(20)
	await press_f()
	await settle_travel(travel)
	check(not travel.inside, "Second exit works without reloading the forest")
	check(travel.overlay.color.a < 0.01, "Fade overlay clears completely")
	finish_report()
func finish_report() -> void:
	report = {"checks": checks, "failures": failures, "fps": Engine.get_frames_per_second()}
	var file := FileAccess.open("res://tests/cabin_validation_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	finished = true
	print("CABIN_VALIDATION: " + JSON.stringify(report))
