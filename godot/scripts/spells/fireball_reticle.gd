extends Control

var perspective_size := 1.0
var launch_screen := Vector2.ZERO
var impact_screen := Vector2.ZERO
var blocked := false
var distance_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label = Label.new()
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label.add_theme_font_size_override("font_size", 15)
	distance_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	distance_label.add_theme_constant_override("shadow_offset_x", 1)
	distance_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(distance_label)

func set_world_target(camera: Camera3D, release: Vector3, target: Vector3, is_blocked: bool) -> void:
	var depth := maxf(0.1, -camera.to_local(target).z)
	# A projected world-space ring shrinks with depth; bounds keep it legible.
	perspective_size = clampf(sqrt(14.0 / depth), 0.45, 1.6)
	launch_screen = camera.unproject_position(release) - position
	impact_screen = camera.unproject_position(target) - position
	blocked = is_blocked
	distance_label.text = ("Obstacle · " if blocked else "") + "%d m" % roundi(release.distance_to(target))
	distance_label.position = Vector2(22, 24) * perspective_size
	queue_redraw()

func _draw() -> void:
	var glow := Color(1.0, 0.35, 0.06, 0.3)
	var fire := Color(1.0, 0.8, 0.35, 0.95)
	if blocked:
		fire = Color(1.0, 0.35, 0.15)
	# Project the direction from the hand to the real impact point.
	var path := impact_screen - launch_screen
	if path.length() > 35.0:
		var dir := path.normalized()
		var end := impact_screen - dir * 18.0 * perspective_size
		draw_dashed_line(launch_screen, end, Color(1.0, 0.68, 0.3, 0.45), 1.5, 7.0, true)
		draw_line(end, end - dir.rotated(0.45) * 10.0, fire, 1.5, true)
		draw_line(end, end - dir.rotated(-0.45) * 10.0, fire, 1.5, true)
	if impact_screen.length() > 12.0:
		draw_arc(impact_screen, 6.0, 0.0, TAU, 24, fire, 2.0, true)
	var r := perspective_size
	draw_arc(Vector2.ZERO, 15.0 * r, 0.0, TAU, 48, glow, 6.0, true)
	draw_arc(Vector2.ZERO, 13.0 * r, 0.0, TAU, 48, fire, 1.5, true)
	for axis in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(axis * 18.0 * r, axis * 25.0 * r, Color.BLACK, 4.0, true)
		draw_line(axis * 18.0 * r, axis * 25.0 * r, fire, 2.0, true)
	draw_circle(Vector2.ZERO, 2.5, fire)
