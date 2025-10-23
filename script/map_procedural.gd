@tool
extends Node3D

# Paramètres
@export var map_size: int = 100
@export var bloc_size: float = 10.0
@export var platform_coverage: float = 0.06
@export var min_platform_blocs: int = 2
@export var max_platform_blocs: int = 8
@export var max_attempts_place: int = 3000
@export var seed: int = 0
@export var bloc_gap: int = 1
@export var stacked_platform_chance: float = 0.5
@export var auto_generate_on_play: bool = true
@export var generate_ground: bool = true
@export var ground_height: float = -5.0
@export_file("*.glb") var bloc_path: String = "res://bloc.glb"
@export_file("*.obj", "*.glb") var pilone_path: String = "res://pilone.obj"
@export var pilone_count: int = 10

# Paramètres du shader pylône
@export_group("Pylône Shader")
@export_file("*.gdshader") var pilone_shader_path: String = "res://pilone_shader.gdshader"
@export_file("*.png") var pilone_texture_path: String = "res://pilone.png"
@export_file("*.gd") var pilone_script_path: String = "res://pilone_charge.gd"
@export var neon_color: Color = Color("#ff1633")  # Couleur néon de départ
@export var pilone_detection_radius: float = 5.0  # Rayon de détection

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
		print("MapGenerator ready (editor).")
	else:
		if auto_generate_on_play:
			generate()
		print("MapGenerator ready (game mode).")

func generate() -> void:
	print("Génération avec blocs préfaits...")
	_cleanup_previous()
	
	if not ResourceLoader.exists(bloc_path):
		push_error("Le modèle bloc.glb n'existe pas au chemin: " + bloc_path)
		return
	
	var N = max(1, int(floor(float(map_size) / bloc_size)))
	var M = N
	
	if min_platform_blocs > max_platform_blocs:
		push_error("min_platform_blocs ne peut pas être plus grand que max_platform_blocs")
		return
	if min_platform_blocs > N or min_platform_blocs > M:
		push_error("min_platform_blocs est trop grand pour la taille de la map")
		return

	var rng = RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

	var hm := []
	for x in range(N + 1):
		var col := []
		for z in range(M + 1):
			col.append(0)
		hm.append(col)

	var placed_platforms := []
	var total_blocs = float(N) * float(M)
	var target_blocs = int(clamp(platform_coverage * total_blocs, 1, total_blocs))

	var blocs_placed = 0
	var attempts = 0
	
	# PHASE 1: Placement des plateformes au sol (niveau 1)
	while blocs_placed < target_blocs and attempts < max_attempts_place:
		attempts += 1
		var max_w = min(max_platform_blocs, N)
		var max_h = min(max_platform_blocs, M)
		
		if max_w < min_platform_blocs or max_h < min_platform_blocs:
			break
		
		var w = rng.randi_range(min_platform_blocs, max_w)
		var h = rng.randi_range(min_platform_blocs, max_h)
		
		if N - w < 0 or M - h < 0:
			continue
		
		var x0 = rng.randi_range(0, N - w)
		var z0 = rng.randi_range(0, M - h)

		var ok = true
		for xi in range(max(0, x0 - bloc_gap), min(N, x0 + w + bloc_gap)):
			for zi in range(max(0, z0 - bloc_gap), min(M, z0 + h + bloc_gap)):
				if xi < hm.size() and zi < hm[xi].size():
					if hm[xi][zi] > 0:
						ok = false
						break
			if not ok:
				break
		if not ok:
			continue

		for xi in range(x0, x0 + w):
			for zi in range(z0, z0 + h):
				hm[xi][zi] = 1
				blocs_placed += 1

		placed_platforms.append({
			"x": x0,
			"z": z0,
			"w": w,
			"h": h,
			"level": 1
		})

	# PHASE 2: Empilement de plateformes
	var i = 0
	while i < placed_platforms.size():
		var base_plat = placed_platforms[i]
		i += 1
		
		if rng.randf() > stacked_platform_chance:
			continue
		
		var max_w = max(min_platform_blocs, base_plat.w - bloc_gap * 2)
		var max_h = max(min_platform_blocs, base_plat.h - bloc_gap * 2)
		
		if max_w < min_platform_blocs or max_h < min_platform_blocs:
			continue
		
		var w = rng.randi_range(min_platform_blocs, min(max_platform_blocs, max_w))
		var h = rng.randi_range(min_platform_blocs, min(max_platform_blocs, max_h))
		
		var max_offset_x = max(0, base_plat.w - w - bloc_gap)
		var max_offset_z = max(0, base_plat.h - h - bloc_gap)
		
		if max_offset_x < bloc_gap or max_offset_z < bloc_gap:
			continue
		
		var offset_x = rng.randi_range(bloc_gap, max_offset_x)
		var offset_z = rng.randi_range(bloc_gap, max_offset_z)
		
		var x0 = base_plat.x + offset_x
		var z0 = base_plat.z + offset_z
		var new_level = base_plat.level + 1
		
		for xi in range(x0, x0 + w):
			for zi in range(z0, z0 + h):
				hm[xi][zi] = new_level
		
		placed_platforms.append({
			"x": x0,
			"z": z0,
			"w": w,
			"h": h,
			"level": new_level
		})

	var container = Node3D.new()
	container.name = NAME_BODY
	var center = Vector3(N * bloc_size * 0.5, 0, M * bloc_size * 0.5)

	# Générer le sol
	if generate_ground:
		_generate_ground(N, M, bloc_size, center, container)

	# Placer les blocs visuels (sans collision individuelle)
	var bloc_scene = load(bloc_path)
	var visual_container = Node3D.new()
	visual_container.name = "BlocsVisuels"
	
	for x in range(N):
		for z in range(M):
			var level = hm[x][z]
			if level > 0:
				var bloc_instance = bloc_scene.instantiate()
				bloc_instance.name = "Bloc_" + str(x) + "_" + str(z) + "_L" + str(level)
				
				var x_pos = x * bloc_size + bloc_size * 0.5
				var y_pos = (level - 1) * bloc_size + bloc_size * 0.5
				var z_pos = z * bloc_size + bloc_size * 0.5
				
				bloc_instance.position = Vector3(x_pos, y_pos, z_pos) - center
				visual_container.add_child(bloc_instance)
	
	container.add_child(visual_container)

	# Créer les collisions par plateforme (une collision par plateforme)
	_generate_platform_collisions(placed_platforms, bloc_size, center, container)

	# Générer les rampes
	var ramp_positions = []  # Stocker les positions des rampes
	for plat in placed_platforms:
		var ramp_pos = _generate_ramps(plat.x, plat.z, plat.w, plat.h, plat.level, hm, N, M, bloc_size, rng, container, center)
		if ramp_pos != null:
			ramp_positions.append(ramp_pos)

	# Placer les pylônes aléatoirement
	if pilone_count > 0 and ResourceLoader.exists(pilone_path):
		_generate_pilones(N, M, hm, bloc_size, rng, container, center, ramp_positions)

	add_child(container)
	
	if Engine.is_editor_hint():
		container.owner = get_tree().edited_scene_root

	print("MapGenerator: génération terminée. size=", N, "x", M, " blocs:", blocs_placed, " plateformes:", placed_platforms.size())

# Générer une collision unique par plateforme
func _generate_platform_collisions(platforms: Array, bloc_size: float, center: Vector3, container: Node3D) -> void:
	for plat in platforms:
		var collision_body = StaticBody3D.new()
		collision_body.name = "Platform_L" + str(plat.level) + "_" + str(plat.x) + "_" + str(plat.z)
		collision_body.collision_layer = 2
		collision_body.collision_mask = 4
		
		# Créer une BoxShape pour toute la plateforme
		var collision = CollisionShape3D.new()
		collision.name = "Collision"
		var box_shape = BoxShape3D.new()
		
		# Taille de la plateforme
		var width = plat.w * bloc_size
		var depth = plat.h * bloc_size
		box_shape.size = Vector3(width, bloc_size, depth)
		
		# Position au centre de la plateforme
		var x_pos = plat.x * bloc_size + width * 0.5
		var y_pos = (plat.level - 1) * bloc_size + bloc_size * 0.5
		var z_pos = plat.z * bloc_size + depth * 0.5
		
		collision_body.position = Vector3(x_pos, y_pos, z_pos) - center
		collision.shape = box_shape
		collision_body.add_child(collision)
		container.add_child(collision_body)

func _generate_ground(N: int, M: int, bloc_size: float, center: Vector3, container: Node3D) -> void:
	var ground_body = StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 2
	ground_body.collision_mask = 4
	
	var mesh = BoxMesh.new()
	var ground_width = N * bloc_size
	var ground_depth = M * bloc_size
	mesh.size = Vector3(ground_width, 1.0, ground_depth)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "GroundMesh"
	mesh_instance.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.3)
	mesh_instance.material_override = mat
	
	ground_body.position = Vector3(0, ground_height, 0)
	ground_body.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	collision.name = "GroundCollision"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(ground_width, 1.0, ground_depth)
	collision.shape = box_shape
	ground_body.add_child(collision)
	
	container.add_child(ground_body)

func _generate_ramps(x0, z0, w, h, level, hm, N, M, bloc_size, rng, container: Node3D, center: Vector3):
	var directions = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
	directions.shuffle()
	
	for dir in directions:
		var nx = x0
		var nz = z0
		if dir.x > 0:
			nx = x0 + w
			nz = z0 + rng.randi_range(0, h-1)
		elif dir.x < 0:
			nx = x0 - 1
			nz = z0 + rng.randi_range(0, h-1)
		elif dir.y > 0:
			nx = x0 + rng.randi_range(0, w-1)
			nz = z0 + h
		elif dir.y < 0:
			nx = x0 + rng.randi_range(0, w-1)
			nz = z0 - 1

		if nx >= 0 and nx < N and nz >= 0 and nz < M:
			var neighbor_level = hm[nx][nz]
			if neighbor_level == level - 1:
				_add_ramp(Vector3(nx, 0, nz), dir, bloc_size, level, container, center)
				return Vector2(nx, nz)  # Retourner la position de la rampe
	
	return null  # Aucune rampe créée

func _add_ramp(origin: Vector3, dir: Vector2, bloc_size: float, level: int, container: Node3D, center: Vector3) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.5)
	
	var ramp_body = StaticBody3D.new()
	ramp_body.name = "Ramp_" + str(origin.x) + "_" + str(origin.z)
	ramp_body.collision_layer = 2
	ramp_body.collision_mask = 4
	
	# Créer le mesh de la rampe
	var mesh = PrismMesh.new()
	mesh.size = Vector3(bloc_size, bloc_size, bloc_size)
	
	var base_height = (level - 1) * bloc_size
	var x_pos = origin.x * bloc_size + bloc_size * 0.5
	var z_pos = origin.z * bloc_size + bloc_size * 0.5
	
	var ramp_mi = MeshInstance3D.new()
	ramp_mi.name = "RampMesh"
	ramp_mi.mesh = mesh
	ramp_mi.material_override = mat
	
	# Variables pour rotation et inclinaison
	var mesh_rotation = Vector3.ZERO
	var collision_rotation = Vector3.ZERO
	
	# Configuration selon la direction
	if dir.x > 0:  # Rampe vers +X
		mesh.left_to_right = 0.0
		mesh_rotation = Vector3(0, 0, 0)
		collision_rotation = Vector3(0, 0, -45)
	elif dir.x < 0:  # Rampe vers -X
		mesh.left_to_right = 1.0
		mesh_rotation = Vector3(0, 0, 0)
		collision_rotation = Vector3(0, 0, 45)
	elif dir.y > 0:  # Rampe vers +Z
		mesh.left_to_right = 0.0
		mesh_rotation = Vector3(0, 90, 0)
		collision_rotation = Vector3(45, 90, 0)
	elif dir.y < 0:  # Rampe vers -Z
		mesh.left_to_right = 1.0
		mesh_rotation = Vector3(0, 90, 0)
		collision_rotation = Vector3(-45, 90, 0)
	
	ramp_mi.rotation_degrees = mesh_rotation
	ramp_body.position = Vector3(x_pos, base_height + bloc_size * 0.5, z_pos) - center
	ramp_body.rotation_degrees = mesh_rotation
	ramp_body.add_child(ramp_mi)
	
	# Collision de rampe
	var cs_ramp = CollisionShape3D.new()
	cs_ramp.name = "RampCollision"
	
	var st = SurfaceTool.new()
	st.create_from(mesh, 0)
	var ramp_mesh = st.commit()
	
	if ramp_mesh.get_surface_count() > 0:
		var arrs = ramp_mesh.surface_get_arrays(0)
		if arrs.size() > Mesh.ARRAY_VERTEX and arrs[Mesh.ARRAY_VERTEX]:
			var verts = arrs[Mesh.ARRAY_VERTEX]
			var convex = ConvexPolygonShape3D.new()
			convex.points = verts
			cs_ramp.shape = convex
	
	ramp_body.add_child(cs_ramp)
	container.add_child(ramp_body)

func _create_pilone_material() -> ShaderMaterial:
	var shader_material = ShaderMaterial.new()
	
	# Charger le shader
	if ResourceLoader.exists(pilone_shader_path):
		var shader = load(pilone_shader_path)
		shader_material.shader = shader
	else:
		push_error("Shader non trouvé: " + pilone_shader_path)
		return null
	
	# Charger la texture
	if ResourceLoader.exists(pilone_texture_path):
		var texture = load(pilone_texture_path)
		shader_material.set_shader_parameter("albedo_texture", texture)
	else:
		push_error("Texture non trouvée: " + pilone_texture_path)
	
	# Définir les paramètres fixes
	shader_material.set_shader_parameter("target_color", Color("#fff2f2"))
	shader_material.set_shader_parameter("color_tolerance", 0.11)
	shader_material.set_shader_parameter("emission_strength", 5.5)
	shader_material.set_shader_parameter("use_original_color", false)
	
	# Paramètre tweakable depuis l'export
	shader_material.set_shader_parameter("neon_color", neon_color)
	
	return shader_material

func _apply_material_to_mesh_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	
	for child in node.get_children():
		_apply_material_to_mesh_recursive(child, material)

func _generate_pilones(N: int, M: int, hm: Array, bloc_size: float, rng: RandomNumberGenerator, container: Node3D, center: Vector3, ramp_positions: Array) -> void:
	var pilone_resource = load(pilone_path)
	var pilone_material = _create_pilone_material()
	
	if not pilone_material:
		push_error("Impossible de créer le matériau pylône")
		return
	
	var placed = 0
	var attempts = 0
	var max_attempts = pilone_count * 10
	
	while placed < pilone_count and attempts < max_attempts:
		attempts += 1
		
		# Position aléatoire sur la grille
		var x = rng.randi_range(0, N - 1)
		var z = rng.randi_range(0, M - 1)
		
		# Vérifier qu'on n'est pas sur une rampe
		var is_on_ramp = false
		for ramp_pos in ramp_positions:
			if ramp_pos != null and int(ramp_pos.x) == x and int(ramp_pos.y) == z:
				is_on_ramp = true
				break
		
		if is_on_ramp:
			continue
		
		# Les pylônes peuvent être placés partout sauf sur les rampes
		var level = hm[x][z]
		
		var pilone_instance: Node3D
		
		# Vérifier si c'est une scène (.glb) ou un mesh (.obj)
		if pilone_resource is PackedScene:
			pilone_instance = pilone_resource.instantiate()
		else:
			# C'est un mesh (.obj), créer un Node3D parent avec MeshInstance3D enfant
			var pilone_parent = Node3D.new()
			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = pilone_resource
			mesh_inst.material_override = pilone_material
			pilone_parent.add_child(mesh_inst)
			pilone_instance = pilone_parent
		
		pilone_instance.name = "Pilone_" + str(placed)
		
		# Position du pylône (adapter la hauteur selon le niveau)
		var x_pos = x * bloc_size + bloc_size * 0.5
		var y_pos = level * bloc_size  # Hauteur selon le niveau de la plateforme
		var z_pos = z * bloc_size + bloc_size * 0.5
		
		pilone_instance.position = Vector3(x_pos, y_pos, z_pos) - center
		
		# Scale du pylône
		pilone_instance.scale = Vector3(0.5, 0.5, 0.5)
		
		# Rotation aléatoire sur l'axe Y
		pilone_instance.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		
		# Appliquer le matériau shader de manière récursive (pour les .glb)
		if pilone_resource is PackedScene:
			_apply_material_to_mesh_recursive(pilone_instance, pilone_material)
		
		# Attacher le script de charge au pylône
		if ResourceLoader.exists(pilone_script_path):
			var script = load(pilone_script_path)
			pilone_instance.set_script(script)
			# Configurer les paramètres du script
			pilone_instance.set("detection_radius", pilone_detection_radius)
			pilone_instance.set("start_color", neon_color)
		
		container.add_child(pilone_instance)
		placed += 1
	
	print("Pylônes placés: ", placed, "/", pilone_count)

func _cleanup_previous() -> void:
	for child in get_children():
		child.queue_free()
