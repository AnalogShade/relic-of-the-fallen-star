extends SceneTree
## Production attack and real bandit scene. Freeze enemy AI to isolate
## placement from evasion; never call apply_claw_hit directly.
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var actor
var enemy
var level: Node3D
var ap: AnimationPlayer
var skeleton: Skeleton3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func prepare(facing: float, angle: float, distance: float, elevation := 0.0) -> void:
	actor.cancel_claw()
	if is_instance_valid(enemy): enemy.free()
	actor.get_node("Nael").rotation.y = deg_to_rad(facing)
	actor.pivot.rotation.y = deg_to_rad(facing + 137.0)
	enemy = load("res://scenes/bandit.tscn").instantiate()
	enemy.temperament = "agressif"
	enemy.behavior_seed = 42
	var direction := Vector3(sin(deg_to_rad(facing + angle)), 0, cos(deg_to_rad(facing + angle)))
	enemy.position = actor.global_position + direction * distance
	enemy.position.y = elevation
	level.add_child(enemy)
	enemy.set_physics_process(false)
	await frames(2)

func begin_left() -> bool:
	actor.left_claw_chance = 1.0
	actor.claw_chain_count = 1
	actor.claw_chain_remaining = 0.65
	return actor.start_claw() and actor.active_claw_left

func finish() -> void:
	for i in range(300):
		if not actor.is_attacking: return
		await frames(1)
	check(false, "Attack ends within test timeout")

func placement(label: String, facing: float, angle: float, distance: float, expected: float, elevation := 0.0, speed := 1.6) -> void:
	await prepare(facing, angle, distance, elevation)
	check(begin_left(), label + ": real left animation starts")
	ap.speed_scale = speed
	var root_before: Basis = actor.get_node("Nael").global_basis
	var changes := 0
	var last_health := 100.0
	while actor.is_attacking:
		await frames(1)
		if enemy.health != last_health:
			changes += 1
			check(ap.current_animation_position >= actor.LEFT_CLAW_IMPACT_TIME, label + ": damage follows impact pose")
			last_health = enemy.health
	check(is_equal_approx(100.0 - enemy.health, expected), label + ": damage = %.1f (expected %.1f)" % [100.0 - enemy.health, expected])
	check(changes == (1 if expected > 0 else 0), label + ": no repeated damage in one swing")
	check(actor.get_node("Nael").global_basis.is_equal_approx(root_before), label + ": animated torso does not redirect hit cone")
	cases.append({"case":label,"facing":facing,"angle":angle,"distance":distance,"speed":speed,"expected_damage":expected,"actual_damage":100.0-enemy.health,"hit_count":changes})

func run() -> void:
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,1,40)
	col.shape = shape
	col.position.y = -0.5
	floor_body.add_child(col)
	level.add_child(floor_body)
	actor = load("res://scenes/player.tscn").instantiate()
	actor.position.y = 0.5
	level.add_child(actor)
	ap = actor.get_node("Nael").animator
	skeleton = actor.get_node("Nael").find_child("Skeleton3D",true,false)
	await frames(30)
	for facing in [0.0,90.0,180.0,270.0]:
		await placement("Front facing %.0f" % facing, facing, 0, 1.25, 50)
	for angle in [-60.0,-35.0,35.0,60.0]:
		await placement("Inside cone %.0f" % angle, 180, angle, 1.4, 50)
	for angle in [-80.0,80.0,180.0]:
		await placement("Outside cone %.0f" % angle, 180, angle, 1.4, 0)
	await placement("Near edge including bandit radius",180,0,2.05,50)
	await placement("Outside range",180,0,2.2,0)
	await placement("Different elevation",180,0,1.25,0,3.0)
	for speed in [0.5,1.0,3.0]:
		await placement("Playback speed %.1f" % speed,180,0,1.25,50,0,speed)
	await prepare(180,0,1.25)
	check(begin_left(),"Pause: left starts")
	ap.speed_scale = 0
	await frames(40)
	check(enemy.health == 100 and actor.is_attacking,"Paused anticipation produces zero damage")
	ap.speed_scale = 1.6
	await finish()
	check(enemy.health == 50,"Resume produces exactly 50 damage")
	await prepare(180,0,1.25)
	var wall := StaticBody3D.new()
	var wall_col := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(3,3,0.1)
	wall_col.shape = wall_shape
	wall.add_child(wall_col)
	wall.position = Vector3(0,1.5,-0.65)
	level.add_child(wall)
	await frames(2)
	check(begin_left(),"Wall: left starts")
	await finish()
	check(enemy.health == 100,"Wall blocks left claw damage")
	wall.free()
	await frames(2)
	check(begin_left(),"After wall removal: left starts")
	await finish()
	check(enemy.health == 50,"Same target takes 50 after wall removal")
	check(begin_left(),"Second left strike starts")
	await finish()
	check(is_instance_valid(enemy) and enemy.health == 0 and enemy.state == "dead", "Two left strikes kill the real 100 HP bandit and leave its body")
	check(not enemy.is_in_group("enemies"), "Dead bandit is no longer a combat target")
	await prepare(180,0,1.25)
	check(begin_left(),"Cancellation: left starts")
	actor.cancel_claw()
	await frames(45)
	check(enemy.health == 100,"Cancelled left strike deals no damage")
	check(begin_left(),"Bone orientation: left starts")
	var hips := skeleton.find_bone("Hips")
	var initial_pose := skeleton.get_bone_global_pose(hips).basis.get_rotation_quaternion()
	while ap.current_animation_position < actor.LEFT_CLAW_IMPACT_TIME:
		await frames(1)
	var impact_pose := skeleton.get_bone_global_pose(hips).basis.get_rotation_quaternion()
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand"))
	check(initial_pose.angle_to(impact_pose) > 0.1,"Torso actually rotates during the tested animation")
	await finish()
	check(enemy.health == 50,"Damage still lands despite animated torso rotation")
	print("LEFT_IMPACT_DIAGNOSTIC: hand=",hand.origin," target=",enemy.global_position," torso_rotation_degrees=",rad_to_deg(initial_pose.angle_to(impact_pose)))
	await prepare(180,0,1.25)
	enemy.set_physics_process(true)
	check(begin_left(),"Active AI: left starts against a live combat bandit")
	await finish()
	check(is_instance_valid(enemy) and enemy.health == 50,"Active AI: left removes 50 HP while enemy combat is running")
	var report := {"failures":failures,"placement_cases":cases,"physics_ticks":Engine.physics_ticks_per_second,"damage_detection":"timed forward cone, range including enemy collision radius, obstacle ray","animation_modified":false}
	var report_path := "user://left_claw_damage_report.json"
	if not OS.get_cmdline_user_args().is_empty():
		report_path = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("REPORT_PATH: ",ProjectSettings.globalize_path(report_path))
	print("LEFT_CLAW_DAMAGE_RESULT: %d failures, %d placement cases" % [failures.size(),cases.size()])
	level.free()
	quit(0 if failures.is_empty() else 1)
