extends SceneTree
const OUT="res://tests/ambient_occlusion_20261017/strong/"
func _initialize(): call_deferred("run")
func settle(n):
	for i in range(n): await process_frame
func run():
	var scene_path=ProjectSettings.get_setting("application/run/main_scene")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_path=arg.trim_prefix("--scene=")
	var world=load(scene_path).instantiate()
	root.add_child(world)
	current_scene=world
	await settle(80)
	var environments=world.find_children("*","WorldEnvironment",true,false)
	var env:Environment=environments[0].environment
	print("AO_ENV ",environments[0].get_path()," enabled=",env.ssao_enabled)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var label="world" if "world" in scene_path else scene_path.get_file().get_basename()
	var report={"scene":scene_path,"renderer":RenderingServer.get_current_rendering_method(),"initially_enabled":root.get_node("AmbientOcclusion").enabled,"samples":{}}
	for enabled in [false,true]:
		preload("res://scripts/ambient_occlusion.gd").configure(env)
		root.get_node("AmbientOcclusion").set_enabled(enabled)
		await settle(35)
		var total=0.0
		var samples=[]
		for i in range(60):
			var start=Time.get_ticks_usec()
			await process_frame
			samples.append((Time.get_ticks_usec()-start)/1000.0)
		await RenderingServer.frame_post_draw
		var suffix="on" if enabled else "off"
		root.get_texture().get_image().save_png(OUT+label+"_"+suffix+".png")
		samples.sort()
		report.samples[suffix]={"median_frame_ms":samples[30],"p95_frame_ms":samples[57]}
	FileAccess.open(OUT+label+"_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("AO_REPORT ",JSON.stringify(report))
	world.queue_free();await settle(3);quit()
