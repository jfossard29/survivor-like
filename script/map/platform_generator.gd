class_name PlatformGenerator
extends RefCounted

static func generate_platforms(
	N: int,
	M: int,
	hm: Array,
	rng: RandomNumberGenerator,
	platform_coverage: float,
	min_platform_blocs: int,
	max_platform_blocs: int,
	max_attempts_place: int,
	bloc_gap: int,
	stacked_platform_chance: float,
	bloc_size: float,
	center: Vector3,
	container: Node3D
) -> Array:
	var placed_platforms := []
	var total_blocs = float(N) * float(M)
	var target_blocs = int(clamp(platform_coverage * total_blocs, 1, total_blocs))
	var blocs_placed = 0
	var attempts = 0
	
	# PHASE 1: Plateformes au sol
	while blocs_placed < target_blocs and attempts < max_attempts_place:
		attempts += 1
		var platform = _try_place_platform(
			N, M, hm, rng, 1,
			min_platform_blocs, max_platform_blocs, bloc_gap
		)
		if platform:
			placed_platforms.append(platform)
			blocs_placed += platform.w * platform.h
			_create_platform_collision(platform, bloc_size, center, container)
	
	# PHASE 2: Empilement
	var i = 0
	while i < placed_platforms.size():
		var base_plat = placed_platforms[i]
		i += 1
		
		if rng.randf() > stacked_platform_chance:
			continue
		
		var stacked = _try_stack_platform(
			base_plat, hm, rng,
			min_platform_blocs, max_platform_blocs, bloc_gap
		)
		if stacked:
			placed_platforms.append(stacked)
			_create_platform_collision(stacked, bloc_size, center, container)
	
	return placed_platforms

static func _try_place_platform(
	N: int,
	M: int,
	hm: Array,
	rng: RandomNumberGenerator,
	level: int,
	min_platform_blocs: int,
	max_platform_blocs: int,
	bloc_gap: int
) -> Variant:
	var max_w = min(max_platform_blocs, N)
	var max_h = min(max_platform_blocs, M)
	
	if max_w < min_platform_blocs or max_h < min_platform_blocs:
		return null
	
	var w = rng.randi_range(min_platform_blocs, max_w)
	var h = rng.randi_range(min_platform_blocs, max_h)
	
	if N - w < 0 or M - h < 0:
		return null
	
	var x0 = rng.randi_range(0, N - w)
	var z0 = rng.randi_range(0, M - h)
	
	# Vérifier collision
	for xi in range(max(0, x0 - bloc_gap), min(N, x0 + w + bloc_gap)):
		for zi in range(max(0, z0 - bloc_gap), min(M, z0 + h + bloc_gap)):
			if xi < hm.size() and zi < hm[xi].size() and hm[xi][zi] > 0:
				return null
	
	# Placer
	for xi in range(x0, x0 + w):
		for zi in range(z0, z0 + h):
			hm[xi][zi] = level
	
	return {"x": x0, "z": z0, "w": w, "h": h, "level": level}

# Détermine le côté où se trouve la rampe d'une plateforme
static func _get_ramp_side(plat: Dictionary, ramp_positions: Array) -> int:
	# Retourne : 0=gauche, 1=droite, 2=haut, 3=bas, -1=pas de rampe
	for ramp_pos in ramp_positions:
		if ramp_pos == null:
			continue
		
		var rx = int(ramp_pos.x)
		var rz = int(ramp_pos.y)
		
		# Vérifier si la rampe est adjacente à cette plateforme
		# Gauche (x - 1)
		if rx == plat.x - 1 and rz >= plat.z and rz < plat.z + plat.h:
			return 0
		# Droite (x + w)
		if rx == plat.x + plat.w and rz >= plat.z and rz < plat.z + plat.h:
			return 1
		# Haut (z - 1)
		if rz == plat.z - 1 and rx >= plat.x and rx < plat.x + plat.w:
			return 2
		# Bas (z + h)
		if rz == plat.z + plat.h and rx >= plat.x and rx < plat.x + plat.w:
			return 3
	
	return -1

# Vérifie qu'il y a au moins un espace libre sur un des 4 côtés de la plateforme empilée
# pour permettre l'accès par une rampe
static func _has_access_space(x0: int, z0: int, w: int, h: int, base_plat: Dictionary) -> bool:
	var base_x = base_plat.x
	var base_z = base_plat.z
	var base_w = base_plat.w
	var base_h = base_plat.h
	
	# Vérifier chaque côté de la plateforme empilée
	# Gauche : il faut au moins 1 bloc libre entre le bord gauche de la plateforme empilée et le bord de la base
	var left_space = x0 - base_x
	
	# Droite : il faut au moins 1 bloc libre entre le bord droit de la plateforme empilée et le bord de la base
	var right_space = (base_x + base_w) - (x0 + w)
	
	# Haut (Z-) : il faut au moins 1 bloc libre
	var top_space = z0 - base_z
	
	# Bas (Z+) : il faut au moins 1 bloc libre
	var bottom_space = (base_z + base_h) - (z0 + h)
	
	# Au moins un côté doit avoir un espace libre d'au moins 1 bloc
	return left_space >= 1 or right_space >= 1 or top_space >= 1 or bottom_space >= 1

static func _try_stack_platform(
	base_plat: Dictionary,
	hm: Array,
	rng: RandomNumberGenerator,
	min_platform_blocs: int,
	max_platform_blocs: int,
	bloc_gap: int
) -> Variant:
	# La plateforme empilée ne doit pas dépasser la base
	# Si elle fait la même taille, on laisse au moins 1 bloc pour les rampes
	var max_w = min(max_platform_blocs, base_plat.w - 1)
	var max_h = min(max_platform_blocs, base_plat.h - 1)
	
	if max_w < min_platform_blocs or max_h < min_platform_blocs:
		return null
	
	var w = rng.randi_range(min_platform_blocs, max_w)
	var h = rng.randi_range(min_platform_blocs, max_h)
	
	# Les plateformes empilées peuvent être collées au bord (offset = 0)
	# mais ne doivent pas dépasser
	var max_offset_x = base_plat.w - w
	var max_offset_z = base_plat.h - h
	
	if max_offset_x < 0 or max_offset_z < 0:
		return null
	
	var offset_x = rng.randi_range(0, max_offset_x)
	var offset_z = rng.randi_range(0, max_offset_z)
	
	var x0 = base_plat.x + offset_x
	var z0 = base_plat.z + offset_z
	
	# Vérifier qu'il reste au moins un accès libre sur un des 4 côtés
	if not _has_access_space(x0, z0, w, h, base_plat):
		return null
	
	var new_level = base_plat.level + 1
	
	# Mettre à jour la heightmap pour refléter le niveau le plus élevé
	for xi in range(x0, x0 + w):
		for zi in range(z0, z0 + h):
			hm[xi][zi] = max(hm[xi][zi], new_level)
	
	return {"x": x0, "z": z0, "w": w, "h": h, "level": new_level}

static func _create_platform_collision(
	plat: Dictionary,
	bloc_size: float,
	center: Vector3,
	container: Node3D
) -> void:
	var body = StaticBody3D.new()
	body.name = "Platform_L" + str(plat.level) + "_" + str(plat.x) + "_" + str(plat.z)
	body.collision_layer = 2
	body.collision_mask = 4
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	
	var width = plat.w * bloc_size
	var depth = plat.h * bloc_size
	shape.size = Vector3(width, bloc_size, depth)
	
	var x_pos = plat.x * bloc_size + width * 0.5
	# CORRECTION : Ajuster pour le nouveau center qui inclut bloc_size * 0.5
	var y_pos = plat.level * bloc_size  # Plus de -1, juste level * bloc_size
	var z_pos = plat.z * bloc_size + depth * 0.5
	
	body.position = Vector3(x_pos, y_pos, z_pos) - center
	collision.shape = shape
	body.add_child(collision)
	container.add_child(body)
