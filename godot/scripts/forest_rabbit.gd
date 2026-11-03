extends CharacterBody3D
## Quiet wildlife: short hops between grazing and sniffing, with ground/obstacle checks.
@export var roam_radius: float = 2.2
@export var hop_speed: float = 0.85
@export var random_seed: int = 1709
@onready var model: Node3D = $Model
@onready var animator: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
var home: Vector3
var state: String = "idle"
var elapsed: float = 0.0
var duration: float = 2.0
var heading := Vector3.FORWARD
var step_index: int = 0
var shy_cooldown: float = 5.0
var rng := RandomNumberGenerator.new()
const ROUTINE = ["sniff", "hop", "graze", "hop", "idle", "hop"]
const CLIPS = {"idle": "Rabbit_Idle", "hop": "Rabbit_Hop", "sniff": "Rabbit_Sniff", "graze": "Rabbit_Graze"}

func _ready() -> void:
	home = global_position
	rng.seed = random_seed
	for clip in CLIPS.values():
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	set_state("idle", 2.0)

func set_state(next: String, seconds: float) -> void:
	state = next
	elapsed = 0.0
	duration = seconds
	animator.play(CLIPS[state], 0.12)

func safe_step(direction: Vector3) -> bool:
	var probe := global_position + direction * 0.55
	if Vector2(probe.x - home.x, probe.z - home.z).length() > roam_radius:
		return false
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.7, probe - Vector3.UP * 0.7, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.8 or absf(hit.position.y - global_position.y) > 0.24:
		return false
	var obstacle := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.20, probe + Vector3.UP * 0.20, 1)
	return space.intersect_ray(obstacle).is_empty()

func choose_heading(preferred: Vector3 = Vector3.ZERO) -> bool:
	for attempt in range(14):
		var angle := rng.randf_range(-PI, PI)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		if attempt == 0 and preferred.length_squared() > 0.01:
			direction = preferred.normalized()
		if safe_step(direction):
			heading = direction
			return true
	return false

func next_activity() -> void:
	var next: String = ROUTINE[step_index % ROUTINE.size()]
	step_index += 1
	if next == "hop":
		if choose_heading():
			set_state("hop", animator.get_animation("Rabbit_Hop").length * rng.randi_range(2, 4))
		else:
			set_state("sniff", 3.0)
	elif next == "graze":
		set_state("graze", animator.get_animation("Rabbit_Graze").length)
	elif next == "sniff":
		set_state("sniff", animator.get_animation("Rabbit_Sniff").length)
	else:
		set_state("idle", rng.randf_range(2.0, 4.0))

func _physics_process(delta: float) -> void:
	elapsed += delta
	shy_cooldown -= delta
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	else:
		velocity.y = 0.0
		if elapsed >= duration:
			next_activity()
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and shy_cooldown <= 0.0 and global_position.distance_to(player.global_position) < 1.3:
			var away := global_position - player.global_position
			away.y = 0.0
			if choose_heading(away):
				set_state("hop", animator.get_animation("Rabbit_Hop").length * 3.0)
				shy_cooldown = 6.0
	velocity.x = 0.0
	velocity.z = 0.0
	if state == "hop" and is_on_floor():
		if not safe_step(heading):
			set_state("sniff", 3.0)
		else:
			var phase := fmod(elapsed, animator.get_animation("Rabbit_Hop").length) / animator.get_animation("Rabbit_Hop").length
			var speed := hop_speed * pow(sin(PI * phase), 2.0)
			velocity.x = heading.x * speed
			velocity.z = heading.z * speed
			model.rotation.y = lerp_angle(model.rotation.y, atan2(heading.x, heading.z), minf(8.0 * delta, 1.0))
	move_and_slide()
	if global_position.y < -4.0:
		global_position = home
		velocity = Vector3.ZERO
		set_state("idle", 2.0)
