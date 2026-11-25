extends Node
## MusicManager — Gestionnaire de musique de fond (Autoload Singleton)
## Diffuse le thème principal et les musiques de lieu en fondu.

const DEFAULT_MUSIC_PATH := "res://assets/audio/music/main_music.mp3"
const DEFAULT_VOLUME_DB := -14.0
const CAVE_MUSIC_PATH := "res://assets/audio/music/cave_sous_la_pierre_noire.ogg"
const MAELOR_MUSIC_PATH := "res://assets/audio/music/la_lumiere_des_fenetres.ogg"
const TRANSITION_SECONDS := 1.5

var player: AudioStreamPlayer
var music_stream: AudioStream
var cave_player: AudioStreamPlayer
var maelor_player: AudioStreamPlayer
var _in_cave := false
var _in_maelor := false
var _volume_db := DEFAULT_VOLUME_DB
var _music_stopped := false
var _transition: Tween
var _cave_mix := 0.0:
	set(value):
		_cave_mix = value
		_apply_volumes()
var _maelor_mix := 0.0:
	set(value):
		_maelor_mix = value
		_apply_volumes()

func _ready() -> void:
	# PROCESS_MODE_ALWAYS assure que la musique continue de jouer
	# même si le reste du jeu est mis en pause (ex: inventaire ou menu).
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = AudioStreamPlayer.new()
	player.name = "BGMPlayer"
	player.bus = "Music"
	player.volume_db = DEFAULT_VOLUME_DB
	add_child(player)

	load_and_play(DEFAULT_MUSIC_PATH)
	cave_player = _create_location_player("CaveBGMPlayer", CAVE_MUSIC_PATH)
	maelor_player = _create_location_player("MaelorBGMPlayer", MAELOR_MUSIC_PATH)
	_apply_volumes()
	get_tree().node_added.connect(_on_location_node_changed)
	get_tree().node_removed.connect(_on_location_node_changed)
	_sync_location_music.call_deferred()

func _create_location_player(player_name: String, path: String) -> AudioStreamPlayer:
	var location_player := AudioStreamPlayer.new()
	location_player.name = player_name
	location_player.bus = "Music"
	var stream := load(path) as AudioStreamOggVorbis
	if stream:
		stream.loop = true
		location_player.stream = stream
	add_child(location_player)
	return location_player

func _on_location_node_changed(node: Node) -> void:
	if node.is_in_group("cave_music") or node.is_in_group("maelor_music"):
		_sync_location_music.call_deferred()

func _sync_location_music() -> void:
	var in_maelor := maelor_player.stream != null and get_tree().get_first_node_in_group("maelor_music") != null
	var in_cave := not in_maelor and cave_player.stream != null and get_tree().get_first_node_in_group("cave_music") != null
	if in_cave == _in_cave and in_maelor == _in_maelor:
		return
	_in_cave = in_cave
	_in_maelor = in_maelor
	if _transition and _transition.is_valid():
		_transition.kill()
	if not _music_stopped:
		_play_active_location_music()
	_transition = create_tween().set_parallel()
	_transition.tween_property(self, "_cave_mix", 1.0 if _in_cave else 0.0, TRANSITION_SECONDS)
	_transition.tween_property(self, "_maelor_mix", 1.0 if _in_maelor else 0.0, TRANSITION_SECONDS)
	_transition.chain().tween_callback(_stop_inactive_location_music)

func _play_active_location_music() -> void:
	if _in_cave and cave_player and not cave_player.playing:
		cave_player.play()
	if _in_maelor and maelor_player and not maelor_player.playing:
		maelor_player.play()

func _stop_inactive_location_music() -> void:
	if not _in_cave:
		cave_player.stop()
	if not _in_maelor:
		maelor_player.stop()

func _apply_volumes() -> void:
	if player:
		player.volume_db = _volume_db + linear_to_db(maxf(1.0 - _cave_mix - _maelor_mix, 0.0001))
	if cave_player:
		cave_player.volume_db = _volume_db + linear_to_db(maxf(_cave_mix, 0.0001))
	if maelor_player:
		maelor_player.volume_db = _volume_db + linear_to_db(maxf(_maelor_mix, 0.0001))

func load_and_play(path: String) -> void:
	if ResourceLoader.exists(path):
		music_stream = load(path)
		if music_stream is AudioStreamMP3:
			music_stream.loop = true
		player.stream = music_stream

		# Sécurité supplémentaire pour garantir le bouclage en continu
		if not player.finished.is_connected(_on_music_finished):
			player.finished.connect(_on_music_finished)

		player.play()
	else:
		push_warning("[MusicManager] Fichier musical introuvable : %s" % path)

func _on_music_finished() -> void:
	if player and player.stream:
		player.play()

func play_music() -> void:
	_music_stopped = false
	if player and not player.playing:
		player.play()
	_play_active_location_music()

func stop_music() -> void:
	_music_stopped = true
	for music_player in [player, cave_player, maelor_player]:
		if music_player:
			music_player.stop()

func pause_music() -> void:
	for music_player in [player, cave_player, maelor_player]:
		if music_player:
			music_player.stream_paused = true

func resume_music() -> void:
	for music_player in [player, cave_player, maelor_player]:
		if music_player:
			music_player.stream_paused = false

func set_volume_db(value: float) -> void:
	_volume_db = value
	_apply_volumes()

func get_volume_db() -> float:
	return _volume_db

func is_playing() -> bool:
	return player.playing if player else false
