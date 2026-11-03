extends SceneTree
## Evaluate the existing spatial lookup without modifying gameplay.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ocean := load("res://assets/environment/world/ocean.glb").instantiate() as Node3D
	root.add_child(ocean)
	current_scene = ocean
	var sampler := preload("res://scripts/water_surface.gd").new()
	ocean.add_child(sampler)
	sampler.rebuild()
	var lookup := preload("res://scripts/lake_water_lookup.gd").new()
	var start := Time.get_ticks_usec()
	lookup.build(sampler.surfaces, Vector3.ZERO, 10000.0)
	var build_ms := float(Time.get_ticks_usec() - start) / 1000.0
	var cases: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261027
	for i in 80: cases.append(Vector3(rng.randf_range(-35.0, 35.0), 3.0, rng.randf_range(85.0, 175.0)))
	for z in [87.999, 88.0, 88.001, 90.0, 150.0]:
		for x in [-9.0, 0.0, 8.0, 20.0]: cases.append(Vector3(x, 3.0, z))
	var mismatches := 0
	for point in cases:
		var expected := sampler.height_at(point)
		var actual := lookup.height_at(point)
		if is_finite(expected) != is_finite(actual) or (is_finite(expected) and absf(actual - expected) > 0.00001): mismatches += 1
	var timings := []
	for point in [Vector3(8, 3, 87.99), Vector3(8, 3, 88.01), Vector3(-9, 3, 90), Vector3(0, 3, 150)]:
		start = Time.get_ticks_usec()
		for repeat in 1000: lookup.height_at(point)
		timings.append({"point": str(point), "indexed_query_ms": float(Time.get_ticks_usec() - start) / 1000000.0, "local_candidates": lookup.cells.get(Vector2i(floori(point.x / lookup.CELL_SIZE), floori(point.z / lookup.CELL_SIZE)), []).size()})
	var report := {"build_ms": build_ms, "cells": lookup.cells.size(), "broad_triangles": lookup.broad_triangles.size(), "cases": cases.size(), "mismatches": mismatches, "timings": timings, "max_physics_steps_per_frame": Engine.max_physics_steps_per_frame, "physics_ticks_per_second": Engine.physics_ticks_per_second}
	print("INDEXED ", JSON.stringify(report))
	var file := FileAccess.open("res://../diagnostics/beach_performance_20261027/indexed.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	ocean.queue_free()
	await process_frame
	quit(0 if mismatches == 0 else 1)
