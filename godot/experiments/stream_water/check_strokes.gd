extends SceneTree
func _initialize():
 call_deferred("check")
func check():
 var scene = load("res://scenes/world/open_world.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 await process_frame
 var strokes = scene.get_node("Original/EnvironmentArt/Ripples")
 assert(not strokes.visible)
 assert(scene.get_node("Original/EnvironmentArt/Water").visible)
 assert(scene.get_node("Original/EnvironmentArt/Water").material_override.shader.resource_path == "res://shaders/stream_water.gdshader")
 print("WHITE_STROKES_HIDDEN_PASS")
 scene.free()
 quit()
