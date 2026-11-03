extends Control
## Affiche discrètement l'emplacement actuel pendant quelques secondes à l'arrivée
## dans une zone ou au démarrage, sans fond noir obstruant, puis s'estompe doucement.

@export var display_duration: float = 4.5
@export var fade_duration: float = 1.2

@onready var text_label: Label = get_node_or_null("Text")

var _fade_tween: Tween

func _ready() -> void:
	# Initialiser le nom de la zone si SaveManager est disponible
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_current_location_name") and text_label:
		var loc: String = save_mgr.get_current_location_name()
		if not loc.is_empty():
			text_label.text = "%s\nRelic of the fallen star" % loc.to_upper()
	
	show_banner()

## Affiche la bannière de lieu pendant quelques secondes puis l'estompe doucement
func show_banner(zone_name: String = "", subtitle: String = "Relic of the fallen star") -> void:
	if not zone_name.is_empty() and text_label:
		text_label.text = "%s\n%s" % [zone_name.to_upper(), subtitle]
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	modulate.a = 1.0
	show()
	
	_fade_tween = create_tween()
	_fade_tween.tween_interval(display_duration)
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	_fade_tween.tween_callback(hide)
