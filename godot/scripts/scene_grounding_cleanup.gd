@tool
extends RefCounted
## Offline-audited corrections, shared by the editor and the game.
## Source GLBs remain intact; corrected geometry and collisions are baked together.
const MANIFEST := "res://assets/environment/scene_cleanup/cleanup.json"

static func apply(world: Node3D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var rocks := world.get_node_or_null("RochesBlender")
	if rocks != null and not rocks.has_meta("grounding_cleanup_applied"):
		var batches := {}
		for item in data.rocks:
			var batch := world.get_node_or_null(NodePath(item.path)) as MultiMeshInstance3D
			var collider := world.get_node_or_null(NodePath(item.collision)) as CollisionShape3D
			if batch == null or collider == null:
				push_error("Grounding cleanup target missing: " + str(item.path))
				continue
			if not batches.has(item.path):
				batch.multimesh = batch.multimesh.duplicate()
				batches[item.path] = batch
			var index := int(item.index)
			var transform := batch.multimesh.get_instance_transform(index)
			transform.origin.y += float(item.dy)
			batch.multimesh.set_instance_transform(index, transform)
			collider.position.y += float(item.dy)
		rocks.set_meta("grounding_cleanup_applied", true)
	# Absolute resource assignments also survive editor reconfiguration.
	for item in data.nodes:
		var node := world.get_node_or_null(NodePath(item.path)) as Node3D
		if node != null:
			node.position.y = float(item.y)
	for item in data.meshes:
		var node := world.get_node_or_null(NodePath(item.path)) as MeshInstance3D
		if node == null:
			push_error("Grounding cleanup mesh missing: " + str(item.path))
			continue
		node.mesh = load(str(item.mesh)) as Mesh
		if not str(item.collision).is_empty():
			var shape := load(str(item.collision)) as Shape3D
			for collision: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
				collision.shape = shape
	for path in data.hidden:
		var node := world.get_node_or_null(NodePath(path)) as Node3D
		if node == null:
			push_error("Grounding cleanup tree missing: " + str(path))
			continue
		node.hide()
		for body: CollisionObject3D in node.find_children("*", "CollisionObject3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
