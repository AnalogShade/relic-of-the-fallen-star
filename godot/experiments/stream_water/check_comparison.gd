extends SceneTree
func _initialize():
 call_deferred("check")
func check():
 var scene = load("res://experiments/stream_water/preview.tscn").instantiate()
 root.add_child(scene)
 var next = scene.water.material_override
 var key = InputEventKey.new()
 key.keycode = KEY_B
 key.pressed = true
 scene._unhandled_key_input(key)
 assert(scene.water.material_override.shader.resource_path == "res://shaders/water.gdshader")
 scene._unhandled_key_input(key)
 assert(scene.water.material_override == next)
 print("COMPARISON_TOGGLE_PASS")
 scene.free()
 quit()
