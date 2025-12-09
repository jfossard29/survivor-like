class_name Map3DBuilder
extends RefCounted

# Types de blocs
enum BlockType {
	FLOOR,    # Intérieur de plateforme
	SIDE,     # Côté de plateforme
	CORNER,   # Coin de plateforme
	RAMP      # Rampe
}

# Directions pour rotation
enum Direction {
	NORTH,  # -Z
	EAST,   # +X
	SOUTH,  # +Z
	WEST    # -X
}

# Construit la map 3D à partir de la grille
static func build_3d_map(
	grid: Array,
	platforms: Array,
	map_size: int,
	max_height: int,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary  # {BlockType: PackedScene}
) -> void:
	
	print("\n🏗️ === CONSTRUCTION 3D DE LA MAP ===")
	
	# 1. Générer le sol
	_generate_ground(map_size, bloc_size, container, block_scenes)
	
	# 2. Générer les plateformes niveau par niveau
	for y in range(max_height):
		var level_platforms = platforms.filter(func(p): return p.height == y)
		if level_platforms.is_empty():
			continue
		
		print("\n📦 Niveau Y=%d : %d plateforme(s)" % [y, level_platforms.size()])
		_generate_level(grid, level_platforms, y, map_size, bloc_size, container, block_scenes)
	
	# 3. Générer les rampes
	_generate_ramps(platforms, bloc_size, container, block_scenes)
	
	print("\n✅ Construction 3D terminée !")

# Génère le sol de base
static func _generate_ground(
	map_size: int,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary
) -> void:
	
	print("\n🟫 Génération du sol...")
	
	# Créer un grand plan pour le sol
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(map_size * bloc_size, map_size * bloc_size)
	ground.mesh = plane_mesh
	
	# Matériau basique
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.25, 0.2)  # Marron
	ground.material_override = material
	
	# Positionner au centre, légèrement en dessous de Y=0
	var center = Vector3(map_size * bloc_size / 2.0, -0.1, map_size * bloc_size / 2.0)
	ground.position = center
	ground.name = "Ground"
	
	# Ajouter collision
	var static_body = StaticBody3D.new()
	static_body.name = "GroundCollision"
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(map_size * bloc_size, 0.2, map_size * bloc_size)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	ground.add_child(static_body)
	
	container.add_child(ground)
	print("  ✅ Sol créé : %dx%d" % [map_size, map_size])

# Génère tous les blocs d'un niveau
static func _generate_level(
	grid: Array,
	level_platforms: Array,
	level: int,
	map_size: int,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary
) -> void:
	
	var blocks_created = 0
	
	# Pour chaque plateforme de ce niveau
	for platform in level_platforms:
		blocks_created += _generate_platform_blocks(
			grid, platform, level, bloc_size, container, block_scenes
		)
	
	print("  ✅ %d blocs créés" % blocks_created)

# Génère les blocs d'une plateforme
static func _generate_platform_blocks(
	grid: Array,
	platform,
	level: int,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary
) -> int:
	
	var blocks_count = 0
	
	# Parcourir toutes les cellules de la plateforme
	for x in range(platform.x, platform.x + platform.width):
		for z in range(platform.z, platform.z + platform.depth):
			# Vérifier que c'est bien une plateforme (pas une rampe intérieure)
			if grid[x][z][level] != 1:
				continue
			
			# Déterminer le type de bloc
			var block_type = _determine_block_type(platform, x, z)
			var rotation = _determine_rotation(platform, x, z, block_type)
			
			# Créer le bloc
			_create_block(
				block_type, rotation, x, z, level,
				bloc_size, container, block_scenes
			)
			
			blocks_count += 1
	
	return blocks_count

# Détermine le type de bloc (Corner, Side, Floor)
static func _determine_block_type(platform, x: int, z: int) -> BlockType:
	var is_left_edge = (x == platform.x)
	var is_right_edge = (x == platform.x + platform.width - 1)
	var is_top_edge = (z == platform.z)
	var is_bottom_edge = (z == platform.z + platform.depth - 1)
	
	# Compter le nombre de côtés qui sont des bords
	var edge_count = 0
	if is_left_edge: edge_count += 1
	if is_right_edge: edge_count += 1
	if is_top_edge: edge_count += 1
	if is_bottom_edge: edge_count += 1
	
	# Corner = 2 bords adjacents
	if edge_count >= 2:
		return BlockType.CORNER
	
	# Side = 1 bord
	if edge_count == 1:
		return BlockType.SIDE
	
	# Floor = aucun bord
	return BlockType.FLOOR

# Détermine la rotation du bloc
static func _determine_rotation(platform, x: int, z: int, block_type: BlockType) -> Direction:
	var is_left_edge = (x == platform.x)
	var is_right_edge = (x == platform.x + platform.width - 1)
	var is_top_edge = (z == platform.z)
	var is_bottom_edge = (z == platform.z + platform.depth - 1)
	
	match block_type:
		BlockType.CORNER:
			# Top-Left corner
			if is_top_edge and is_left_edge:
				return Direction.NORTH  # 0°
			# Top-Right corner
			elif is_top_edge and is_right_edge:
				return Direction.EAST   # 90°
			# Bottom-Right corner
			elif is_bottom_edge and is_right_edge:
				return Direction.SOUTH  # 180°
			# Bottom-Left corner
			elif is_bottom_edge and is_left_edge:
				return Direction.WEST   # 270°
		
		BlockType.SIDE:
			# Top side
			if is_top_edge:
				return Direction.NORTH
			# Right side
			elif is_right_edge:
				return Direction.EAST
			# Bottom side
			elif is_bottom_edge:
				return Direction.SOUTH
			# Left side
			elif is_left_edge:
				return Direction.WEST
	
	# Floor n'a pas de rotation spécifique
	return Direction.NORTH

# Crée un bloc 3D
static func _create_block(
	block_type: BlockType,
	rotation: Direction,
	grid_x: int,
	grid_z: int,
	level: int,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary
) -> void:
	
	# Récupérer la scène appropriée
	var scene = block_scenes.get(block_type)
	if not scene:
		push_error("Scène manquante pour le type de bloc : %d" % block_type)
		return
	
	# Instancier le bloc
	var block_instance = scene.instantiate()
	
	# Calculer la position 3D
	var pos_x = grid_x * bloc_size + bloc_size * 0.5
	var pos_y = level * bloc_size + bloc_size * 0.5  # Décalage d'un demi-bloc
	var pos_z = grid_z * bloc_size + bloc_size * 0.5
	block_instance.position = Vector3(pos_x, pos_y, pos_z)
	
	# Appliquer la rotation
	var rotation_y = 0.0
	match rotation:
		Direction.NORTH: rotation_y = PI / 2.0 # -Z : -90°
		Direction.EAST: rotation_y =  0       # +X : -180°
		Direction.SOUTH: rotation_y = -PI / 2.0  # +Z : +90°
		Direction.WEST: rotation_y = PI  		# -X : 0°
	
	block_instance.rotation.y = rotation_y
	
	# Nommer le bloc
	var type_name = ["Floor", "Side", "Corner", "Ramp"][block_type]
	block_instance.name = "%s_Y%d_[%d,%d]" % [type_name, level, grid_x, grid_z]
	
	container.add_child(block_instance)

# Génère toutes les rampes
static func _generate_ramps(
	platforms: Array,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary
) -> void:
	
	print("\n🔺 Génération des rampes...")
	var ramp_count = 0
	
	for platform in platforms:
		if platform.ramps.is_empty():
			continue
		
		for ramp_pos in platform.ramps:
			var ramp_direction = _determine_ramp_direction_with_parent(platform, ramp_pos)
			
			_create_ramp(
				ramp_pos.x, ramp_pos.y, platform.height,
				ramp_direction, bloc_size, container, block_scenes
			)
			
			ramp_count += 1
	
	print("  ✅ %d rampes créées" % ramp_count)

# Détermine la direction d'une rampe en tenant compte du parent
static func _determine_ramp_direction_with_parent(platform, ramp_pos: Vector2i) -> Direction:
	var ramp_x = ramp_pos.x
	var ramp_z = ramp_pos.y
	
	# CAS 1 : Rampe intérieure (dans la plateforme) - cas spéciaux
	if platform.contains_position(ramp_x, ramp_z):
		# C'est une rampe de déblocage ou alignée
		# Chercher la rampe parent à cette position
		if platform.parent and platform.parent.ramps:
			for parent_ramp in platform.parent.ramps:
				# Si une rampe parent est à la même position ou adjacente
				if (parent_ramp.x == ramp_x and parent_ramp.y == ramp_z):
					# Même direction que la rampe parent
					return _determine_ramp_direction(platform.parent, parent_ramp)
				
				# Vérifier si on est adjacent à une rampe parent
				var dx = abs(parent_ramp.x - ramp_x)
				var dz = abs(parent_ramp.y - ramp_z)
				if dx <= 1 and dz <= 1 and (dx + dz) == 1:
					# On est à côté d'une rampe parent, même direction
					return _determine_ramp_direction(platform.parent, parent_ramp)
		
		# Pas de rampe parent trouvée, déterminer selon le bord
		return _determine_ramp_direction_from_edge(platform, ramp_x, ramp_z)
	
	# CAS 2 : Rampe extérieure (normale)
	return _determine_ramp_direction(platform, ramp_pos)

# Détermine la direction selon le bord de la plateforme
static func _determine_ramp_direction_from_edge(platform, ramp_x: int, ramp_z: int) -> Direction:
	# Trouver quel bord est le plus proche
	if ramp_z == platform.z:
		return Direction.NORTH  # Bord nord
	elif ramp_z == platform.z + platform.depth - 1:
		return Direction.SOUTH  # Bord sud
	elif ramp_x == platform.x:
		return Direction.WEST   # Bord ouest
	elif ramp_x == platform.x + platform.width - 1:
		return Direction.EAST   # Bord est
	
	# Par défaut, trouver le bord le plus proche
	var dist_north = ramp_z - platform.z
	var dist_south = (platform.z + platform.depth - 1) - ramp_z
	var dist_west = ramp_x - platform.x
	var dist_east = (platform.x + platform.width - 1) - ramp_x
	
	var min_dist = min(dist_north, min(dist_south, min(dist_west, dist_east)))
	
	if min_dist == dist_north:
		return Direction.NORTH
	elif min_dist == dist_south:
		return Direction.SOUTH
	elif min_dist == dist_west:
		return Direction.WEST
	else:
		return Direction.EAST

# Détermine la direction d'une rampe
static func _determine_ramp_direction(platform, ramp_pos: Vector2i) -> Direction:
	var ramp_x = ramp_pos.x
	var ramp_z = ramp_pos.y
	
	# Vérifier quelle direction pointe vers la plateforme
	# Nord (-Z)
	if ramp_z < platform.z:
		return Direction.SOUTH  # Rampe monte vers le sud
	# Sud (+Z)
	elif ramp_z >= platform.z + platform.depth:
		return Direction.NORTH  # Rampe monte vers le nord
	# Ouest (-X)
	elif ramp_x < platform.x:
		return Direction.EAST   # Rampe monte vers l'est
	# Est (+X)
	elif ramp_x >= platform.x + platform.width:
		return Direction.WEST   # Rampe monte vers l'ouest
	
	# Si la rampe est DANS la plateforme (cas spéciaux)
	# Chercher la direction vers l'extérieur
	if ramp_z == platform.z:
		return Direction.NORTH  # Bord nord
	elif ramp_z == platform.z + platform.depth - 1:
		return Direction.SOUTH  # Bord sud
	elif ramp_x == platform.x:
		return Direction.WEST   # Bord ouest
	elif ramp_x == platform.x + platform.width - 1:
		return Direction.EAST   # Bord est
	
	return Direction.NORTH  # Fallback

# Crée une rampe 3D
static func _create_ramp(
	grid_x: int,
	grid_z: int,
	level: int,
	direction: Direction,
	bloc_size: float,
	container: Node3D,
	block_scenes: Dictionary
) -> void:
	
	var ramp_scene = block_scenes.get(BlockType.RAMP)
	if not ramp_scene:
		push_error("Scène de rampe manquante !")
		return
	
	var ramp_instance = ramp_scene.instantiate()
	
	# Position de la rampe
	# Les rampes montent d'un niveau complet (bloc_size)
	# Elles doivent être centrées verticalement pour arriver au milieu de la plateforme supérieure
	var pos_x = grid_x * bloc_size + bloc_size * 0.5
	var pos_y = level * bloc_size + bloc_size * 0.5  # Même calcul que les plateformes
	var pos_z = grid_z * bloc_size + bloc_size * 0.5
	
	ramp_instance.position = Vector3(pos_x, pos_y, pos_z)
	
	# Rotation de la rampe
	var rotation_y = 0.0
	match direction:
		Direction.NORTH: rotation_y = -PI / 2.0        # -Z : -90°
		Direction.EAST: rotation_y = PI        # +X : -180°
		Direction.SOUTH: rotation_y = PI / 2.0        # +Z : +90°
		Direction.WEST: rotation_y = 0 #PI / 2.0        # -X : 0°
	
	ramp_instance.rotation.y = rotation_y
	
	ramp_instance.name = "Ramp_Y%d_[%d,%d]" % [level, grid_x, grid_z]
	container.add_child(ramp_instance)
