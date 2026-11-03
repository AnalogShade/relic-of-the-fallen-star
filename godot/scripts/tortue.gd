extends CharacterBody3D

## Tortue cheminant paisiblement sur un circuit circulaire en boucle.
@export var walk_speed: float = 0.14
@export var slope_align_speed: float = 5.0
@export var ground_snap_speed: float = 12.0

@onready var model: Node3D = $Model
@onready var animator: AnimationPlayer = $Model/AnimationPlayer

var curve: Curve3D
var curve_length: float = 0.0
var progress: float = 0.0

# Circuit le long de la rivière, remontant vers le centre/pont, puis s'enfonçant dans la forêt et bouclant.
const WAYPOINTS_2D = [
	Vector2(14.0, 72.0),   # 1. Bord de rivière au sud (proche plage)
	Vector2(11.0, 56.0),   # 2. Le long de la rive
	Vector2(7.5, 42.0),    # 3. Rive montant vers le nord
	Vector2(4.5, 28.0),    # 4. Rive s'approchant du pont
	Vector2(-2.0, 16.0),   # 5. Centre (proche pont / clairière de départ)
	Vector2(-12.0, 13.5),  # 6. Virage vers l'ouest dans la forêt
	Vector2(-28.0, 14.0),  # 7. Traversée sous bois
	Vector2(-48.0, 20.0),  # 8. Montée douce forêt ouest
	Vector2(-64.0, 30.0),  # 9. Clairière ouest face aux plaines
	Vector2(-66.0, 46.0),  # 10. Descente sud le long de la lisière
	Vector2(-58.0, 60.0),  # 11. Collines boisées du sud
	Vector2(-41.0, 65.0),  # 12. Lisière sud vers l'est
	Vector2(-22.0, 72.0),  # 13. Retour vers la zone de la rivière
	Vector2(-4.0, 74.0),   # 14. Approche de la rive sud
	Vector2(8.0, 74.0)     # 15. Bouclage avec le point de départ
]

func _ready() -> void:
	_setup_curve()
	_setup_animation()
	_snap_initial_position()

func _setup_curve() -> void:
	curve = Curve3D.new()
	for p in WAYPOINTS_2D:
		curve.add_point(Vector3(p.x, 0.0, p.y))
	# Fermeture de la boucle
	curve.add_point(Vector3(WAYPOINTS_2D[0].x, 0.0, WAYPOINTS_2D[0].y))
	curve_length = curve.get_baked_length()
	progress = 0.0

func _setup_animation() -> void:
	if animator:
		var anim = animator.get_animation("walk1")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		animator.play("walk1")
		# Vitesse calée pour éviter le patinage (0.136 m/s = cycle 2.0s à vitesse 1.0)
		animator.speed_scale = walk_speed / 0.136

func _snap_initial_position() -> void:
	var pt := curve.sample_baked(0.0)
	global_position.x = pt.x
	global_position.z = pt.z
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(pt.x, 40.0, pt.z),
		Vector3(pt.x, -10.0, pt.z),
		1
	)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		global_position.y = hit.position.y
		_align_to_surface(hit.normal, Vector3(0, 0, -1), 1.0)

func _physics_process(delta: float) -> void:
	if curve_length <= 0.0:
		return
	
	# Avancement le long de la courbe spline
	progress = fmod(progress + walk_speed * delta, curve_length)
	
	var current_pt := curve.sample_baked(progress)
	var look_ahead := curve.sample_baked(fmod(progress + 0.6, curve_length))
	var forward_dir := (look_ahead - current_pt)
	forward_dir.y = 0.0
	if forward_dir.length_squared() > 0.001:
		forward_dir = forward_dir.normalized()
	else:
		forward_dir = -transform.basis.z
	
	global_position.x = current_pt.x
	global_position.z = current_pt.z
	
	# Détection du sol et de la normale de pente
	var space := get_world_3d().direct_space_state
	var ray_from := Vector3(current_pt.x, global_position.y + 1.5, current_pt.z)
	var ray_to := Vector3(current_pt.x, global_position.y - 3.0, current_pt.z)
	var ray := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	var hit := space.intersect_ray(ray)
	
	if not hit.is_empty():
		# Ajustement fluide de la hauteur au sol
		global_position.y = lerpf(global_position.y, hit.position.y, minf(ground_snap_speed * delta, 1.0))
		# Inclinaison sur la pente (tangage + roulis selon la normale du terrain)
		_align_to_surface(hit.normal, forward_dir, minf(slope_align_speed * delta, 1.0))
	else:
		# En cas de micro-saut, recherche plus large vers le bas
		var broad_ray := PhysicsRayQueryParameters3D.create(
			Vector3(current_pt.x, 40.0, current_pt.z),
			Vector3(current_pt.x, -10.0, current_pt.z),
			1
		)
		var broad_hit := space.intersect_ray(broad_ray)
		if not broad_hit.is_empty():
			global_position.y = broad_hit.position.y
			_align_to_surface(broad_hit.normal, forward_dir, 1.0)

func _align_to_surface(normal: Vector3, forward: Vector3, weight: float) -> void:
	if normal.length_squared() < 0.1:
		normal = Vector3.UP
	
	# Projection de la direction avant sur le plan tangent à la surface
	var surface_forward := (forward - normal * forward.dot(normal))
	if surface_forward.length_squared() < 0.001:
		surface_forward = -transform.basis.z
		surface_forward = (surface_forward - normal * surface_forward.dot(normal))
	surface_forward = surface_forward.normalized()
	
	var surface_right := surface_forward.cross(normal).normalized()
	# Construction de la base 3D orientée (right, up, -forward)
	var target_basis := Basis(surface_right, normal, -surface_forward).orthonormalized()
	
	transform.basis = transform.basis.slerp(target_basis, weight).orthonormalized()
