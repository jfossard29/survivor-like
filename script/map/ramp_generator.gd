class_name RampGenerator
extends RefCounted

# Génère des rampes entre les plateformes
static func generate_ramps(
	platforms: Array,
	hm: Array,
	N: int,
	M: int,
	bloc_size: float,
	bloc_gap: int,
	rng: RandomNumberGenerator,
	container: Node3D,
	center: Vector3
) -> Array:
	var ramp_positions = []
	
	for plat in platforms:
		var ramp_pos = _generate_ramp_for_platform(
			plat.x, plat.z, plat.w, plat.h, plat.level,
			hm, N, M, bloc_size, bloc_gap, rng, container, center, ramp_positions
		)
		if ramp_pos != null:
			ramp_positions.append(ramp_pos)
	
	return ramp_positions

static func _generate_ramp_for_platform(
	x0: int, z0: int, w: int, h: int, level: int,
	hm: Array, N: int, M: int,
	bloc_size: float, bloc_gap: int,
	rng: RandomNumberGenerator,
	container: Node3D,
	center: Vector3,
	existing_ramps: Array
) -> Variant:
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	directions.shuffle()
	
	for dir in directions:
		var nx = x0
		var nz = z0
		
		if dir.x > 0:
			nx = x0 + w
			nz = z0 + rng.randi_range(0, h - 1)
		elif dir.x < 0:
			nx = x0 - 1
			nz = z0 + rng.randi_range(0, h - 1)
		elif dir.y > 0:
			nx = x0 + rng.randi_range(0, w - 1)
			nz = z0 + h
		elif dir.y < 0:
			nx = x0 + rng.randi_range(0, w - 1)
			nz = z0 - 1
		
		# ✅ Vérifier que la rampe n'est pas sur le bord de la map
		if nx <= 0 or nx >= N - 1 or nz <= 0 or nz >= M - 1:
			continue
		
		if nx >= 0 and nx < N and nz >= 0 and nz < M:
			var neighbor_level = hm[nx][nz]
			
			# Vérifier que le voisin est au niveau inférieur
			if neighbor_level == level - 1:
				# ✅ Vérifier que ce n'est pas dans un bloc_gap
				if _is_in_gap(nx, nz, hm, N, M, bloc_gap):
					continue
				
				# ✅ Vérifier qu'il n'y a pas déjà une rampe du même niveau adjacente
				if _has_adjacent_ramp_same_level(nx, nz, level, existing_ramps, hm):
					continue
				
				# Tout est OK, créer la rampe
				_add_ramp(Vector3(nx, 0, nz), dir, bloc_size, level, container, center)
				return Vector2(nx, nz)
	
	return null

static func _add_ramp(
	origin: Vector3,
	dir: Vector2,
	bloc_size: float,
	level: int,
	container: Node3D,
	center: Vector3
) -> void:
	# Charger la scène de rampe
	var stairs_scene = load("res://scenes/Stairs.tscn")
	if not stairs_scene:
		push_error("Impossible de charger Stairs.tscn")
		return
	
	var stairs = stairs_scene.instantiate()
	stairs.name = "Ramp_" + str(origin.x) + "_" + str(origin.z)
	var ramp_ground_offset := 0.5
	# La rampe est placée sur le bloc de niveau inférieur (level - 1)
	# et monte vers le bloc de niveau supérieur (level)
	var base_height = (level * bloc_size) - (bloc_size * 0.5)

	# Position de base centrée sur la case
	var x_pos = origin.x * bloc_size + bloc_size * 0.5
	var z_pos = origin.z * bloc_size + bloc_size * 0.5
	
	# Décaler la rampe de la moitié d'un bloc dans la direction de montée
	# pour qu'elle repose correctement sur le sol et se connecte à la plateforme
	x_pos += dir.x * bloc_size * 0.45
	z_pos += dir.y * bloc_size * 0.45
	
	stairs.position = Vector3(x_pos, base_height, z_pos) - center
	
	# Calculer la rotation selon la direction
	var rotation_y = 0.0
	if dir.x > 0:      # Droite
		rotation_y = 90.0
	elif dir.x < 0:    # Gauche
		rotation_y = -90.0
	elif dir.y > 0:    # Haut (Z+)
		rotation_y = 0.0
	elif dir.y < 0:    # Bas (Z-)
		rotation_y = 180.0
	
	stairs.rotation_degrees = Vector3(0, rotation_y, 0)
	
	container.add_child(stairs)

# Vérifie si la position est dans un gap entre plateformes
static func _is_in_gap(x: int, z: int, hm: Array, N: int, M: int, bloc_gap: int) -> bool:
	if bloc_gap <= 0:
		return false
	
	var current_level = hm[x][z]
	
	# Vérifier si c'est un gap : pas de bloc ET entouré de blocs
	if current_level != 0:
		return false
	
	# Vérifier les 4 directions adjacentes
	var adjacent_blocks = 0
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	
	for dir in directions:
		var nx = x + int(dir.x)
		var nz = z + int(dir.y)
		
		if nx >= 0 and nx < N and nz >= 0 and nz < M:
			if hm[nx][nz] > 0:
				adjacent_blocks += 1
	
	# Si au moins 2 côtés ont des blocs, c'est probablement un gap
	return adjacent_blocks >= 2

# Vérifie s'il y a une rampe du même niveau adjacente
static func _has_adjacent_ramp_same_level(
	x: int, z: int, level: int,
	existing_ramps: Array,
	hm: Array
) -> bool:
	# Vérifier les 8 cases autour (diagonales incluses)
	var offsets = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 0),                   Vector2(1, 0),
		Vector2(-1, 1),  Vector2(0, 1),  Vector2(1, 1)
	]
	
	for offset in offsets:
		var check_pos = Vector2(x, z) + offset
		
		# Vérifier si une rampe existe déjà à cette position
		for ramp_pos in existing_ramps:
			if ramp_pos == null:
				continue
			
			if int(ramp_pos.x) == int(check_pos.x) and int(ramp_pos.y) == int(check_pos.y):
				# Vérifier que cette rampe est du même niveau
				# Une rampe se trouve sur un bloc de niveau inférieur, donc on vérifie level-1
				var ramp_level = hm[int(ramp_pos.x)][int(ramp_pos.y)] + 1
				if ramp_level == level:
					return true
	
	return false
