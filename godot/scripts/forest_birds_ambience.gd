extends Node3D
## ForestBirdsAmbience — Ambiance procédurale d'oiseaux dans la forêt
## Alterne aléatoirement entre les 5 variations de chants d'oiseaux,
## avec silences naturels, positionnement 3D aléatoire dans la canopée,
## et fondus progressifs (fade-in / fade-out).

const BIRD_PATHS := [
	"res://assets/audio/sfx/environment/birds/oiseaux_01_chorale_matinale.wav",
	"res://assets/audio/sfx/environment/birds/oiseaux_02_chants_printemps.wav",
	"res://assets/audio/sfx/environment/birds/oiseaux_03_gazouillis_clairiere.wav",
	"res://assets/audio/sfx/environment/birds/oiseaux_04_chants_lointains.wav",
	"res://assets/audio/sfx/environment/birds/oiseaux_05_ambiance_paisible.wav",
]

const TARGET_VOLUME_DB := -10.0 # Volume modéré et immersif
const FADE_IN_TIME := 2.5       # Fondu entrant doux en secondes
const FADE_OUT_TIME := 3.0      # Fondu sortant progressif en secondes
const MIN_PLAY_TIME := 9.0      # Durée minimale de chant
const MAX_PLAY_TIME := 15.0     # Durée maximale de chant
const MIN_SILENCE_TIME := 6.0   # Silence minimal entre les chants
const MAX_SILENCE_TIME := 18.0  # Silence maximal entre les chants

var audio_player: AudioStreamPlayer3D
var bird_streams: Array[AudioStream] = []
var player: Node3D = null
var is_active := true
var last_index := -1
var current_tween: Tween = null

func _ready() -> void:
	_init_audio()
	_start_ambience_loop()

func _init_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "BirdsAudio3D"
	audio_player.bus = "SFX"
	audio_player.unit_size = 7.0
	audio_player.max_distance = 45.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio_player.panning_strength = 1.0
	audio_player.volume_db = -80.0
	add_child(audio_player)
	
	for path in BIRD_PATHS:
		var s: AudioStream = null
		if ResourceLoader.exists(path):
			s = load(path)
		elif FileAccess.file_exists(path):
			s = AudioStreamWAV.load_from_file(path)
		if s:
			bird_streams.append(s)

func _start_ambience_loop() -> void:
	if bird_streams.is_empty():
		push_warning("[ForestBirdsAmbience] Aucun fichier de chant d'oiseau trouvé.")
		return
	call_deferred("_ambience_cycle")

func _ambience_cycle() -> void:
	# Petit silence initial avant le premier chant
	await get_tree().create_timer(randf_range(3.0, 7.0)).timeout
	
	while is_active and is_inside_tree():
		if not is_instance_valid(player):
			player = get_tree().get_first_node_in_group("player") as Node3D
			if not player:
				await get_tree().create_timer(1.0).timeout
				continue
		
		# 1. Sélection d'un chant aléatoire (sans répéter le même successivement)
		var next_idx := randi() % bird_streams.size()
		if bird_streams.size() > 1 and next_idx == last_index:
			next_idx = (next_idx + 1) % bird_streams.size()
		last_index = next_idx
		var stream: AudioStream = bird_streams[next_idx]
		
		# 2. Positionnement 3D aléatoire dans les arbres autour du joueur
		var angle := randf() * TAU
		var dist := randf_range(11.0, 22.0)
		var height := randf_range(4.5, 8.5)
		var offset := Vector3(cos(angle) * dist, height, sin(angle) * dist)
		audio_player.global_position = player.global_position + offset
		
		# 3. Lancement du chant avec Fade-in
		audio_player.stream = stream
		audio_player.volume_db = -80.0
		audio_player.play()
		
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		current_tween = create_tween()
		var target_vol := TARGET_VOLUME_DB + randf_range(-1.5, 1.5)
		current_tween.tween_property(audio_player, "volume_db", target_vol, FADE_IN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# 4. Durée de chant
		var play_duration := randf_range(MIN_PLAY_TIME, MAX_PLAY_TIME)
		await get_tree().create_timer(play_duration).timeout
		if not is_inside_tree() or not is_active:
			break
			
		# 5. Fade-out vers le silence
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		current_tween = create_tween()
		current_tween.tween_property(audio_player, "volume_db", -80.0, FADE_OUT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await current_tween.finished
		
		if audio_player.playing:
			audio_player.stop()
			
		# 6. Période de silence / calme aléatoire
		var silence_time := randf_range(MIN_SILENCE_TIME, MAX_SILENCE_TIME)
		await get_tree().create_timer(silence_time).timeout

func _exit_tree() -> void:
	is_active = false
	if current_tween and current_tween.is_valid():
		current_tween.kill()
