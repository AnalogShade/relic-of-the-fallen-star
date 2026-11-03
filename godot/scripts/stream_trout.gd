extends Node3D
## Station-holding trout: swim animation continues while position stays near home.
var fish_scale := 0.7
var home := Vector3.ZERO
var upstream := Vector3.FORWARD
var motion_room := Vector2.ZERO
var allow_wobble := false
var phase := 0.0
var elapsed := 0.0
var wait_time := 0.0
var move_time := 0.0
var move_duration := 2.0
var moving := false
var origin := Vector3.ZERO
var destination := Vector3.ZERO
var station := Vector3.ZERO
var animator: AnimationPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	scale = Vector3.ONE * fish_scale
	station = home
	destination = home
	global_position = home
	phase = rng.randf_range(0.0, TAU)
	wait_time = rng.randf_range(5.0, 16.0)
	global_basis = Basis.looking_at(upstream).scaled(Vector3.ONE * fish_scale)
	animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null and animator.has_animation("truite_swim"):
		animator.animation_finished.connect(_repeat_swim)
		animator.play("truite_swim")
		animator.speed_scale = rng.randf_range(0.95, 1.15) / sqrt(fish_scale)
		animator.seek(rng.randf_range(0.0, animator.get_animation("truite_swim").length), true)

func _repeat_swim(animation: StringName) -> void:
	if animation == &"truite_swim":
		animator.play("truite_swim")

func _physics_process(delta: float) -> void:
	elapsed += delta
	if moving:
		move_time = minf(move_time + delta, move_duration)
		var t := smoothstep(0.0, 1.0, move_time / move_duration)
		station = origin.lerp(destination, t)
		if move_time >= move_duration:
			moving = false
			wait_time = rng.randf_range(9.0, 21.0)
	else:
		wait_time -= delta
		if wait_time <= 0.0:
			var side := upstream.cross(Vector3.UP).normalized()
			var candidate := home + upstream * rng.randf_range(-motion_room.x, motion_room.x) + side * rng.randf_range(-motion_room.y, motion_room.y)
			if motion_room.length_squared() > 0.0001:
				origin = station
				destination = candidate
				move_time = 0.0
				move_duration = rng.randf_range(2.5, 4.5)
				moving = true
			else:
				wait_time = rng.randf_range(5.0, 10.0)
	# Bounded, frame-rate independent corrections, never a random walk downstream.
	var wobble := upstream.cross(Vector3.UP) * sin(elapsed * 1.7 + phase) * 0.025
	wobble.y = sin(elapsed * 1.3 + phase) * 0.012
	global_position = station + wobble if allow_wobble else station
	var facing := upstream.rotated(Vector3.UP, sin(elapsed * 0.65 + phase) * 0.045)
	global_basis = Basis.looking_at(facing).scaled(Vector3.ONE * fish_scale)
