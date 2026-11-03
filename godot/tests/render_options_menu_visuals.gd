extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	
	var pause_menu = root.get_node("PauseMenu")
	
	# Ouvrir le menu pause
	pause_menu.open()
	await frames(5)
	
	# 1. Capture de la vue principale avec le bouton Options
	await RenderingServer.frame_post_draw
	var img_main: Image = root.get_texture().get_image()
	img_main.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/68e0b723-6106-43f5-bede-3d847d8338eb/menu_pause_avec_options.png")
	
	# 2. Capture de la vue Options
	pause_menu.show_options_view()
	await frames(5)
	await RenderingServer.frame_post_draw
	var img_options: Image = root.get_texture().get_image()
	img_options.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/68e0b723-6106-43f5-bede-3d847d8338eb/menu_options_audio.png")
	
	pause_menu.resume()
	print("Screenshots captured successfully.")
	quit(0)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
