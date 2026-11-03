extends Node3D
const FLAG := "story/lake_monster_defeated"
const CLAIMED := "relic/primordial_wave"
const DOCK_LANDING := Vector3(19.0, 6.52, -212.7)
const FLIGHT_DURATION := 2.6
var relic: MeshInstance3D
var halo: MeshInstance3D
var label: Label3D
var elapsed := 0.0
var appeared := false
var flying := false
var flight_elapsed := 0.0
var flight_origin := Vector3.ZERO
var landing_point := DOCK_LANDING
var glow: OmniLight3D
var trail: CPUParticles3D

func _ready() -> void:
	add_to_group("interactable")
	# The boss walks and returns home while sinking. Its reward must stay in world space.
	set_as_top_level(true)
	var world := get_tree().current_scene
	var pier: Node3D = world.get_node_or_null("Sectors/OasisDuNord/OasisPier") if world else null
	if pier: landing_point = pier.to_global(DOCK_LANDING)
	global_position = landing_point
	relic = MeshInstance3D.new()
	var crystal := SphereMesh.new()
	crystal.radius = 0.28
	crystal.height = 0.85
	crystal.radial_segments = 5
	crystal.rings = 1
	relic.mesh = crystal
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("9affdf")
	mat.emission_enabled = true
	mat.emission = Color("45eecf")
	mat.emission_energy_multiplier = 2.5
	relic.material_override = mat
	add_child(relic)
	halo = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.56
	halo.mesh = ring
	halo.material_override = mat
	add_child(halo)
	glow = OmniLight3D.new()
	glow.light_color = Color("78ffdf")
	glow.omni_range = 4.0
	glow.light_energy = 1.5
	glow.position.y = 1.0
	add_child(glow)
	label = Label3D.new()
	label.text = "Éclat de l’Onde primordiale\nDeuxième fragment du Premier Souffle"
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 25
	label.pixel_size = 0.009
	label.modulate = Color("a0ffe7")
	add_child(label)
	trail = CPUParticles3D.new()
	trail.emitting = false
	trail.amount = 64
	trail.lifetime = 0.85
	trail.local_coords = false
	trail.direction = Vector3.UP
	trail.spread = 90
	trail.initial_velocity_min = 0.15
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, -0.15, 0)
	trail.scale_amount_min = 0.025
	trail.scale_amount_max = 0.06
	var spark := SphereMesh.new()
	spark.radius = 1.0
	spark.height = 2.0
	spark.radial_segments = 6
	spark.rings = 3
	trail.mesh = spark
	trail.material_override = mat
	trail.position.y = 1.1
	add_child(trail)
	hide()

func _unclaimed(bag: Node) -> bool:
	return bool(bag.collected.get(FLAG, false)) and not bool(bag.collected.get(CLAIMED, false)) and not bag.equipment.has("primordial_wave")

func release_from(origin: Vector3) -> void:
	var bag := get_node("/root/Inventory")
	if appeared or not _unclaimed(bag): return
	appeared = true
	flying = true
	flight_elapsed = 0.0
	flight_origin = origin - Vector3.UP * 1.1
	global_position = flight_origin
	label.hide()
	trail.emitting = true
	show()
	bag.ui.notify("Le fragment quitte le Dévoreur et rejoint le bout du quai…")

func _process(delta: float) -> void:
	var bag := get_node("/root/Inventory")
	if not _unclaimed(bag):
		hide()
		trail.emitting = false
		return
	if not appeared:
		appeared = true
		global_position = landing_point
		bag.ui.notify("L’Éclat de l’Onde primordiale vous attend au bout du quai.")
	show()
	if bag.is_open: return
	if flying:
		flight_elapsed += delta
		var progress := clampf(flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, progress)
		global_position = flight_origin.lerp(landing_point, eased) + Vector3.UP * sin(progress * PI) * 4.0
		if progress >= 1.0:
			flying = false
			global_position = landing_point
			label.show()
			trail.emitting = false
			bag.ui.notify("Fragment libéré ! F au bout du quai pour éveiller la Nova (Q).")
	elapsed += delta
	relic.position.y = 1.1 + (0.0 if flying else sin(elapsed * 2) * 0.12)
	relic.rotation.y += delta * 0.65
	glow.light_energy = 2.2 + sin(elapsed * 3.0) * 0.35
	halo.position.y = relic.position.y - 0.2
	halo.rotation = Vector3(0.2 * sin(elapsed), elapsed * 0.3, 0.25)

func interaction_text() -> String:
	return "Recueillir l’Éclat de l’Onde primordiale"

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return _unclaimed(get_node("/root/Inventory")) and visible and not flying and player != null and player.global_position.distance_to(global_position) < 3.0 and not get_node("/root/CabinTravel").busy

func interact() -> void:
	if not can_interact(): return
	var bag := get_node("/root/Inventory")
	if not bag.add_item("primordial_wave"):
		bag.ui.notify("Libérez une place dans l’équipement pour recueillir le fragment.")
		return
	bag.collected[CLAIMED] = true
	hide()
	bag.ui.notify("Onde primordiale éveillée ! Q : nova circulaire. Dans la Forêt Maléfique, elle brise les carapaces corrompues.")
