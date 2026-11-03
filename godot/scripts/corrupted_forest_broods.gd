extends Node3D
## Three dense broods make the lake fragment essential against their shielded leaders.
const SPIDER := preload("res://scenes/araignee.tscn")
const CENTERS := [Vector3(-230, 9.49, -150), Vector3(-234, 11.16, -226), Vector3(-182, 12.19, -162)]
var brood_count := 0

func _ready() -> void:
	call_deferred("populate")

func populate() -> void:
	if has_node("Broods"): return
	var broods := Node3D.new()
	broods.name = "Broods"
	add_child(broods)
	for group_index in range(CENTERS.size()):
		var center: Vector3 = CENTERS[group_index]
		for i in range(8):
			var angle := TAU * i / 8.0 + group_index * 0.5
			var point := center + Vector3(cos(angle), 0, sin(angle)) * (4.5 if i % 2 == 0 else 7.0)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 10, point - Vector3.UP * 12, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.normal.y < 0.75: continue
			var spider := SPIDER.instantiate()
			spider.name = "Couvee_%d_%02d" % [group_index + 1, i + 1]
			spider.enemy_name = "Araignée de la couvée"
			spider.max_health = 55.0
			spider.damage = 9.0
			spider.spider_scale = 1.05
			spider.detection_radius = 14.0
			spider.leash_radius = 22.0
			spider.patrol_radius = 3.0
			spider.chase_speed = 3.8
			spider.temperament = "agressif"
			spider.behavior_seed = 2800 + group_index * 10 + i
			spider.position = to_local(hit.position + Vector3.UP * 0.05)
			broods.add_child(spider)
			brood_count += 1
