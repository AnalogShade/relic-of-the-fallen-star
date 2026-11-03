extends SceneTree
func _initialize():
	var w=WorldEnvironment.new();var env=Environment.new();env.ssao_enabled=true;w.environment=env;root.add_child(w)
	print("RENDERER ",RenderingServer.get_current_rendering_method())
	await process_frame
	await process_frame
	quit()
