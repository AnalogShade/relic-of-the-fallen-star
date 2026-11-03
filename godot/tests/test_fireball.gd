extends SceneTree

var failures := 0
var tests := 0

func check(condition: bool, message: String) -> void:
	tests += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		print("FAIL: %s" % message)

func _init() -> void:
	print("========================================")
	print("TEST SUITE: FIREBALL & MAGIC CASTING")
	print("========================================")
	
	_test_assets()
	_test_projectile_scene()
	_test_inventory_check()
	_test_flight_and_impact()
	
	print("\n========================================")
	print("TOTAL TESTS: %d | FAILURES: %d" % [tests, failures])
	print("========================================")
	quit(1 if failures > 0 else 0)

func _test_assets() -> void:
	print("\n[1] Testing 3D assets...")
	var fb_glb: PackedScene = load("res://assets/spells/fireball.glb")
	check(fb_glb != null, "fireball.glb loaded successfully")
	
	var shard_glb: PackedScene = load("res://assets/spells/fireball_shard.glb")
	check(shard_glb != null, "fireball_shard.glb loaded successfully")
	
	if fb_glb:
		var inst: Node = fb_glb.instantiate()
		var anim_player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(anim_player != null, "fireball.glb contains AnimationPlayer")
		if anim_player:
			check(anim_player.has_animation("Fireball_Flight"), "Animation Fireball_Flight exists")
		inst.free()

func _test_projectile_scene() -> void:
	print("\n[2] Testing FireballProjectile scene...")
	var proj_scene: PackedScene = load("res://scenes/spells/fireball_projectile.tscn")
	check(proj_scene != null, "fireball_projectile.tscn loaded successfully")
	
	var proj = proj_scene.instantiate()
	root.add_child(proj)
	
	check(proj.has_node("FireballModel"), "Projectile contains 3D animated model")
	check(proj.has_node("FireLight"), "Projectile contains OmniLight3D")
	check(proj.has_node("ShardTrail"), "Projectile contains ShardTrail particles")
	
	var shard_p: CPUParticles3D = proj.get_node("ShardTrail") as CPUParticles3D
	if shard_p:
		check(shard_p.local_coords == false, "Shard particles use world-space (local_coords == false) for true trailing embers")
		check(shard_p.mesh != null, "Shard particles have 3D shard mesh assigned")
	
	proj.queue_free()

func _test_inventory_check() -> void:
	print("\n[3] Testing Inventory spell gating...")
	var inventory_script = load("res://scripts/inventory.gd")
	var inv = inventory_script.new()
	root.add_child(inv)
	
	check(inv.has_method("has_fireball_relic"), "inventory.gd has has_fireball_relic method")
	check(inv.has_fireball_relic() == false, "Initially does not have fireball relic")
	
	# Add first_echo
	var added = inv.add_item("first_echo")
	check(added == true, "Added first_echo to inventory")
	check(inv.has_fireball_relic() == true, "has_fireball_relic returns true after obtaining first_echo")
	
	inv.queue_free()

func _test_flight_and_impact() -> void:
	print("\n[4] Testing flight movement and enemy damage...")
	var container := Node3D.new()
	root.add_child(container)
	
	var proj_scene: PackedScene = load("res://scenes/spells/fireball_projectile.tscn")
	var proj = proj_scene.instantiate()
	container.add_child(proj)
	
	var start := Vector3(0, 5, 0)
	var dir := Vector3(0, 0, -1)
	proj.launch(start, dir)
	check(proj.position == start or proj.global_position == start, "Projectile launched from correct start position")
	check(proj.direction == dir, "Projectile launched in correct direction")
	
	# Simulate dummy enemy
	var dummy = StaticBody3D.new()
	dummy.name = "DummyEnemy"
	dummy.add_to_group("enemies")
	dummy.position = Vector3(0, 5, -5)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	col.shape = box
	dummy.add_child(col)
	
	# Attach damage tracker
	var script = GDScript.new()
	script.source_code = """
extends StaticBody3D
var hit_received := false
var damage_taken := 0.0
func take_damage(amount: float, _source: Vector3) -> void:
	hit_received = true
	damage_taken += amount
"""
	script.reload()
	dummy.set_script(script)
	root.add_child(dummy)
	
	# Handle hit
	proj._handle_hit(dummy)
	check(dummy.hit_received == true, "Enemy received damage on hit")
	check(dummy.damage_taken == 40.0, "Enemy took correct damage amount (40)")
	check(proj.impacted == true, "Projectile marked as impacted after hit")
	
	dummy.queue_free()
	proj.queue_free()
