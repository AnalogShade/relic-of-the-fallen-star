class_name SurfaceDetector
extends RefCounted
## SurfaceDetector — Identifie le type de sol (gravier, brindilles/forêt, pelouse)
## sous les pieds du joueur, synchronisé avec la disposition du monde et les sentiers.

enum SurfaceType {
	TWIGS,
	GRASS,
	GRAVEL
}

static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 == 0.0:
		return (p - a).length()
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (p - (a + ab * t)).length()

static func trail_distance(p: Vector2) -> float:
	return preload("res://scripts/forest_trails.gd").distance_to_path(p)

static func get_surface_at(pos: Vector3) -> SurfaceType:
	var p2 := Vector2(pos.x, pos.z)
	# 1. Proximité du sentier : moins de 2.2 m d'un segment = gravier
	if trail_distance(p2) < 2.2:
		return SurfaceType.GRAVEL
	
	# 2. Hors sentier : pelouse et clairières herbeuses
	return SurfaceType.GRASS

