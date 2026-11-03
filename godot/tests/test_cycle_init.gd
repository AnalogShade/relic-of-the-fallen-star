@tool
extends SceneTree

func _init() -> void:
	print("--- Testing DayNightCycle compilation and basic instantiation ---")
	var cycle_script = load("res://scripts/day_night_cycle.gd")
	if cycle_script == null:
		printerr("FAIL: Could not load day_night_cycle.gd")
		quit(1)
		return
	
	var cycle = cycle_script.new()
	print("PASS: Instantiated DayNightCycle successfully")
	cycle.free()
	quit(0)
