extends Node3D

## Truite autonome nageant paisiblement dans le lac.
@export var fish_scale: float = 1.0
@export var base_speed: float = 1.2
@export var turn_speed: float = 2.0
@export var lake_center: Vector3 = Vector3(7.0, 4.95, -213.0)
@export var lake_radius: float = 13.5
@export var min_depth_y: float = 4.60
@export var max_depth_y: float = 5.25

@onready var model: Node3D = get_node_or_null("Model")

var current_target: Vector3
var target_timer: float = 0.0
var swim_phase: float = 0.0
var animator: AnimationPlayer

func _ready() -> void:
	# Appliquer l'échelle du poisson
	scale = Vector3.ONE * fish_scale
	swim_phase = randf_range(0.0, 100.0)
	
	# Configuration de l'animation
	animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator:
		for anim_name in animator.get_animation_list():
			var anim := animator.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
		
		if animator.has_animation("truite_swim"):
			animator.play("truite_swim")
		elif animator.has_animation("Armature|truite_swim"):
			animator.play("Armature|truite_swim")
		else:
			var list := animator.get_animation_list()
			if list.size() > 0:
				animator.play(list[0])
		
		# Cadence de nage adaptée à la taille (les petites battent plus vite)
		animator.speed_scale = (1.0 / sqrt(clampf(fish_scale, 0.5, 2.0))) * randf_range(0.9, 1.1)
		animator.seek(randf_range(0.0, 1.5))
	
	_pick_new_target()
	var initial_dir := (current_target - global_position)
	if initial_dir.length_squared() > 0.001:
		initial_dir.y = 0.0
		initial_dir = initial_dir.normalized()
		var right := initial_dir.cross(Vector3.UP).normalized()
		var up := right.cross(initial_dir).normalized()
		transform.basis = Basis(right, up, -initial_dir).orthonormalized().scaled(Vector3.ONE * fish_scale)

func _pick_new_target() -> void:
	target_timer = randf_range(5.0, 10.0)
	# Choisir un point aléatoire dans le disque du lac
	var angle := randf_range(0.0, TAU)
	var dist := sqrt(randf()) * lake_radius
	var tx := lake_center.x + cos(angle) * dist
	var tz := lake_center.z + sin(angle) * dist
	var ty := randf_range(min_depth_y, max_depth_y)
	current_target = Vector3(tx, ty, tz)

func _physics_process(delta: float) -> void:
	swim_phase += delta * 2.0
	target_timer -= delta
	
	# Vérification des limites du lac
	var dist_from_center := Vector2(global_position.x - lake_center.x, global_position.z - lake_center.z).length()
	if dist_from_center > lake_radius:
		# Forcer un retour vers le centre
		current_target = lake_center + Vector3(randf_range(-3.0, 3.0), randf_range(-0.2, 0.2), randf_range(-3.0, 3.0))
		target_timer = randf_range(4.0, 7.0)
	elif target_timer <= 0.0 or global_position.distance_to(current_target) < 1.5:
		_pick_new_target()
	
	# Direction vers la cible
	var dir := (current_target - global_position)
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = -transform.basis.z
	
	# Rotation douce vers la cible (tangage modéré, lacet principal)
	var target_forward := dir
	# Atténuer le tangage vertical pour un déplacement de poisson horizontal réaliste
	target_forward.y = clampf(target_forward.y, -0.25, 0.25)
	target_forward = target_forward.normalized()
	
	var up := Vector3.UP
	var right := target_forward.cross(up).normalized()
	var real_up := right.cross(target_forward).normalized()
	var target_basis := Basis(right, real_up, -target_forward).orthonormalized()
	
	var current_rot := transform.basis.orthonormalized()
	var blended_basis := current_rot.slerp(target_basis, minf(turn_speed * delta, 1.0)).orthonormalized()
	transform.basis = blended_basis.scaled(Vector3.ONE * fish_scale)
	
	# Déplacement vers l'avant
	var move_forward := -transform.basis.z
	var current_speed := base_speed * clampf(fish_scale, 0.7, 1.3)
	global_position += move_forward * current_speed * delta
	
	# Légère ondulation verticale naturelle de nage
	global_position.y += sin(swim_phase) * 0.002
	
	# Maintien strict de la profondeur
	global_position.y = clampf(global_position.y, min_depth_y, max_depth_y)
