extends SceneTree

func _init() -> void:
	print("--- INSPECTING FIREBALL.GLB ---")
	var scene: PackedScene = load("res://assets/spells/fireball.glb")
	if not scene:
		print("FAILED to load fireball.glb")
		quit(1)
		return
	var inst: Node = scene.instantiate()
	_print_tree(inst, 0)
	var anim_player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		print("AnimationPlayer found! Animations:", anim_player.get_animation_list())
	else:
		print("No AnimationPlayer found directly, searching any animations...")
	
	print("\n--- INSPECTING FIREBALL_SHARD.GLB ---")
	var shard_scene: PackedScene = load("res://assets/spells/fireball_shard.glb")
	if shard_scene:
		var shard_inst: Node = shard_scene.instantiate()
		_print_tree(shard_inst, 0)
	quit(0)

func _print_tree(node: Node, depth: int) -> void:
	var prefix := "  ".repeat(depth)
	print("%s- %s (%s)" % [prefix, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1)
