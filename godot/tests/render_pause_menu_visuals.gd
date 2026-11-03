extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	
	var save_mgr = root.get_node("SaveManager")
	var inv = root.get_node("Inventory")
	var pause_menu = root.get_node("PauseMenu")
	
	# Create two realistic save entries for visual presentation
	inv.equipment.clear()
	inv.equipment.append("first_echo")
	inv.equipment.append("fishing_rod")
	inv.stacks.clear()
	inv.stacks.append({"id": "blueberry", "quantity": 24})
	inv.stacks.append({"id": "mushroom", "quantity": 6})
	save_mgr.save_game("Grotte terminée - Souffle igné débloqué")
	
	inv.equipment.clear()
	inv.equipment.append("fishing_rod")
	inv.stacks.clear()
	inv.stacks.append({"id": "trout", "quantity": 3})
	save_mgr.save_game("Cabane du pêcheur au crépuscule")
	
	# Open pause menu
	pause_menu.open()
	await frames(5)
	
	# 1. Capture Main View
	await RenderingServer.frame_post_draw
	var img_main: Image = root.get_texture().get_image()
	img_main.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/e89da791-3435-4d9e-8753-398dae534af6/menu_pause_main.png")
	
	# 2. Capture Save View
	pause_menu.show_save_view()
	await frames(5)
	await RenderingServer.frame_post_draw
	var img_save: Image = root.get_texture().get_image()
	img_save.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/e89da791-3435-4d9e-8753-398dae534af6/menu_pause_save.png")
	
	# 3. Capture Load View
	pause_menu.show_load_view()
	await frames(5)
	await RenderingServer.frame_post_draw
	var img_load: Image = root.get_texture().get_image()
	img_load.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/e89da791-3435-4d9e-8753-398dae534af6/menu_pause_load.png")
	
	# Clean up test saves
	for save in save_mgr.list_saves():
		save_mgr.delete_save(save.file_path)
		
	pause_menu.resume()
	print("Screenshots captured successfully.")
	quit(0)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
