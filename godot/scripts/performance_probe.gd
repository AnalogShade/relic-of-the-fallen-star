extends Node
## Passive diagnostics: query /root/PerformanceProbe properties through MCP.
## Frame intervals use wall time so Engine's delta clamping cannot hide stalls.

var latest: Dictionary = {}
var history: Array[Dictionary] = []
var log_path := "user://performance_latest.jsonl"
var _frames: Array[float] = []
var _previous_usec: int = 0
var _window_start_usec: int = 0
var _log: FileAccess
var _samples_since_flush := 0


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_usec = Time.get_ticks_usec()
	_window_start_usec = _previous_usec
	_log = FileAccess.open(log_path, FileAccess.WRITE)
	log_path = ProjectSettings.globalize_path(log_path)
	if _log == null:
		push_warning("PerformanceProbe: cannot open diagnostic log; live samples remain available.")


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_frames.append(float(now - _previous_usec) / 1000.0)
	_previous_usec = now
	var elapsed := float(now - _window_start_usec) / 1000000.0
	if elapsed < 1.0:
		return
	_frames.sort()
	var over_33 := 0
	var over_50 := 0
	for frame_ms in _frames:
		if frame_ms > 33.333:
			over_33 += 1
		if frame_ms > 50.0:
			over_50 += 1
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var activity := scene.get_node_or_null("EnemyActivity") if scene else null
	latest = {
		"uptime_s": float(now) / 1000000.0,
		"window_s": elapsed,
		"fps": float(_frames.size()) / elapsed,
		"frame_mean_ms": elapsed * 1000.0 / float(_frames.size()),
		"frame_p95_ms": _frames[clampi(ceili(_frames.size() * 0.95) - 1, 0, _frames.size() - 1)],
		"frame_max_ms": _frames[-1],
		"frames_over_33ms": over_33,
		"frames_over_50ms": over_50,
		"process_ms_last": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms_last": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls_last": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects_last": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives_last": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"static_memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"physics_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"physics_collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"managed_enemies": activity.entries.size() if activity else 0,
		"sleeping_enemies": activity.sleeping_count if activity else 0,
		"paused": get_tree().paused,
		"scene": scene.scene_file_path if scene else "",
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z] if player else [],
	}
	history.append(latest)
	if history.size() > 120:
		history.pop_front()
	if _log:
		_log.store_line(JSON.stringify(latest))
		_samples_since_flush += 1
		if _samples_since_flush >= 5:
			_log.flush()
			_samples_since_flush = 0
	_frames.clear()
	_window_start_usec = now


func _exit_tree() -> void:
	if _log:
		_log.flush()
		_log.close()
