extends Node3D
## StreamAudioEmitter — Émetteur 3D suiveur pour le ruisseau et la rivière complète
## Couvre l'intégralité du cours d'eau traversant la carte de Z = -228m à Z = +88m.
## Projette l'émetteur AudioStreamPlayer3D sur le point d'eau le plus proche du joueur.
## Offre un panoramique stéréo gauche/droite dynamique et une atténuation naturelle.
## Bouclage 100% ininterrompu et garanti.

const STREAM_SFX_PATH := "res://assets/audio/sfx/environment/water/eau_ruisseau_cristallin.wav"
const BASE_VOLUME_DB := -3.5       # Volume sur les berges et abords
const IN_STREAM_VOLUME_DB := -7.5  # Volume légèrement atténué quand le joueur est directement dans l'eau
const IN_STREAM_RADIUS := 2.2      # Rayon de détection d'immersion dans le lit du cours d'eau
const UNIT_SIZE := 7.0             # Plein volume jusqu'à 7 mètres de la rive
const MAX_DISTANCE := 42.0         # Atténuation progressive perceptible jusqu'à 42 mètres

var audio_player: AudioStreamPlayer3D
var water_points: PackedVector3Array = PackedVector3Array()
var player: Node3D = null
var update_timer := 0.0

func _ready() -> void:
	_ensure_river_bus()
	_init_audio_player()
	call_deferred("_collect_river_points")

func _ensure_river_bus() -> void:
	var bus_idx := AudioServer.get_bus_index("River")
	if bus_idx == -1:
		var sfx_idx := AudioServer.get_bus_index("SFX")
		var send_bus := "SFX" if sfx_idx != -1 else "Master"
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "River")
		AudioServer.set_bus_send(bus_idx, send_bus)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.28
		reverb.damping = 0.6
		reverb.wet = 0.18
		reverb.dry = 0.95
		AudioServer.add_bus_effect(bus_idx, reverb)

func _init_audio_player() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "RiverAudio3D"
	audio_player.bus = "River"
	audio_player.volume_db = BASE_VOLUME_DB
	audio_player.unit_size = UNIT_SIZE
	audio_player.max_distance = MAX_DISTANCE
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio_player.panning_strength = 1.0
	
	var stream: AudioStream = null
	if ResourceLoader.exists(STREAM_SFX_PATH):
		stream = load(STREAM_SFX_PATH)
	elif FileAccess.file_exists(STREAM_SFX_PATH):
		stream = AudioStreamWAV.load_from_file(STREAM_SFX_PATH)
		
	if stream:
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			# Calcul précis du nombre total d'échantillons pour éviter que Godot s'arrête à 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
			
		audio_player.stream = stream
		audio_player.autoplay = true
		add_child(audio_player)
		
		# Sécurité supplémentaire pour relancer la lecture si un cycle venait à se terminer
		if not audio_player.finished.is_connected(_on_audio_finished):
			audio_player.finished.connect(_on_audio_finished)
			
		audio_player.play()
	else:
		add_child(audio_player)
		push_warning("[StreamAudioEmitter] Fichier audio introuvable : %s" % STREAM_SFX_PATH)

func _on_audio_finished() -> void:
	if is_instance_valid(audio_player) and not audio_player.playing:
		audio_player.play()

func _collect_river_points() -> void:
	var world := get_tree().current_scene
	if not world:
		world = self
		while world.get_parent() and world.get_parent() != get_tree().root:
			world = world.get_parent()
			
	var seen := {}
	water_points.clear()
	
	# Recherche de l'ensemble des maillages constituant le cours d'eau sur toute la carte
	var waters := world.find_children("*Water*", "MeshInstance3D", true, false)
	for w: MeshInstance3D in waters:
		# Exclure le fossé du château (ouest lointain) pour ne garder que le cours d'eau central
		if w.name == "Water_Moat":
			continue
			
		if w.mesh:
			for surface in range(w.mesh.get_surface_count()):
				var verts: PackedVector3Array = w.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for v in verts:
					var world_pt: Vector3 = w.global_transform * v
					# Échantillonnage à ~1.5m pour couvrir les 300+ mètres du fleuve de façon optimale
					var key := Vector3i(roundi(world_pt.x / 1.5), roundi(world_pt.y / 1.5), roundi(world_pt.z / 1.5))
					if not seen.has(key):
						seen[key] = true
						water_points.append(world_pt)
	
	# Si aucun maillage (scène de test unitaire isolée), tracé linéaire de secours
	if water_points.is_empty():
		for z in range(-230, 90, 2):
			var x_val := sin(float(z) * 0.08) * 2.5 + 0.5
			water_points.append(Vector3(x_val, 0.04, float(z)))
			
	print("[StreamAudioEmitter] Points du cours d'eau collectés : %d points (couvrant Z = %.1f à %.1f)" % [
		water_points.size(),
		water_points[0].z if not water_points.is_empty() else 0.0,
		water_points[-1].z if not water_points.is_empty() else 0.0
	])

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		if not player:
			return
			
	# Garantir que le lecteur ne s'arrête jamais
	if is_instance_valid(audio_player) and not audio_player.playing:
		audio_player.play()
			
	update_timer += delta
	if update_timer < 0.04: # ~25 Hz
		return
	var dt := update_timer
	update_timer = 0.0
	
	var player_pos := player.global_position
	var closest := _find_closest_point(player_pos)
	
	# Positionnement spatial instantané sur le point d'eau le plus proche
	audio_player.global_position = closest

	# Ajustement du volume : légèrement atténué quand on est directement dans le ruisseau
	var horiz_dist := Vector2(player_pos.x - closest.x, player_pos.z - closest.z).length()
	var target_vol := BASE_VOLUME_DB
	if horiz_dist < IN_STREAM_RADIUS:
		var factor := clampf(horiz_dist / IN_STREAM_RADIUS, 0.0, 1.0)
		target_vol = lerpf(IN_STREAM_VOLUME_DB, BASE_VOLUME_DB, factor)
		
	audio_player.volume_db = lerpf(audio_player.volume_db, target_vol, clampf(dt * 4.0, 0.0, 1.0))

func _find_closest_point(pos: Vector3) -> Vector3:
	if water_points.is_empty():
		return Vector3(0, 0.04, pos.z)
		
	var best_dist_sq := INF
	var best_pt := water_points[0]
	for pt in water_points:
		var d_sq := pos.distance_squared_to(pt)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_pt = pt
	return best_pt
