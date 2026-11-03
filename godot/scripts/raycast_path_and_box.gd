extends SceneTree

func _init():
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("Original/HUD").hide()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	
	for i in range(25):
		await physics_frame
		
	var space = world.get_world_3d().direct_space_state
	
	var cam_pos = Vector3(-390.0, 165.0, -10.0)
	var target = Vector3(-210.0, 12.0, -10.0)
	var fov_y = deg_to_rad(65.0)
	
	var W = 1010.0
	var H = 486.0
	var aspect = W / H
	var tan_half = tan(fov_y / 2.0)
	
	var fwd = (target - cam_pos).normalized()
	var right = Vector3(0, 0, 1)
	var up = right.cross(fwd).normalized()
	
	# Let's sample the path at several key pixel points:
	# From user drawing: starts around (630, 56) down through (550, 80), (480, 130), (430, 180), (405, 230)
	var path_pixels = [
		Vector2(630, 56),
		Vector2(585, 68),
		Vector2(540, 85),
		Vector2(495, 115),
		Vector2(455, 155),
		Vector2(425, 195),
		Vector2(405, 230)
	]
	
	print("--- PATH 3D WAYPOINTS ---")
	for p in path_pixels:
		var ndc_y = 1.0 - 2.0 * (p.y / H)
		var ndc_x = (2.0 * (p.x / W) - 1.0) * aspect
		var ray_dir = (fwd + right * (ndc_x * tan_half) + up * (ndc_y * tan_half)).normalized()
		var q = PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + ray_dir * 1000.0)
		var res = space.intersect_ray(q)
		if not res.is_empty():
			print("Pixel (", p.x, ", ", p.y, ") -> 3D Pos: Vector2(%.1f, %.1f) [Y=%.2f]" % [res.position.x, res.position.z, res.position.y])
			
	# Let's sample the box bounds:
	# Corners of user's blue box:
	# Top-left: around (100, 55)
	# Top-right: around (360, 45)
	# Bottom-right: around (380, 420)
	# Bottom-left: around (75, 420)
	var box_corners = [
		Vector2(100, 55),
		Vector2(360, 45),
		Vector2(380, 420),
		Vector2(75, 420)
	]
	print("--- BOX CORNERS 3D ---")
	for p in box_corners:
		var ndc_y = 1.0 - 2.0 * (p.y / H)
		var ndc_x = (2.0 * (p.x / W) - 1.0) * aspect
		var ray_dir = (fwd + right * (ndc_x * tan_half) + up * (ndc_y * tan_half)).normalized()
		var q = PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + ray_dir * 1000.0)
		var res = space.intersect_ray(q)
		if not res.is_empty():
			print("Corner (", p.x, ", ", p.y, ") -> Vector2(%.1f, %.1f)" % [res.position.x, res.position.z])
			
	quit()
