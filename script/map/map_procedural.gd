@tool
extends Node3D

# Paramètres
@export var map_size: int = 300
@export var bloc_size: float = 10.0
@export var platform_coverage: float = 0.06
@export var min_platform_blocs: int = 3
@export var max_platform_blocs: int = 8
@export var max_attempts_place: int = 3000
@export var seed: int = 0
@export var bloc_gap: int = 1
@export var stacked_platform_chance: float = 0.5
@export var auto_generate_on_play: bool = true
@export var generate_ground: bool = true
@export_file var bloc_path: String = "res://scenes/cyberpunk_block.tscn"

# Paramètres pylônes
@export_group("Pylône")
@export var pilone_count: int = 10
@export_file("*.vox") var pylone_path: String = "res://assets/pylone.vox"
@export_file("*.gdshader") var pylone_shader_path: String = "res://shaders/pylone.gdshader"
@export_file("*.gd") var pylone_script_path: String = "res://script/pylone_charge.gd"

@export_group("Audio Wall")
@export_file("*.gd") var audio_wall_script_path: String = "res://script/audio_wall.gd"

@export_group("Generate")
@export var Generate: bool:
	get:
		return false
	set(value):
		if Engine.is_editor_hint() and value:
			generate()

const NAME_BODY := "GeneratedStaticBody"

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
	else:
		if auto_generate_on_play:
			generate()

func generate() -> void:
	print("Génération de la map...")
	_cleanup_previous()
	
	if not ResourceLoader.exists(bloc_path):
		push_error("Le modèle bloc.glb n'existe pas: " + bloc_path)
		return
	
	var N = max(1, int(floor(float(map_size) / bloc_size)))
	var M = N
	
	if not _validate_parameters(N, M):
		return
	
	var rng = _setup_rng()
	var hm = _create_heightmap(N, M)

	
	var container = Node3D.new()
	container.name = NAME_BODY
	var center = Vector3(
		N * bloc_size * 0.5, 
		bloc_size * 0.5,  # ← Ajout de l'offset vertical
		M * bloc_size * 0.5
	)
		# Utiliser le générateur de plateformes
	var placed_platforms = PlatformGenerator.generate_platforms(
		N, M, hm, rng,
		platform_coverage,
		min_platform_blocs,
		max_platform_blocs,
		max_attempts_place,
		bloc_gap,
		stacked_platform_chance,
		bloc_size,
		center,
		container
	)
	# Générer le terrain
	if generate_ground:
		_generate_ground(N, M, bloc_size, center, container)
	
	# Placer les blocs visuels
	_place_visual_blocs(placed_platforms, bloc_size, center, container)
	
	# Générer les rampes
	var ramp_positions = RampGenerator.generate_ramps(
		placed_platforms, hm, N, M, bloc_size, bloc_gap, rng, container, center
	)
	
	add_child(container)
	
	if Engine.is_editor_hint():
		container.owner = get_tree().edited_scene_root
	
	# Placer les pylônes
	if pilone_count > 0:
		var placed = PyloneGenerator.generate_pylones(
			pilone_count, N, M, hm, bloc_size, rng, container, center,
			ramp_positions, pylone_path, pylone_shader_path, pylone_script_path,
			Engine.is_editor_hint()
		)
		print("Pylônes placés: ", placed, "/", pilone_count)
	
	# Créer le mur audio
	_create_audio_wall(container)
	
	print("Génération terminée: ", N, "x", M, " - Plateformes:", placed_platforms.size())

func _validate_parameters(N: int, M: int) -> bool:
	if min_platform_blocs > max_platform_blocs:
		push_error("min_platform_blocs > max_platform_blocs")
		return false
	if min_platform_blocs > N or min_platform_blocs > M:
		push_error("min_platform_blocs trop grand")
		return false
	return true

func _setup_rng() -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	return rng

func _create_heightmap(N: int, M: int) -> Array:
	var hm := []
	for x in range(N + 1):
		var col := []
		for z in range(M + 1):
			col.append(0)
		hm.append(col)
	return hm

func _place_visual_blocs(placed_platforms: Array, bloc_size: float, center: Vector3, container: Node3D) -> void:
	var bloc_scene = load(bloc_path)
	var visual_container = Node3D.new()
	visual_container.name = "BlocsVisuels"
	
	# Parcourir TOUTES les plateformes, pas juste la heightmap
	for plat in placed_platforms:
		for x in range(plat.x, plat.x + plat.w):
			for z in range(plat.z, plat.z + plat.h):
				var bloc = bloc_scene.instantiate()
				bloc.name = "Bloc_" + str(x) + "_" + str(z) + "_L" + str(plat.level)
				
				var x_pos = x * bloc_size + bloc_size * 0.5
				var y_pos = (plat.level - 1) * bloc_size + bloc_size * 0.5
				var z_pos = z * bloc_size + bloc_size * 0.5
				
				bloc.position = Vector3(x_pos, y_pos, z_pos) - center
				visual_container.add_child(bloc)
	
	container.add_child(visual_container)

func _generate_ground(N: int, M: int, bloc_size: float, center: Vector3, container: Node3D) -> void:
	var ground = StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 2
	ground.collision_mask = 4
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(N * bloc_size, 1.0, M * bloc_size)
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.3)
	mesh_inst.material_override = mat
	
	# CORRECTION : Positionner le ground à Y = -0.5 pour qu'il soit sous les plateformes
	ground.position = Vector3(0, -0.5, 0)
	ground.add_child(mesh_inst)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	ground.add_child(collision)
	
	container.add_child(ground)
func _create_audio_wall(container: Node3D) -> void:
	var audio_wall = Node3D.new()
	audio_wall.name = "AudioWall"
	audio_wall.set_script(load(audio_wall_script_path))
	audio_wall.set("map_size", map_size - 10.5)
	container.add_child(audio_wall)

func _cleanup_previous() -> void:
	for child in get_children():
		child.queue_free()
