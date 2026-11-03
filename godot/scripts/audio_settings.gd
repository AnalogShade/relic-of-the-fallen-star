extends Node
## AudioSettings — Gestionnaire centralisé des paramètres audio (Autoload Singleton)
## Contrôle le volume et l'activation des bus Musique et SFX, avec sauvegarde persistante.

signal settings_changed

const CONFIG_PATH := "user://audio_settings.cfg"
const SECTION := "audio"

var music_enabled: bool = true
var music_volume: float = 0.8  # Valeur linéaire 0.0 à 1.0
var sfx_enabled: bool = true
var sfx_volume: float = 0.8    # Valeur linéaire 0.0 à 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	load_settings()
	apply_all()

func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func apply_all() -> void:
	_apply_music()
	_apply_sfx()

func _apply_music() -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, not music_enabled)
		var db := linear_to_db(music_volume) if music_volume > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_sfx() -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, not sfx_enabled)
		var db := linear_to_db(sfx_volume) if sfx_volume > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func set_music_enabled(value: bool) -> void:
	if music_enabled == value:
		return
	music_enabled = value
	_apply_music()
	save_settings()
	settings_changed.emit()

func set_music_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, clamped):
		return
	music_volume = clamped
	_apply_music()
	save_settings()
	settings_changed.emit()

func set_sfx_enabled(value: bool) -> void:
	if sfx_enabled == value:
		return
	sfx_enabled = value
	_apply_sfx()
	save_settings()
	settings_changed.emit()

func set_sfx_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, clamped):
		return
	sfx_volume = clamped
	_apply_sfx()
	save_settings()
	settings_changed.emit()

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		music_enabled = config.get_value(SECTION, "music_enabled", true)
		music_volume = clampf(float(config.get_value(SECTION, "music_volume", 0.8)), 0.0, 1.0)
		sfx_enabled = config.get_value(SECTION, "sfx_enabled", true)
		sfx_volume = clampf(float(config.get_value(SECTION, "sfx_volume", 0.8)), 0.0, 1.0)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_enabled", music_enabled)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.save(CONFIG_PATH)
