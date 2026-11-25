@tool
extends Node3D
## Assembly-only settings; the original forest scene and GLB remain reusable.
const WATER = preload("res://shaders/water.gdshader")
const FLOWING_WATER = preload("res://scripts/stream_water.gd")
const OUTDOOR_MESH_LOD_THRESHOLD := 2.0

var _outdoor_viewport: Viewport
var _previous_msaa: Viewport.MSAA
var _previous_mesh_lod_threshold: float

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		_outdoor_viewport = get_viewport()
		_previous_msaa = _outdoor_viewport.msaa_3d
		_previous_mesh_lod_threshold = _outdoor_viewport.mesh_lod_threshold
		if _previous_msaa > Viewport.MSAA_4X:
			_outdoor_viewport.msaa_3d = Viewport.MSAA_4X
		_outdoor_viewport.mesh_lod_threshold = maxf(_previous_mesh_lod_threshold, OUTDOOR_MESH_LOD_THRESHOLD)
		for path in ["Original/Sun", "Original/Moon"]:
			var light := get_node_or_null(path) as DirectionalLight3D
			if light:
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

	# Opt in this outdoor world before its existing cycle enters _ready().
	var cycle := get_node_or_null("Original/DayNightCycle")
	if cycle != null:
		cycle.use_outdoor_sky = true

func _exit_tree() -> void:
	# The forest shares this viewport with independent interior scenes.
	if _outdoor_viewport != null:
		_outdoor_viewport.msaa_3d = _previous_msaa
		_outdoor_viewport.mesh_lod_threshold = _previous_mesh_lod_threshold
		_outdoor_viewport = null

func _ready() -> void:
	call_deferred("_configure_world")

func _configure_world() -> void:
	var original := get_node_or_null("Original")
	if original == null:
		return
	preload("res://scripts/world_legacy_cleanup.gd").apply(original)
	preload("res://scripts/castle_moat_cleanup.gd").apply(self)
	for mesh in original.find_children("DistantHills*", "MeshInstance3D", true, false):
		mesh.visible = false
	var player := original.get_node_or_null("Player")
	if player != null:
		player.world_bounds = Rect2(-287.0, -295.0, 510.0, 510.0)
		var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
		camera.far = 4000.0
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://shaders/world_ground.gdshader")
	preload("res://scripts/hybrid_grass_material.gd").configure(ground)
	preload("res://scripts/mountain_ground_material.gd").configure(ground)
	var water := ShaderMaterial.new()
	water.shader = WATER
	var oasis_water := ShaderMaterial.new()
	oasis_water.shader = preload("res://shaders/oasis_water.gdshader")
	var ocean := ShaderMaterial.new()
	ocean.shader = preload("res://shaders/ocean.gdshader")
	for child in original.find_children("Terrain*", "MeshInstance3D", true, false):
		child.material_override = ground
	var sectors := get_node_or_null("Sectors")
	if sectors != null:
		for child in sectors.find_children("*", "MeshInstance3D", true, false):
			if str(child.name) == "Ripples":
				child.visible = false
			elif str(child.name).begins_with("Terrain") or str(child.name).begins_with("CastleGround"):
				child.material_override = ground
			elif str(child.name).begins_with("Ocean"):
				child.material_override = ocean
			elif str(child.name).begins_with("Paths"):
				child.visible = false
			elif str(child.name).begins_with("Water_Oasis_Reservoir") or str(child.name).begins_with("Water_Oasis_Exutoire"):
				child.material_override = oasis_water
				if str(child.name).begins_with("Water_Oasis_Reservoir"):
					FLOWING_WATER.apply_lake(child)
				else:
					FLOWING_WATER.apply(child)
			elif str(child.name).begins_with("Water"):
				child.material_override = water
				if str(child.name) == "Water_Moat":
					FLOWING_WATER.apply_lake(child)
				elif str(child.name) == "Water" or str(child.name).begins_with("Water_Oasis_Source"):
					FLOWING_WATER.apply(child)
			elif str(child.name).begins_with("Undergrowth"):
				child.visibility_range_end = 90.0
				child.visibility_range_end_margin = 12.0

	# Ground materials are recreated above, including during editor reloads.
	preload("res://scripts/stream_stone_ground.gd").apply.call_deferred(self)
	preload("res://scripts/forest_trail_clearance.gd").apply(self)
	preload("res://scripts/natural_surface_materials.gd").apply(self)
	preload("res://scripts/rock_replacements.gd").apply(self)
	preload("res://scripts/scene_grounding_cleanup.gd").apply(self)
	# Existing grass on the restored cave path is redistributed along its verges.
	var verge_grass := get_node_or_null("Original/EnvironmentArt/OriginalGeometry/Undergrowth") as MeshInstance3D
	if verge_grass != null:
		verge_grass.mesh = preload("res://assets/environment/path_edge_grass/undergrowth.res")
	preload("res://scripts/broadleaf_foliage.gd").apply(self)
	preload("res://scripts/pine_foliage.gd").apply(self)
	preload("res://scripts/fern_replacements.gd").apply(self)
	preload("res://scripts/grass_replacements.gd").apply(self)
	preload("res://scripts/stream_grass_trial.gd").apply(self)
	if not Engine.is_editor_hint() and get_node_or_null("EnemyActivity") == null:
		var activity := preload("res://scripts/enemy_activity.gd").new()
		activity.name = "EnemyActivity"
		add_child(activity)
	if not Engine.is_editor_hint() and get_node_or_null("CaveEncounter") == null:
		var encounter := preload("res://scripts/cave_encounter.gd").new()
		encounter.name = "CaveEncounter"
		add_child(encounter)
	if not Engine.is_editor_hint() and get_node_or_null("LakeMonster") == null:
		var lake_monster := preload("res://scripts/lake_monster.gd").new()
		lake_monster.name = "LakeMonster"
		lake_monster.stream_model = true
		lake_monster.position = Vector3(7.0, 5.5, -213.0)
		add_child(lake_monster)

	if not Engine.is_editor_hint() and get_node_or_null("StreamTrout") == null:
		var trout := preload("res://scripts/stream_trout_population.gd").new()
		trout.name = "StreamTrout"
		add_child(trout)

	if not Engine.is_editor_hint() and get_node_or_null("ForestMotes") == null:
		var harvest := preload("res://scripts/harvest_world.gd").new()
		harvest.name = "HarvestWorld"
		add_child(harvest)
		var fishing := preload("res://scripts/stream_fishing.gd").new()
		fishing.name = "StreamFishing"
		add_child(fishing)
		var motes := preload("res://scripts/forest_motes.gd").new()
		motes.name = "ForestMotes"
		add_child(motes)
		if get_node_or_null("InsectManager") == null:
			var insects := preload("res://scripts/insect_manager.gd").new()
			insects.name = "InsectManager"
			add_child(insects)
		if get_node_or_null("StreamAudioEmitter") == null:
			var stream_audio := preload("res://scripts/stream_audio_emitter.gd").new()
			stream_audio.name = "StreamAudioEmitter"
			add_child(stream_audio)
		if get_node_or_null("ForestBirdsAmbience") == null:
			var birds_audio := preload("res://scripts/forest_birds_ambience.gd").new()
			birds_audio.name = "ForestBirdsAmbience"
			add_child(birds_audio)
