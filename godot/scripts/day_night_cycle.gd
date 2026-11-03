@tool
class_name DayNightCycle
extends Node3D

## Gestionnaire de cycle Jour / Nuit dynamique avec transition douce.
## Contrôleur unique du soleil, de la lune, du ciel et de l'ambiance.
## OpenWorld active son ciel animé; les autres scènes gardent leur profil original.

signal time_changed(current_hour: float)
signal phase_changed(new_phase: String)

@export_group("Cycle Settings")
## Active le cycle asymétrique (journée étirée et nuit dynamique courte).
@export var asymmetric_cycle: bool = true

## Durée réelle de la phase diurne (aube, grand jour et crépuscule : 5h00 -> 21h00) en minutes.
## Par défaut 18.0 min (3x plus long que la nuit d'origine pour explorer sereinement).
@export_range(1.0, 60.0, 0.5) var day_duration_minutes: float = 18.0

## Durée réelle de la phase nocturne (nuit profonde : 21h00 -> 5h00) en minutes.
## Par défaut 3.0 min (garde la nuit courte et dynamique, sans longueur excessive).
@export_range(0.5, 30.0, 0.5) var night_duration_minutes: float = 3.0

## Durée totale d'un cycle complet en minutes réelles (utilisé uniquement si asymmetric_cycle = false).
@export_range(0.5, 60.0, 0.5) var cycle_duration_minutes: float = 10.0

## Heure actuelle de la journée (0.0 à 24.0).
## 12.0 = Midi (Plein jour original), 0.0 / 24.0 = Minuit (Pleine nuit lunaire).
@export_range(0.0, 24.0, 0.05) var time_of_day: float = 12.0:
	set(value):
		time_of_day = fposmod(value, 24.0)
		if is_node_ready():
			_update_lighting(time_of_day)
		time_changed.emit(time_of_day)

## Met en pause l'écoulement naturel du temps.
@export var is_paused: bool = false

## Multiplicateur d'accélération du temps (pratique pour les tests).
@export_range(0.1, 50.0, 0.5) var time_speed_multiplier: float = 1.0

@export_group("Outdoor Sky")
## Enabled by OpenWorld only; standalone forest scenes retain their original sky.
@export var use_outdoor_sky: bool = false
@export_range(0.0, 3.0, 0.05) var cloud_speed: float = 1.0

@export_group("Night Lighting (Moon)")
## Teinte de la lumière de la lune (bleu argenté doux).
@export var moon_light_color: Color = Color(0.62, 0.76, 0.98, 1.0)
## Intensité maximale de la lune au zénith nocturne.
@export_range(0.0, 1.0, 0.01) var moon_max_energy: float = 0.24
## Teinte ambiante nocturne (assure une excellente lisibilité sans noir complet).
@export var night_ambient_color: Color = Color(0.26, 0.32, 0.46, 1.0)
## Énergie ambiante nocturne.
@export_range(0.05, 1.0, 0.01) var night_ambient_energy: float = 0.30
## Couleur de la brume nocturne féerique.
@export var night_fog_color: Color = Color(0.08, 0.12, 0.22, 1.0)
## Énergie de la brume nocturne.
@export_range(0.1, 1.5, 0.05) var night_fog_energy: float = 0.50
## Densité de la brume nocturne.
@export_range(0.001, 0.02, 0.0005) var night_fog_density: float = 0.0040

@export_group("Debug Hotkeys")
## Active les raccourcis de debug en jeu (F6: +3h, F7: pause, F8: x10 vitesse).
@export var enable_debug_hotkeys: bool = true

@export_group("Node References")
@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var soft_fill: DirectionalLight3D
@export var world_environment: WorldEnvironment

# --- Paramètres du jour capturés depuis la scène ---
var _base_sun_color: Color = Color(1.0, 0.94, 0.82)
var _base_sun_energy: float = 0.45
var _base_sun_basis: Basis
var _base_moon_basis: Basis
var _orbit_axis: Vector3 = Vector3(0.529919, 0.0, -0.848048).normalized()

var _base_soft_fill_color: Color = Color(0.80, 0.88, 1.0)
var _base_soft_fill_energy: float = 0.18

var _base_ambient_color: Color = Color(0.76, 0.80, 0.76)
var _base_ambient_energy: float = 0.45

var _base_fog_color: Color = Color(0.51, 0.61, 0.52)
var _base_fog_energy: float = 0.65
var _base_fog_density: float = 0.0035

var _base_sky_top: Color = Color(0.16, 0.29, 0.35)
var _base_sky_horizon: Color = Color(0.63, 0.67, 0.49)
var _base_ground_bottom: Color = Color(0.12, 0.17, 0.12)
var _base_ground_horizon: Color = Color(0.45, 0.50, 0.35)

var _sky_mat: ProceduralSkyMaterial
var _outdoor_sky_mat: ShaderMaterial
var _cloud_seconds: float = 0.0
var _sky_refresh_elapsed: float = 0.0
var _defer_sky_update: bool = false
var _current_phase: String = "Day"
var _initialized: bool = false


func _ready() -> void:
	_resolve_references()
	_capture_baseline()
	_update_lighting(time_of_day)
	_initialized = true


func _resolve_references() -> void:
	var parent := get_parent()
	if sun == null and parent != null:
		sun = parent.get_node_or_null("Sun") as DirectionalLight3D
	if soft_fill == null and parent != null:
		soft_fill = parent.get_node_or_null("SoftFill") as DirectionalLight3D
	if world_environment == null and parent != null:
		world_environment = parent.get_node_or_null("WorldEnvironment") as WorldEnvironment

	# Gestion ou création automatique de la Lune si elle n'existe pas encore
	if moon == null:
		if parent != null:
			moon = parent.get_node_or_null("Moon") as DirectionalLight3D
		if moon == null:
			moon = get_node_or_null("Moon") as DirectionalLight3D
		if moon == null and not Engine.is_editor_hint():
			moon = DirectionalLight3D.new()
			moon.name = "Moon"
			moon.light_color = moon_light_color
			moon.light_energy = 0.0
			moon.light_specular = 0.20
			moon.shadow_enabled = true
			moon.shadow_blur = 2.0
			moon.directional_shadow_max_distance = 85.0
			if parent != null:
				parent.call_deferred("add_child", moon)
			else:
				add_child(moon)


func _capture_baseline() -> void:
	if sun != null:
		_base_sun_color = sun.light_color
		_base_sun_energy = sun.light_energy
		_base_sun_basis = sun.transform.basis
		# Calcul de l'axe orbital et de la base lunaire
		var noon_dir := -_base_sun_basis.z
		_orbit_axis = Vector3(-noon_dir.z, 0.0, noon_dir.x).normalized()
		# La lune à minuit fait face dans la direction opposée en azimut
		_base_moon_basis = _base_sun_basis.rotated(Vector3.UP, PI)
	else:
		_base_sun_basis = Basis.from_euler(Vector3(deg_to_rad(-48.0), deg_to_rad(-32.0), 0.0))
		_base_moon_basis = _base_sun_basis.rotated(Vector3.UP, PI)

	if soft_fill != null:
		_base_soft_fill_color = soft_fill.light_color
		_base_soft_fill_energy = soft_fill.light_energy

	if world_environment != null and world_environment.environment != null:
		# Duplique l'environnement pour isoler les modifications d'exécution
		if use_outdoor_sky or not Engine.is_editor_hint():
			world_environment.environment = world_environment.environment.duplicate()
			if world_environment.environment.sky != null:
				world_environment.environment.sky = world_environment.environment.sky.duplicate()
				if world_environment.environment.sky.sky_material != null:
					world_environment.environment.sky.sky_material = world_environment.environment.sky.sky_material.duplicate()

		var env := world_environment.environment
		if use_outdoor_sky:
			_configure_outdoor_sky(env)
		_base_ambient_color = env.ambient_light_color
		_base_ambient_energy = env.ambient_light_energy
		_base_fog_color = env.fog_light_color
		_base_fog_energy = env.fog_light_energy
		_base_fog_density = env.fog_density

		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			_sky_mat = env.sky.sky_material as ProceduralSkyMaterial
			_base_sky_top = _sky_mat.sky_top_color
			_base_sky_horizon = _sky_mat.sky_horizon_color
			_base_ground_bottom = _sky_mat.ground_bottom_color
			_base_ground_horizon = _sky_mat.ground_horizon_color


func _configure_outdoor_sky(env: Environment) -> void:
	# Replace the sky on the ONE existing environment, never add a second rig.
	var noise := FastNoiseLite.new()
	noise.seed = 7319
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 5
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	_outdoor_sky_mat = ShaderMaterial.new()
	_outdoor_sky_mat.shader = preload("res://shaders/outdoor_sky.gdshader")
	_outdoor_sky_mat.set_shader_parameter("cloud_noise", texture)
	var outdoor_sky := Sky.new()
	outdoor_sky.sky_material = _outdoor_sky_mat
	outdoor_sky.radiance_size = Sky.RADIANCE_SIZE_256
	outdoor_sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = outdoor_sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_color = Color(0.68, 0.76, 0.88)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_sky_affect = 0.0 # Atmosphere is drawn by the sky itself.
	_base_sun_color = Color(1.0, 0.94, 0.84)
	_base_sun_energy = 0.85
	if soft_fill != null:
		# Ambient sky replaces the artificial directional fill completely.
		soft_fill.light_energy = 0.0
		soft_fill.visible = false
		soft_fill.shadow_enabled = false
		soft_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY


func _outdoor_keyframe(type: String) -> Dictionary:
	var data := _get_data_for_type(type)
	data["soft_fill_energy"] = 0.0
	match type:
		"day":
			data["sky_top"] = Color(0.23, 0.46, 0.76)
			data["sky_horizon"] = Color(0.69, 0.79, 0.88)
			data["ground_bottom"] = Color(0.19, 0.23, 0.20)
			data["fog_color"] = Color(0.61, 0.70, 0.76)
			data["fog_density"] = 0.0015
		"dawn":
			data["sky_top"] = Color(0.16, 0.28, 0.48)
			data["sky_horizon"] = Color(0.88, 0.66, 0.48)
			data["fog_color"] = Color(0.58, 0.57, 0.61)
			data["fog_density"] = 0.0019
		"dusk":
			data["sky_top"] = Color(0.12, 0.20, 0.38)
			data["sky_horizon"] = Color(0.94, 0.53, 0.32)
			data["fog_density"] = 0.0018
		"night":
			data["sky_top"] = Color(0.012, 0.025, 0.065)
			data["sky_horizon"] = Color(0.075, 0.115, 0.19)
			data["fog_density"] = 0.0018
	return data


func _update_outdoor_sky(k: Dictionary) -> void:
	if _outdoor_sky_mat == null:
		return
	var sun_height := sun.transform.basis.z.y if sun != null else 0.0
	var day_weight := smoothstep(-0.12, 0.30, sun_height)
	var stars := 1.0 - smoothstep(-0.30, -0.04, sun_height)
	var twilight := 1.0 - smoothstep(0.02, 0.40, absf(sun_height))
	var cloud_light := Color(0.96, 0.97, 1.0).lerp(Color(1.0, 0.68, 0.43), twilight * 0.75)
	# High clouds remain sunlit while the sun is just below the ground horizon.
	var cloud_day := smoothstep(-0.22, 0.16, sun_height)
	cloud_light = Color(0.095, 0.135, 0.22).lerp(cloud_light, cloud_day)
	var cloud_shadow := Color(0.045, 0.065, 0.12).lerp(Color(0.48, 0.56, 0.68), cloud_day)
	_outdoor_sky_mat.set_shader_parameter("zenith_color", k["sky_top"])
	_outdoor_sky_mat.set_shader_parameter("horizon_color", k["sky_horizon"])
	_outdoor_sky_mat.set_shader_parameter("ground_color", k["ground_bottom"])
	_outdoor_sky_mat.set_shader_parameter("sun_color", k["sun_color"])
	_outdoor_sky_mat.set_shader_parameter("cloud_light_color", cloud_light)
	_outdoor_sky_mat.set_shader_parameter("cloud_shadow_color", cloud_shadow)
	_outdoor_sky_mat.set_shader_parameter("daylight", day_weight)
	_outdoor_sky_mat.set_shader_parameter("stars_visibility", stars)
	_outdoor_sky_mat.set_shader_parameter("cloud_offset", Vector2(0.005, 0.0018) * _cloud_seconds)
	if sun != null:
		_outdoor_sky_mat.set_shader_parameter("sun_direction", sun.transform.basis.z.normalized())
	if moon != null:
		_outdoor_sky_mat.set_shader_parameter("moon_direction", moon.transform.basis.z.normalized())
	world_environment.environment.ambient_light_sky_contribution = lerpf(0.38, 0.65, day_weight)


## Retourne la vitesse instantanée d'écoulement du temps en heures virtuelles par seconde réelle.
## Si asymmetric_cycle est activé, applique un écoulement ralenti le jour et rapide la nuit,
## avec transitions douces à l'aube et au crépuscule pour préserver l'inertie visuelle.
func get_effective_hours_per_second(hour: float = -1.0) -> float:
	if hour < 0.0:
		hour = time_of_day

	if not asymmetric_cycle:
		return 24.0 / maxf(cycle_duration_minutes * 60.0, 1.0)

	# Plages horaires :
	# Journée (aube, grand jour, crépuscule) : 5h00 -> 21h00 = 16h virtuelles
	# Nuit profonde : 21h00 -> 5h00 = 8h virtuelles
	var day_speed := 16.0 / maxf(day_duration_minutes * 60.0, 1.0)
	var night_speed := 8.0 / maxf(night_duration_minutes * 60.0, 1.0)

	# Transitions douces pour éviter tout saut brutal de vitesse orbitale du soleil / lune
	# Aube : transition progressive de 4.5h à 5.5h (centrée sur 5.0h)
	# Crépuscule / tombée de la nuit : transition de 20.5h à 21.5h (centrée sur 21.0h)
	if hour >= 5.5 and hour <= 20.5:
		return day_speed
	elif hour >= 4.5 and hour < 5.5:
		var t := smoothstep(4.5, 5.5, hour)
		return lerpf(night_speed, day_speed, t)
	elif hour > 20.5 and hour <= 21.5:
		var t := smoothstep(20.5, 21.5, hour)
		return lerpf(day_speed, night_speed, t)
	else:
		return night_speed


## Retourne la durée totale estimée d'un cycle complet (24h virtuelles) en minutes réelles.
func get_total_cycle_minutes() -> float:
	if asymmetric_cycle:
		return day_duration_minutes + night_duration_minutes
	return cycle_duration_minutes


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_paused:
		if use_outdoor_sky:
			_cloud_seconds += delta * cloud_speed
			_sky_refresh_elapsed += delta
			_defer_sky_update = _sky_refresh_elapsed < 0.1
		var hours_per_second := get_effective_hours_per_second(time_of_day)
		time_of_day = fposmod(time_of_day + hours_per_second * delta * time_speed_multiplier, 24.0)
		if not _defer_sky_update:
			_sky_refresh_elapsed = 0.0
		_defer_sky_update = false


func _unhandled_input(event: InputEvent) -> void:
	if not enable_debug_hotkeys or Engine.is_editor_hint():
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_F6:
				# Saut horaire (+3 heures)
				var step := 1.0 if event.shift_pressed else 3.0
				time_of_day = fposmod(time_of_day + step, 24.0)
				print("[DayNightCycle] Heure avancée: %s (phase: %s)" % [_get_formatted_time(), _current_phase])
			KEY_F7:
				# Pause / Reprise
				is_paused = not is_paused
				print("[DayNightCycle] Pause: %s" % str(is_paused))
			KEY_F8:
				# Bascule avance rapide (1x <-> 10x)
				time_speed_multiplier = 10.0 if is_equal_approx(time_speed_multiplier, 1.0) else 1.0
				print("[DayNightCycle] Multiplicateur de vitesse: %.1fx" % time_speed_multiplier)


## Formate l'heure courante en HH:MM
func _get_formatted_time() -> String:
	var hours := int(time_of_day)
	var minutes := int(fposmod(time_of_day * 60.0, 60.0))
	return "%02d:%02d" % [hours, minutes]


## Met à jour les lumières, ombres, ciel et brouillard pour une heure donnée
func _update_lighting(hour: float) -> void:
	# 1. Mise à jour de la rotation orbitale du Soleil et de la Lune
	var sun_angle := (hour - 12.0) / 24.0 * TAU
	var moon_angle := (hour - 0.0) / 24.0 * TAU

	if sun != null:
		sun.transform.basis = _base_sun_basis.rotated(_orbit_axis, sun_angle)
	if moon != null:
		moon.transform.basis = _base_moon_basis.rotated(_orbit_axis, moon_angle)
	if use_outdoor_sky:
		# Preserve the noon direction but align sunrise/sunset with 06:00/18:00.
		var noon := _base_sun_basis.z.normalized()
		var east := Vector3(noon.z, 0.0, -noon.x).normalized()
		var orbit := (hour - 6.0) / 24.0 * TAU
		var direction := (east * cos(orbit) + noon * sin(orbit)).normalized()
		if sun != null:
			sun.transform.basis = Basis.looking_at(-direction, Vector3.UP)
		if moon != null:
			moon.transform.basis = Basis.looking_at(direction, Vector3.UP)

	# 2. Calcul des paramètres interpolés
	var k := _evaluate_keyframes(hour)

	# Détection de phase pour signal / information
	var phase := "Day"
	if hour < 4.5 or hour >= 21.5:
		phase = "Night"
	elif hour >= 4.5 and hour < 7.5:
		phase = "Dawn"
	elif hour >= 7.5 and hour < 17.0:
		phase = "Day"
	else:
		phase = "Dusk"

	if phase != _current_phase:
		_current_phase = phase
		phase_changed.emit(_current_phase)

	# 3. Application au Soleil
	if sun != null:
		sun.light_color = k["sun_color"]
		sun.light_energy = k["sun_energy"]
		if use_outdoor_sky:
			sun.light_energy *= smoothstep(0.0, 0.12, sun.transform.basis.z.y)
		var sun_above := sun.transform.basis.z.y > -0.05
		sun.visible = (sun.light_energy > 0.001) and sun_above
		sun.shadow_enabled = sun.visible

	# 4. Application à la Lune
	if moon != null:
		moon.light_color = k["moon_color"]
		moon.light_energy = k["moon_energy"]
		if use_outdoor_sky:
			moon.light_energy *= smoothstep(0.0, 0.12, moon.transform.basis.z.y)
		var moon_above := moon.transform.basis.z.y > -0.05
		moon.visible = (moon.light_energy > 0.001) and moon_above
		moon.shadow_enabled = moon.visible

	# 5. Application au SoftFill
	if soft_fill != null:
		soft_fill.light_color = k["soft_fill_color"]
		soft_fill.light_energy = k["soft_fill_energy"]
		soft_fill.visible = k["soft_fill_energy"] > 0.001

	# 6. Application au WorldEnvironment (Ambiance, Brouillard, Ciel)
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.ambient_light_color = k["ambient_color"]
		env.ambient_light_energy = k["ambient_energy"]
		env.fog_light_color = k["fog_color"]
		env.fog_light_energy = k["fog_energy"]
		env.fog_density = k["fog_density"]

		if _sky_mat != null:
			_sky_mat.sky_top_color = k["sky_top"]
			_sky_mat.sky_horizon_color = k["sky_horizon"]
			_sky_mat.ground_bottom_color = k["ground_bottom"]
			_sky_mat.ground_horizon_color = k["ground_horizon"]
		if use_outdoor_sky and not _defer_sky_update:
			_update_outdoor_sky(k)


## Évalue les paramètres visuels clés selon l'heure
func _evaluate_keyframes(hour: float) -> Dictionary:
	# Clés temporelles :
	#  0.0  : Minuit (Plein clair de lune)
	#  4.5  : Fin de nuit
	#  6.0  : Aube / Lever du soleil
	#  8.0  : Matinée -> 100% éclairage de jour baseline
	# 16.0  : Fin d'après-midi -> début transition crépuscule
	# 18.5  : Crépuscule / Coucher de soleil
	# 21.0  : Début de nuit
	# 24.0  : Minuit
	var kf := [
		{"h": 0.0,  "type": "night"},
		{"h": 4.5,  "type": "night"},
		{"h": 6.0,  "type": "dawn"},
		{"h": 8.0,  "type": "day"},
		{"h": 16.0, "type": "day"},
		{"h": 18.5, "type": "dusk"},
		{"h": 21.0, "type": "night"},
		{"h": 24.0, "type": "night"}
	]

	# Trouver le segment actif
	var i0 := 0
	var i1 := 1
	for i in range(kf.size() - 1):
		if hour >= kf[i]["h"] and hour <= kf[i + 1]["h"]:
			i0 = i
			i1 = i + 1
			break

	var h0: float = kf[i0]["h"]
	var h1: float = kf[i1]["h"]
	var raw_t := 0.0 if is_equal_approx(h0, h1) else (hour - h0) / (h1 - h0)
	var t := smoothstep(0.0, 1.0, raw_t)

	var d0: Dictionary = _get_data_for_type(kf[i0]["type"])
	var d1: Dictionary = _get_data_for_type(kf[i1]["type"])
	if use_outdoor_sky:
		d0 = _outdoor_keyframe(kf[i0]["type"])
		d1 = _outdoor_keyframe(kf[i1]["type"])

	var result := {}
	for key in d0.keys():
		var val0 = d0[key]
		var val1 = d1[key]
		if val0 is Color:
			result[key] = (val0 as Color).lerp(val1 as Color, t)
		elif val0 is float:
			result[key] = lerpf(val0, val1, t)

	return result


func _get_data_for_type(type: String) -> Dictionary:
	match type:
		"day":
			return {
				"sun_color": _base_sun_color,
				"sun_energy": _base_sun_energy,
				"moon_color": moon_light_color,
				"moon_energy": 0.0,
				"soft_fill_color": _base_soft_fill_color,
				"soft_fill_energy": _base_soft_fill_energy,
				"ambient_color": _base_ambient_color,
				"ambient_energy": _base_ambient_energy,
				"fog_color": _base_fog_color,
				"fog_energy": _base_fog_energy,
				"fog_density": _base_fog_density,
				"sky_top": _base_sky_top,
				"sky_horizon": _base_sky_horizon,
				"ground_bottom": _base_ground_bottom,
				"ground_horizon": _base_ground_horizon
			}
		"dusk":
			return {
				"sun_color": Color(1.0, 0.62, 0.32),
				"sun_energy": _base_sun_energy * 0.40,
				"moon_color": moon_light_color,
				"moon_energy": moon_max_energy * 0.25,
				"soft_fill_color": Color(0.65, 0.45, 0.55),
				"soft_fill_energy": 0.12,
				"ambient_color": Color(0.58, 0.44, 0.46),
				"ambient_energy": 0.35,
				"fog_color": Color(0.52, 0.38, 0.38),
				"fog_energy": 0.58,
				"fog_density": 0.0038,
				"sky_top": Color(0.10, 0.14, 0.28),
				"sky_horizon": Color(0.88, 0.46, 0.26),
				"ground_bottom": Color(0.08, 0.10, 0.10),
				"ground_horizon": Color(0.28, 0.20, 0.18)
			}
		"night":
			return {
				"sun_color": _base_sun_color,
				"sun_energy": 0.0,
				"moon_color": moon_light_color,
				"moon_energy": moon_max_energy,
				"soft_fill_color": Color(0.20, 0.28, 0.45),
				"soft_fill_energy": 0.08,
				"ambient_color": night_ambient_color,
				"ambient_energy": night_ambient_energy,
				"fog_color": night_fog_color,
				"fog_energy": night_fog_energy,
				"fog_density": night_fog_density,
				"sky_top": Color(0.025, 0.04, 0.10),
				"sky_horizon": Color(0.09, 0.14, 0.25),
				"ground_bottom": Color(0.02, 0.03, 0.05),
				"ground_horizon": Color(0.05, 0.08, 0.14)
			}
		"dawn":
			return {
				"sun_color": Color(1.0, 0.80, 0.62),
				"sun_energy": _base_sun_energy * 0.45,
				"moon_color": moon_light_color,
				"moon_energy": moon_max_energy * 0.20,
				"soft_fill_color": Color(0.55, 0.65, 0.82),
				"soft_fill_energy": 0.14,
				"ambient_color": Color(0.64, 0.66, 0.72),
				"ambient_energy": 0.38,
				"fog_color": Color(0.46, 0.50, 0.56),
				"fog_energy": 0.60,
				"fog_density": 0.0036,
				"sky_top": Color(0.12, 0.20, 0.32),
				"sky_horizon": Color(0.76, 0.60, 0.52),
				"ground_bottom": Color(0.10, 0.14, 0.11),
				"ground_horizon": Color(0.36, 0.38, 0.28)
			}
		_:
			return {}
