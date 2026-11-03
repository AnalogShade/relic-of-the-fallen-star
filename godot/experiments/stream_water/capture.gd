extends SceneTree
func _initialize():
 call_deferred("capture")
func capture():
 var scene = load("res://assets/environment/forest.glb").instantiate()
 root.add_child(scene)
 var water = scene.find_child("Water", true, false)
 var old = ShaderMaterial.new()
 old.shader = load("res://shaders/water.gdshader")
 water.material_override = old
 var env_node = WorldEnvironment.new()
 var env = Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky = Sky.new()
 sky.sky_material = ProceduralSkyMaterial.new()
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(0.76,0.8,0.76)
 env.ambient_light_energy = 0.45
 env_node.environment = env
 root.add_child(env_node)
 var sun = DirectionalLight3D.new()
 root.add_child(sun)
 sun.rotation_degrees = Vector3(-50,-30,0)
 sun.light_energy = 0.65
 sun.shadow_enabled = true
 var camera = Camera3D.new()
 root.add_child(camera)
 camera.position = Vector3(6,5,17)
 camera.look_at(Vector3(0,0.05,9))
 camera.current = true
 root.size = Vector2i(1280,720)
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://experiments/stream_water/before.png")
 load("res://scripts/stream_water.gd").apply(water)
 scene.find_child("Ripples", true, false).hide()
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://experiments/stream_water/after.png")
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://experiments/stream_water/after_motion.png")
 print("STREAM_PREVIEW_COMPLETE")
 quit()
