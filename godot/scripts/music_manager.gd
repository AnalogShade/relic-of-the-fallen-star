extends Node
## MusicManager — Gestionnaire de musique de fond (Autoload Singleton)
## Diffuse la musique principale en boucle continue et à volume modéré.

const DEFAULT_MUSIC_PATH := "res://assets/audio/music/main_music.mp3"
const DEFAULT_VOLUME_DB := -14.0
const CAVE_MUSIC_PATH := "res://assets/audio/music/cave_sous_la_pierre_noire.ogg"
const TRANSITION_SECONDS := 1.5

var player: AudioStreamPlayer
var music_stream: AudioStream
var cave_player: AudioStreamPlayer
var _in_cave := false
var _volume_db := DEFAULT_VOLUME_DB
var _music_stopped := false
var _transition: Tween
var _cave_mix := 0.0:
	set(value):
		_cave_mix = value
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
	cave_player = AudioStreamPlayer.new()
	cave_player.name = "CaveBGMPlayer"
	cave_player.bus = "Music"
	var cave_stream := load(CAVE_MUSIC_PATH) as AudioStreamOggVorbis
	if cave_stream:
		cave_stream.loop = true
		cave_player.stream = cave_stream
	add_child(cave_player)
	_apply_volumes()
	get_tree().node_added.connect(_on_location_node_changed)
	get_tree().node_removed.connect(_on_location_node_changed)
	_sync_location_music.call_deferred()

func _on_location_node_changed(node: Node) -> void:
	if node.is_in_group("cave_music"):
		_sync_location_music.call_deferred()

func _sync_location_music() -> void:
	var inside := not get_tree().get_nodes_in_group("cave_music").is_empty()
	if inside == _in_cave or not cave_player.stream:
		return
	_in_cave = inside
	if _transition and _transition.is_valid():
		_transition.kill()
	if inside and not _music_stopped and not cave_player.playing:
		cave_player.play()
	_transition = create_tween()
	_transition.tween_property(self, "_cave_mix", 1.0 if inside else 0.0, TRANSITION_SECONDS)
	if not inside:
		_transition.tween_callback(cave_player.stop)

func _apply_volumes() -> void:
	if player:
		player.volume_db = _volume_db + linear_to_db(maxf(1.0 - _cave_mix, 0.0001))
	if cave_player:
		cave_player.volume_db = _volume_db + linear_to_db(maxf(_cave_mix, 0.0001))

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

	if _in_cave and cave_player and not cave_player.playing:
		cave_player.play()

func stop_music() -> void:
	_music_stopped = true
	if cave_player:
		cave_player.stop()
	if player and player.playing:
		player.stop()

func pause_music() -> void:
	if player:
		player.stream_paused = true
	if cave_player:
		cave_player.stream_paused = true

func resume_music() -> void:
	if player:
		player.stream_paused = false
	if cave_player:
		cave_player.stream_paused = false

func set_volume_db(value: float) -> void:
	_volume_db = value
	_apply_volumes()

func get_volume_db() -> float:
	return _volume_db

func is_playing() -> bool:
	return player.playing if player else false
