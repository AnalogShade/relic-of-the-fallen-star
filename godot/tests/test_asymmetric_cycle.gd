@tool
extends SceneTree

func _init() -> void:
	print("--- Testing DayNightCycle Asymmetric Cycle ---")
	var cycle_script = load("res://scripts/day_night_cycle.gd")
	if cycle_script == null:
		printerr("FAIL: Could not load day_night_cycle.gd")
		quit(1)
		return

	var cycle: DayNightCycle = cycle_script.new()
	
	# Verify default values
	print("asymmetric_cycle: ", cycle.asymmetric_cycle)
	print("day_duration_minutes: ", cycle.day_duration_minutes)
	print("night_duration_minutes: ", cycle.night_duration_minutes)
	print("Total cycle minutes: ", cycle.get_total_cycle_minutes())
	
	assert(cycle.asymmetric_cycle == true, "Asymmetric cycle should be enabled by default")
	assert(is_equal_approx(cycle.day_duration_minutes, 18.0), "Day duration should be 18.0 min")
	assert(is_equal_approx(cycle.night_duration_minutes, 3.0), "Night duration should be 3.0 min")
	assert(is_equal_approx(cycle.get_total_cycle_minutes(), 21.0), "Total cycle should be 21.0 min")
	
	# Check day speed at midday (12.0)
	var day_speed: float = cycle.get_effective_hours_per_second(12.0)
	var expected_day_speed: float = 16.0 / (18.0 * 60.0) # ~0.0148148
	print("Day speed at 12h: ", day_speed, " (expected: ", expected_day_speed, ")")
	assert(is_equal_approx(day_speed, expected_day_speed), "Day speed does not match expected")
	
	# Check night speed at midnight (0.0)
	var night_speed: float = cycle.get_effective_hours_per_second(0.0)
	var expected_night_speed: float = 8.0 / (3.0 * 60.0) # ~0.044444
	print("Night speed at 0h: ", night_speed, " (expected: ", expected_night_speed, ")")
	assert(is_equal_approx(night_speed, expected_night_speed), "Night speed does not match expected")
	
	# Check speed ratio (night speed / day speed = 3.0)
	var speed_ratio: float = night_speed / day_speed
	print("Speed ratio (night / day): ", speed_ratio)
	assert(is_equal_approx(speed_ratio, 3.0), "Night speed should be exactly 3x day speed")
	
	# Check smooth transition at dawn (5.0) and dusk (21.0)
	var dawn_mid_speed: float = cycle.get_effective_hours_per_second(5.0)
	var expected_mid_speed: float = (day_speed + night_speed) * 0.5
	print("Dawn transition speed at 5h: ", dawn_mid_speed, " (expected midpoint: ", expected_mid_speed, ")")
	assert(is_equal_approx(dawn_mid_speed, expected_mid_speed), "Dawn midpoint speed should be average of day and night")
	
	var dusk_mid_speed: float = cycle.get_effective_hours_per_second(21.0)
	print("Dusk transition speed at 21h: ", dusk_mid_speed, " (expected midpoint: ", expected_mid_speed, ")")
	assert(is_equal_approx(dusk_mid_speed, expected_mid_speed), "Dusk midpoint speed should be average of day and night")
	
	# Test fallback when asymmetric_cycle is false
	cycle.asymmetric_cycle = false
	var uniform_speed: float = cycle.get_effective_hours_per_second(12.0)
	var expected_uniform: float = 24.0 / (10.0 * 60.0)
	assert(is_equal_approx(uniform_speed, expected_uniform), "Uniform fallback should match cycle_duration_minutes")
	
	cycle.free()
	print("PASS: All Asymmetric Day/Night Cycle tests passed successfully!")
	quit(0)
