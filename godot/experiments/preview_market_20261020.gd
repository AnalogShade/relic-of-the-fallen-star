extends SceneTree
var world: Node3D
var camera: Camera3D
const OUT="C:/Users/Utilisateur/Documents/Dev/Jeux/Relic of the fallen star/3D MODELS/chateau/marche_20261020/"
func _initialize() -> void:
	call_deferred("run")
func point(p: Vector3) -> Vector3:
	var q=p-Vector3(2,4,0)
	return Basis(Vector3.UP,PI/2.0-.35)*Vector3(q.x,q.z,-q.y)+Vector3(-226,12,-32)
func capture(eye: Vector3,target: Vector3,file: String) -> void:
	camera.global_position=point(eye)
	camera.look_at(point(target))
	for i in range(25): await process_frame
	for ui in root.find_children("*","Control",true,false): ui.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+file)
func run() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(20): await physics_frame
	var player=world.get_node("Original/Player")
	player.set_physics_process(false)
	for ui in world.find_children("*","CanvasLayer",true,false): ui.hide()
	world.get_node("Original/WorldEnvironment").environment.fog_enabled=false
	camera=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	camera.far=2500
	camera.fov=47
	await capture(Vector3(-37,-52,43),Vector3(1,-8,4),"godot_ensemble.png")
	await capture(Vector3(-6,-40,19),Vector3(12,-15,1),"godot_marche.png")
	await capture(Vector3(12,-23,3.2),Vector3(12,-13,1.8),"godot_marche_joueur.png")
	await capture(Vector3(-31,-34,24),Vector3(-12,-7,0),"godot_terre_maisons.png")
	print("CASTLE_PREVIEW_COMPLETE")
	world.queue_free()
	camera.queue_free()
	await process_frame
	quit()

