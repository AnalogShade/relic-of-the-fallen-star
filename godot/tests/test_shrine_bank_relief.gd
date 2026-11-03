extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	if "--baseline" in OS.get_cmdline_user_args():
		var source: Node3D = load("res://assets/environment/trails_20261021/tile_07_meandres_du_sud.glb").instantiate()
		var original := source.find_child("Terrain", true, false) as MeshInstance3D
		var terrain := world.get_node("Sectors/Tile_07_meandres_du_sud/Art/Terrain") as MeshInstance3D
		terrain.mesh = original.mesh
		for shape: CollisionShape3D in terrain.find_children("*", "CollisionShape3D", true, false):
			shape.shape = original.mesh.create_trimesh_shape()
		source.free()
	root.add_child(world)
	current_scene = world
	await frames(30)
	var player = world.get_node("Original/Player")
	player.damage_invulnerability = 10000.0
	player.pivot.rotation.y = 0.0
	var water := world.get_node("Sectors/Tile_07_meandres_du_sud").find_child("Water", true, false) as MeshInstance3D
	var vertices := water.mesh.get_faces()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for z in [28.0, 30.0, 32.0, 34.0, 36.0, 38.0]:
		var edge := Vector3(-INF,0,z)
		var row_distance := INF
		for v in vertices:
			var p: Vector3 = water.global_transform * v
			row_distance = minf(row_distance, absf(p.z-z))
		for v in vertices:
			var p: Vector3 = water.global_transform * v
			if absf(p.z-z) < row_distance + 0.001 and p.x > edge.x: edge = p
		assert(is_finite(edge.x))
		var above_water := true
		var max_grade := 0.0
		var previous := Vector3.INF
		for i in range(42):
			var point := edge + Vector3(-1.0 + i * 0.15,0,0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP*8, point - Vector3.UP*3, 1))
			assert(not hit.is_empty())
			var ground: Vector3 = hit.position
			if point.x >= edge.x + 0.25 and ground.y <= edge.y: above_water = false
			if previous.is_finite(): max_grade = maxf(max_grade, absf(ground.y-previous.y)/0.15)
			previous = ground
		check(above_water, "Right grass bank above water at z=" + str(z))
		check(max_grade < 0.85, "Continuous walkable bank at z=%s grade=%.3f" % [z,max_grade])
		for direction in [1.0,-1.0]:
			player.global_position = edge + Vector3(-1.0 if direction > 0 else 3.6, 2.0, 0)
			player.velocity = Vector3.ZERO
			await frames(60)
			var action := "move_right" if direction > 0 else "move_left"
			Input.action_press(action)
			await frames(160)
			Input.action_release(action)
			var goal: float = edge.x + (3.0 if direction > 0 else -0.8)
			check(player.global_position.x > goal if direction > 0 else player.global_position.x < goal, "Walk %s bank without jumping z=%s end=%s" % ["out of" if direction > 0 else "into",z,player.global_position])
			var jump_y: float = player.global_position.y
			Input.action_press("jump")
			await frames(8)
			Input.action_release("jump")
			check(player.global_position.y > jump_y + 0.4, "Jump still works after crossing z=" + str(z))
	world.queue_free()
	await process_frame
	print("SHRINE_BANK_RESULT failures=", failures)
	quit(1 if failures else 0)


