@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("render_captures")

func render_captures() -> void:
	print("--- RENDERING HARVEST & INVENTORY PREVIEWS ---")
	var scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	
	var inventory = root.get_node_or_null("/root/Inventory")
	var player: CharacterBody3D = world.find_child("Player", true, false) as CharacterBody3D
	
	# Disable player camera so preview camera takes over
	for c in world.find_children("*", "Camera3D", true, false):
		c.current = false
		
	# Find a Bleuetier
	var bushes_node = world.get_node_or_null("ArbustesABaies")
	var bleuetier = bushes_node.get_node_or_null("Bleuetier_01")
	
	# Place player close to the Bleuetier
	player.global_position = bleuetier.global_position + Vector3(1.2, 0.0, 1.2)
	player.rotation.y = PI * 0.75
	
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = player.global_position + Vector3(1.8, 1.8, 2.2)
	cam.look_at(bleuetier.global_position + Vector3.UP * 1.2, Vector3.UP)
	cam.fov = 60.0
	cam.make_current()
	
	# Manually set prompt as if player is looking at bush
	inventory.ui.set_prompt("F  ·  Cueillir les bleuets")
	
	for i in range(10):
		await process_frame
		
	var out_dir := "C:/Users/Utilisateur/.gemini/antigravity/brain/2d201e42-43fe-4c46-bebd-597af6456fca"
	var img = root.get_texture().get_image()
	img.save_png(out_dir + "/godot_harvest_prompt_preview.png")
	print("Saved harvest prompt preview")
	
	# Now populate bag with variety of consumables, hurt player slightly, open inventory
	inventory.add_item("blueberry", 8)
	inventory.add_item("raspberry", 6)
	inventory.add_item("golden_berry", 5)
	inventory.add_item("mushroom", 6)
	inventory.add_item("trout", 2)
	player.take_damage(25.0, Vector3.ZERO) # 75 PV
	
	inventory.set_open(true)
	inventory.ui.refresh()
	
	for i in range(5):
		await process_frame
		
	img = root.get_texture().get_image()
	img.save_png(out_dir + "/godot_inventory_consumables_preview.png")
	print("Saved inventory consumables preview")
	
	cam.queue_free()
	world.queue_free()
	quit(0)
