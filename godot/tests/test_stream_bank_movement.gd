extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(30)
	var p = world.get_node("Original/Player")
	p.damage_invulnerability = 10000.0
	p.pivot.rotation.y = 0.0
	for sample in [[Vector3(-3.3126,0.440947,2.935997), "move_left"], [Vector3(-3.741223,-0.054679,7.9998), "move_left"], [Vector3(3.818298,0.789444,-2.932918), "move_right"]]:
		p.global_position = sample[0] + Vector3.UP * 0.03
		p.velocity = Vector3.ZERO
		Input.action_press(sample[1])
		await frames(35)
		# Reproduce arriving at the bank after the ground and air jumps.
		p.jumped_this_air = true
		p.air_jump_used = true
		p.coyote_time = 0.0
		await frames(2)
		var start: Vector3 = p.global_position
		print("CONTACT ", start, " floor=", p.is_on_floor(), " support=", p._can_unstuck_jump())
		Input.action_press("jump")
		await frames(8)
		Input.action_release("jump")
		check(p.global_position.y > start.y + 0.4, "Jump escapes bank after spent air jump at " + str(sample[0]))
		Input.action_release(sample[1])
		await frames(2)
	var bank := StaticBody3D.new()
	var bank_shape := CollisionShape3D.new()
	var bank_box := BoxShape3D.new()
	bank_box.size = Vector3(8,0.2,8)
	bank_shape.shape = bank_box
	bank.add_child(bank_shape)
	bank.position = Vector3(150,50,150)
	bank.rotation.z = deg_to_rad(60.0)
	world.add_child(bank)
	var other_bank := bank.duplicate() as StaticBody3D
	other_bank.rotation.z = -bank.rotation.z
	world.add_child(other_bank)
	p.global_position = Vector3(150,52,150)
	p.velocity = Vector3.ZERO
	Input.action_press("move_right")
	await frames(60)
	print("STEEP ", p.global_position, " floor=", p.is_on_floor(), " wall=", p.is_on_wall(), " support=", p._can_unstuck_jump())
	p.jumped_this_air = true
	p.air_jump_used = true
	p.coyote_time = 0.0
	await frames(2)
	var steep_start: Vector3 = p.global_position
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	Input.action_release("move_right")
	check(p.global_position.y > steep_start.y + 0.4, "Steep supporting slope restores jump after both jumps were used")
	# Airborne players cannot refill jumps merely by touching a vertical wall.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,20,8)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(15,10,10)
	world.add_child(wall)
	p.global_position = Vector3(14,8,10)
	p.velocity = Vector3.ZERO
	p.jumped_this_air = true
	p.air_jump_used = true
	Input.action_press("move_right")
	await frames(10)
	check(not p._can_unstuck_jump() and p.air_jump_used, "Vertical wall does not restore jumps")
	Input.action_release("move_right")
	world.free()
	print("BANK_MOVEMENT failures=", failures)
	quit(1 if failures else 0)
