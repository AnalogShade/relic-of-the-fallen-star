extends SceneTree
## Run with --script res://tests/lake_monster_preview.gd for a nearby playable entry.
func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(30):
		await physics_frame
	var player = world.get_node("Original/Player")
	player.global_position = Vector3(38, 8, -213)
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = PI / 2
	player.arm.rotation.x = 0.05
	player.arm.spring_length = 10.0
	player.spawn_position = player.global_position
	var layer := CanvasLayer.new()
	layer.layer = 5
	var hint := Label.new()
	hint.position = Vector2(24, 95)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hint)
	world.add_child(layer)
	var controls = load("res://tests/lake_monster_preview_controls.gd").new()
	controls.player = player
	controls.boss = world.get_node("LakeMonster")
	controls.hint = hint
	world.add_child(controls)
	print("LAKE_PREVIEW_READY: F8 recommencer; F9 activer/désactiver le feu; gueule 4 impacts")
	if "--capture-preview" in OS.get_cmdline_user_args():
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/lake_monster_playable_start.png")
