@tool
extends SceneTree

func _init() -> void:
	print("=== ENQUETE SUR LES COLLIDERS DU JEU ===")
	var world_scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = world_scene.instantiate()
	root.add_child(world)

	for i in range(10):
		await process_frame

	var all_shapes: Array[Dictionary] = []
	var static_bodies := world.find_children("*", "StaticBody3D", true, false)
	print("Nombre total de StaticBody3D : %d" % static_bodies.size())

	for sb in static_bodies:
		for cs in sb.find_children("*", "CollisionShape3D", true, false):
			var shape := (cs as CollisionShape3D).shape
			if shape == null:
				continue
			var face_count := 0
			if shape is ConcavePolygonShape3D:
				face_count = (shape as ConcavePolygonShape3D).get_faces().size() / 3
			elif shape is ConvexPolygonShape3D:
				face_count = (shape as ConvexPolygonShape3D).points.size()
			
			all_shapes.append({
				"node_path": str(cs.get_path()),
				"shape_type": shape.get_class(),
				"faces": face_count,
				"disabled": (cs as CollisionShape3D).disabled
			})

	# Sort by face count descending
	all_shapes.sort_custom(func(a, b): return a["faces"] > b["faces"])

	print("\nTOP 25 DES PLUS GROS COLLIDERS (en nombre de faces/points) :")
	for i in range(mini(25, all_shapes.size())):
		var item: Dictionary = all_shapes[i]
		print("  [%s] %d faces/pts | disabled=%s | %s" % [item["shape_type"], item["faces"], item["disabled"], item["node_path"]])

	world.queue_free()
	print("\n=== FIN DE L'ENQUETE ===")
	quit(0)
