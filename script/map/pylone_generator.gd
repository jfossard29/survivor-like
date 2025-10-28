class_name PyloneGenerator
extends RefCounted

# Génère les pylônes sur la map
static func generate_pylones(
	count: int,
	N: int, M: int,
	hm: Array,
	bloc_size: float,
	rng: RandomNumberGenerator,
	container: Node3D,
	center: Vector3,
	ramp_positions: Array,
	pylone_path: String,
	shader_path: String,
	script_path: String,
	is_editor: bool
) -> int:
	# Vérifier que tous les fichiers existent
	if not ResourceLoader.exists(pylone_path):
		push_error("Fichier pylone non trouvé: " + pylone_path)
		return 0
	
	if not ResourceLoader.exists(shader_path):
		push_error("Shader pylone non trouvé: " + shader_path)
		return 0
	
	if not ResourceLoader.exists(script_path):
		push_error("Script pylone non trouvé: " + script_path)
		return 0
	
	# Charger les ressources
	var pilone_resource = load(pylone_path)
	var pylone_shader = load(shader_path)
	var pylone_script = load(script_path)
	
	var placed = 0
	var attempts = 0
	var max_attempts = count * 10
	
	while placed < count and attempts < max_attempts:
		attempts += 1
		
		var x = rng.randi_range(0, N - 1)
		var z = rng.randi_range(0, M - 1)
		var level = hm[x][z]
		
		# Ne placer que sur les plateformes (pas au sol)
		if level == 0:
			continue
		
		# Éviter les rampes
		if _is_on_ramp(x, z, ramp_positions):
			continue
		
		# Créer le pylône
		var pilone = _create_pylone(
			pilone_resource, pylone_shader, pylone_script,
			x, z, level, bloc_size, center, rng, placed
		)
		
		container.add_child(pilone)
		
		# Définir l'owner pour l'éditeur
		if is_editor:
			_set_owner_recursive(pilone, container.get_tree().edited_scene_root)
		
		placed += 1
	
	return placed

static func _is_on_ramp(x: int, z: int, ramp_positions: Array) -> bool:
	for ramp_pos in ramp_positions:
		if ramp_pos != null and int(ramp_pos.x) == x and int(ramp_pos.y) == z:
			return true
	return false

static func _create_pylone(
	pilone_resource: Resource,
	shader: Shader,
	script: Script,
	x: int, z: int, level: int,
	bloc_size: float,
	center: Vector3,
	rng: RandomNumberGenerator,
	index: int
) -> Node3D:
	# Instancier le pylône
	var pilone_instance: Node3D
	
	if pilone_resource is PackedScene:
		pilone_instance = pilone_resource.instantiate()
	else:
		# C'est un mesh direct (.vox)
		pilone_instance = Node3D.new()
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = pilone_resource
		mesh_inst.name = "PiloneMesh"
		pilone_instance.add_child(mesh_inst)
	
	pilone_instance.name = "Pilone_" + str(index)
	
	# Calculer la position
	var x_pos = x * bloc_size + bloc_size * 0.5
	var y_pos = (level * bloc_size) + bloc_size * 0.5
	var z_pos = z * bloc_size + bloc_size * 0.5
	pilone_instance.position = Vector3(x_pos, y_pos, z_pos) - center
	
	# Appliquer scale et rotation
	pilone_instance.scale = Vector3(0.5, 0.5, 0.5)
	pilone_instance.rotation_degrees.y = rng.randf_range(0.0, 360.0)
	
	# Ajouter collision
	_add_collision(pilone_instance)
	
	# Appliquer shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	_apply_shader_to_meshes(pilone_instance, shader_material)
	
	var beam = Node3D.new()
	beam.name = "LightBeam"
	beam.set_script(load("res://script/map/test_fesceau.gd"))
	beam.position = Vector3(0, 13, 0 )
	pilone_instance.add_child(beam)
	# Attacher le script
	pilone_instance.set_script(script)
	
	return pilone_instance

static func _add_collision(pilone: Node3D) -> void:
	var base_box = Vector3(8, 26, 8)  # Taille en unités du modèle
	
	var collision_body = StaticBody3D.new()
	collision_body.name = pilone.name + "_Body"
	collision_body.collision_layer = 2
	collision_body.collision_mask = 4
	collision_body.transform = Transform3D.IDENTITY
	collision_body.position = Vector3(0, base_box.y * 0.5 * pilone.scale.y, 0)
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var box_shape = BoxShape3D.new()
	box_shape.size = base_box
	collision_shape.shape = box_shape
	collision_shape.scale = pilone.scale
	
	collision_body.add_child(collision_shape)
	pilone.add_child(collision_body)

static func _apply_shader_to_meshes(node: Node, shader_material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		node.material_override = shader_material
	
	for child in node.get_children():
		_apply_shader_to_meshes(child, shader_material)

static func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node == owner:
		return
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
