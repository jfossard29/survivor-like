class_name PlatformGeneratorGrid
extends RefCounted

# Structure pour représenter une plateforme
class Platform:
	var x: int  # Position X de départ
	var z: int  # Position Z de départ
	var width: int  # Largeur (en X)
	var depth: int  # Profondeur (en Z)
	var height: int  # Niveau Y
	var ramps: Array = []  # Liste des positions de rampes [Vector2i(x, z), ...]
	var parent: Platform = null  # Référence vers la plateforme parent (si empilée)
	
	func _init(px: int, pz: int, w: int, d: int, h: int):
		x = px
		z = pz
		width = w
		depth = d
		height = h
	
	func _to_string() -> String:
		return "Platform[%d,%d | %dx%d @ Y=%d | %d rampes]" % [x, z, width, depth, height, ramps.size()]
	
	func contains_position(pos_x: int, pos_z: int) -> bool:
		return pos_x >= x and pos_x < x + width and pos_z >= z and pos_z < z + depth
	
	func is_on_edge(pos_x: int, pos_z: int) -> bool:
		if not contains_position(pos_x, pos_z):
			return false
		return (pos_x == x or pos_x == x + width - 1 or 
				pos_z == z or pos_z == z + depth - 1)

# Génère des plateformes dans la grille
static func generate_platforms(
	grid: Array,
	map_size: int,
	max_height: int,
	rng: RandomNumberGenerator,
	config: Dictionary
) -> Array:
	var platforms: Array[Platform] = []
	
	print("\n🏗️ === GÉNÉRATION DES PLATEFORMES ===")
	print("Configuration:")
	print("  • Couverture cible: %.1f%%" % (config.platform_coverage * 100))
	print("  • Taille min: %dx%d" % [config.min_size, config.min_size])
	print("  • Taille max: %dx%d" % [config.max_size, config.max_size])
	print("  • Gap minimum: %d" % config.min_gap)
	print("  • Chance d'empilement: %.0f%%" % (config.stacking_chance * 100))
	
	var total_cells = map_size * map_size
	var target_cells = int(total_cells * config.platform_coverage)
	
	# ========================================
	# PHASE 1: GÉNÉRER TOUTES LES PLATEFORMES
	# ========================================
	print("\n🔷 PHASE 1: Génération des plateformes")
	
	# 1A: Plateformes au sol (Y=0)
	print("\n  1A - Plateformes au sol (Y=0)")
	var filled_cells = 0
	var attempts = 0
	
	while filled_cells < target_cells and attempts < config.max_attempts:
		attempts += 1
		
		var platform = _try_place_platform(
			grid, map_size, max_height, rng,
			0, config.min_size, config.max_size, config.min_gap
		)
		
		if platform:
			platforms.append(platform)
			filled_cells += platform.width * platform.depth
			_fill_grid(grid, platform)
			
			if platforms.size() % 5 == 0:
				print("    ✓ %d plateformes | %d/%d cellules (%.1f%%)" % [
					platforms.size(), filled_cells, target_cells,
					(float(filled_cells) / target_cells) * 100
				])
	
	print("\n  ✅ Plateformes sol: %d créées" % platforms.size())
	
	# 1B: Empilement de plateformes
	if config.stacking_chance > 0:
		print("\n  1B - Empilement de plateformes")
		var base_platforms = platforms.duplicate()
		var stacked_count = 0
		
		# EMPILEMENT NIVEAU 1 (Y=1)
		for base_platform in base_platforms:
			if base_platform.height != 0:  # Seulement depuis Y=0
				continue
				
			if rng.randf() > config.stacking_chance:
				continue
			
			var stacked = _try_stack_platform(
				grid, map_size, max_height, rng,
				base_platform, config.min_size, config.max_size
			)
			
			if stacked:
				stacked.parent = base_platform
				platforms.append(stacked)
				_fill_grid(grid, stacked)
				stacked_count += 1
				
				if stacked_count % 3 == 0:
					print("    ✓ %d plateformes Y=1 empilées" % stacked_count)
		
		var y1_count = stacked_count
		print("\n  ✅ Plateformes Y=1: %d" % y1_count)
		
		# EMPILEMENT NIVEAU 2+ (Y=2, Y=3, etc.)
		var current_level = 1
		while current_level < max_height - 1:
			var level_platforms = platforms.filter(func(p): return p.height == current_level)
			if level_platforms.is_empty():
				break
			
			var level_stacked = 0
			for level_platform in level_platforms:
				if rng.randf() > config.stacking_chance:
					continue
				
				var stacked = _try_stack_platform(
					grid, map_size, max_height, rng,
					level_platform, config.min_size, config.max_size
				)
				
				if stacked:
					stacked.parent = level_platform
					platforms.append(stacked)
					_fill_grid(grid, stacked)
					level_stacked += 1
					stacked_count += 1
			
			if level_stacked > 0:
				print("\n  ✅ Plateformes Y=%d: %d" % [current_level + 1, level_stacked])
			else:
				break  # Arrêter si aucun empilement à ce niveau
			
			current_level += 1
		
		print("\n  ✅ Total plateformes empilées: %d" % stacked_count)
	
	print("\n✅ PHASE 1 terminée: %d plateformes au total" % platforms.size())
	
	# ========================================
	# PHASE 2: GÉNÉRER LES RAMPES
	# ========================================
	print("\n🔶 PHASE 2: Génération des rampes")
	_generate_all_ramps(grid, map_size, platforms, rng)
	
	print("\n🎉 === GÉNÉRATION TERMINÉE ===\n")
	return platforms

# ========================================
# PHASE 2: GÉNÉRATION DES RAMPES
# ========================================
static func _generate_all_ramps(
	grid: Array,
	map_size: int,
	platforms: Array,
	rng: RandomNumberGenerator
) -> void:
	
	# Trier les plateformes par niveau (Y=0 d'abord, puis Y=1, etc.)
	var sorted_platforms = platforms.duplicate()
	sorted_platforms.sort_custom(func(a, b): return a.height < b.height)
	
	for platform in sorted_platforms:
		if platform.height == 0:
			# Plateformes au sol : rampes vers l'extérieur
			_generate_ground_ramps(grid, map_size, platform, rng)
		else:
			# Plateformes en hauteur : rampes depuis le parent
			_generate_elevated_ramps(grid, map_size, platform, rng)

# Génère des rampes pour une plateforme au sol (Y=0)
static func _generate_ground_ramps(
	grid: Array,
	map_size: int,
	platform: Platform,
	rng: RandomNumberGenerator
) -> void:
	
	var available_positions = _find_ground_ramp_positions(grid, map_size, platform)
	
	if available_positions.is_empty():
		print("  ⚠️ Y=%d [%d,%d]: Aucune position valide pour rampe" % 
			[platform.height, platform.x, platform.z])
		return
	
	# Placer 1-2 rampes
	available_positions.shuffle()
	var num_ramps = min(rng.randi_range(1, 2), available_positions.size())
	
	for i in range(num_ramps):
		var pos = available_positions[i]
		platform.ramps.append(pos)
		grid[pos.x][pos.y][platform.height] = 2
		print("  🔺 Y=%d: Rampe sol placée à [%d,%d]" % [platform.height, pos.x, pos.y])

# Génère des rampes pour une plateforme en hauteur
static func _generate_elevated_ramps(
	grid: Array,
	map_size: int,
	platform: Platform,
	rng: RandomNumberGenerator
) -> void:
	
	if not platform.parent:
		print("  ⚠️ Y=%d [%d,%d]: Pas de parent trouvé!" % 
			[platform.height, platform.x, platform.z])
		return
	
	# ÉTAPE 1: Vérifier si des rampes du parent sont bloquées
	_check_and_unblock_parent_ramps(grid, platform)
	
	# ÉTAPE 2: Cas spécial - Plateforme de même taille que le parent
	if platform.width == platform.parent.width and platform.depth == platform.parent.depth:
		print("  📦 Y=%d [%d,%d]: Même taille que parent → rampes alignées" % 
			[platform.height, platform.x, platform.z])
		_create_aligned_ramps(grid, platform)
		
		# Si des rampes ont été créées, on s'arrête ici
		if not platform.ramps.is_empty():
			return
	
	# ÉTAPE 3: Si pas de rampes créées, chercher des positions valides
	var available_positions = _find_elevated_ramp_positions(grid, map_size, platform)
	
	if available_positions.is_empty():
		print("  ⚠️ Y=%d [%d,%d]: Aucune position valide → création forcée" % 
			[platform.height, platform.x, platform.z])
		_force_create_ramp(grid, platform, rng)
		return
	
	# Placer 1-2 rampes EXTÉRIEURES (on ne les marque PAS dans la grille au niveau enfant)
	available_positions.shuffle()
	var num_ramps = min(rng.randi_range(1, 2), available_positions.size())
	
	for i in range(num_ramps):
		var pos = available_positions[i]
		platform.ramps.append(pos)
		# NE PAS marquer dans la grille - les rampes extérieures existent au niveau parent
		print("  🔺 Y=%d: Rampe extérieure à [%d,%d] (sur parent Y=%d)" % 
			[platform.height, pos.x, pos.y, platform.parent.height])

# Vérifie si des rampes du parent sont bloquées et crée des rampes de déblocage
static func _check_and_unblock_parent_ramps(grid: Array, platform: Platform) -> void:
	var parent = platform.parent
	
	# Pour chaque rampe du parent
	for parent_ramp in parent.ramps:
		# La rampe est à l'EXTÉRIEUR de la plateforme parent
		# On doit trouver LA CELLULE DE LA PLATEFORME PARENT qui donne accès à cette rampe
		var parent_access_cell = _find_parent_cell_leading_to_ramp(parent, parent_ramp)
		
		if parent_access_cell == null:
			# Pas de cellule d'accès trouvée (ne devrait pas arriver)
			continue
		
		# Si cette cellule d'accès du parent est recouverte par l'enfant
		if platform.contains_position(parent_access_cell.x, parent_access_cell.y):
			# L'enfant BLOQUE l'accès à la rampe parent
			# On doit créer une rampe sur l'enfant à cette position
			var ramp_pos = Vector2i(parent_access_cell.x, parent_access_cell.y)
			
			if not platform.ramps.has(ramp_pos):
				platform.ramps.append(ramp_pos)
				grid[ramp_pos.x][ramp_pos.y][platform.height] = 2
				print("  🔧 Rampe de déblocage: [%d,%d] Y=%d (débloque accès à rampe parent [%d,%d])" % 
					[ramp_pos.x, ramp_pos.y, platform.height, parent_ramp.x, parent_ramp.y])

# Trouve la cellule de la plateforme parent qui mène à une rampe
static func _find_parent_cell_leading_to_ramp(parent: Platform, ramp_pos: Vector2i) -> Variant:
	# La rampe est normalement adjacente à une cellule de bord de la plateforme parent
	# On cherche cette cellule de bord
	var directions = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1)
	]
	
	for dir in directions:
		var check_x = ramp_pos.x - dir.x  # Direction inverse (de la rampe vers la plateforme)
		var check_z = ramp_pos.y - dir.y
		
		# Cette cellule appartient-elle à la plateforme parent ?
		if parent.contains_position(check_x, check_z):
			# C'est une cellule de bord qui mène à la rampe
			return Vector2i(check_x, check_z)
	
	return null

# Trouve les positions valides pour rampes au sol
static func _find_ground_ramp_positions(
	grid: Array,
	map_size: int,
	platform: Platform
) -> Array:
	
	var positions = []
	
	# Parcourir le périmètre
	for x in range(platform.x, platform.x + platform.width):
		for z in range(platform.z, platform.z + platform.depth):
			if not platform.is_on_edge(x, z):
				continue
			
			# Vérifier les 4 directions
			var directions = [
				Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(0, -1), Vector2i(0, 1)
			]
			
			for dir in directions:
				var ramp_x = x + dir.x
				var ramp_z = z + dir.y
				
				# Hors limites ?
				if ramp_x < 0 or ramp_x >= map_size or ramp_z < 0 or ramp_z >= map_size:
					continue
				
				# Case déjà occupée ?
				if grid[ramp_x][ramp_z][0] != 0:
					continue
				
				# Vérifier 2 cases libres devant
				if not _check_two_spaces_free(grid, map_size, ramp_x, ramp_z, dir):
					continue
				
				var pos = Vector2i(ramp_x, ramp_z)
				if not positions.has(pos):
					positions.append(pos)
	
	return positions

# Trouve les positions valides pour rampes en hauteur
static func _find_elevated_ramp_positions(
	grid: Array,
	map_size: int,
	platform: Platform
) -> Array:
	
	var positions = []
	var parent = platform.parent
	
	# Parcourir le périmètre de la plateforme enfant
	for x in range(platform.x, platform.x + platform.width):
		for z in range(platform.z, platform.z + platform.depth):
			# Vérifier SEULEMENT les bords
			if not platform.is_on_edge(x, z):
				continue
			
			# Vérifier les 4 directions EXTÉRIEURES
			var directions = [
				Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(0, -1), Vector2i(0, 1)
			]
			
			for dir in directions:
				var ramp_x = x + dir.x
				var ramp_z = z + dir.y
				
				# Hors limites ?
				if ramp_x < 0 or ramp_x >= map_size or ramp_z < 0 or ramp_z >= map_size:
					continue
				
				# RÈGLE : La rampe doit être EN DEHORS de la plateforme enfant
				if platform.contains_position(ramp_x, ramp_z):
					continue
				
				# La rampe ne doit pas déjà exister au niveau actuel
				if grid[ramp_x][ramp_z][platform.height] != 0:
					continue
				
				# La rampe doit reposer sur le PARENT (niveau inférieur)
				var parent_level = platform.height - 1
				var parent_cell = grid[ramp_x][ramp_z][parent_level]
				
				# Doit être sur le parent (1=plateforme, 2=rampe)
				if parent_cell == 0:
					continue
				
				var pos = Vector2i(ramp_x, ramp_z)
				if not positions.has(pos):
					positions.append(pos)
	
	return positions

# Crée des rampes alignées avec celles du parent (plateforme même taille)
static func _create_aligned_ramps(grid: Array, platform: Platform) -> void:
	var parent = platform.parent
	
	# Pour chaque rampe du parent
	for parent_ramp in parent.ramps:
		# CAS 1: La rampe du parent est RECOUVERTE par l'enfant
		# → On crée une rampe au MÊME endroit sur l'enfant
		if platform.contains_position(parent_ramp.x, parent_ramp.y):
			var ramp_pos = Vector2i(parent_ramp.x, parent_ramp.y)
			
			if not platform.ramps.has(ramp_pos):
				platform.ramps.append(ramp_pos)
				grid[ramp_pos.x][ramp_pos.y][platform.height] = 2
				print("    🔗 Rampe alignée (recouvrement): [%d,%d] Y=%d" % 
					[ramp_pos.x, ramp_pos.y, platform.height])

# Trouve la cellule de plateforme adjacente à une rampe
static func _find_adjacent_platform_cell(platform: Platform, ramp_pos: Vector2i) -> Variant:
	# La rampe est à l'extérieur, on cherche la cellule de bord la plus proche
	var directions = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1)
	]
	
	for dir in directions:
		var check_x = ramp_pos.x + dir.x
		var check_z = ramp_pos.y + dir.y
		
		# Cette cellule est-elle sur le bord de la plateforme ?
		if platform.contains_position(check_x, check_z) and platform.is_on_edge(check_x, check_z):
			return Vector2i(check_x, check_z)
	
	return null

# Force la création d'une rampe (dernier recours)
static func _force_create_ramp(
	grid: Array,
	platform: Platform,
	rng: RandomNumberGenerator
) -> void:
	
	var parent = platform.parent
	
	# PRIORITÉ 1 : Chercher une position EXTÉRIEURE valide
	var external_positions = []
	
	for x in range(platform.x, platform.x + platform.width):
		for z in range(platform.z, platform.z + platform.depth):
			if not platform.is_on_edge(x, z):
				continue
			
			var directions = [
				Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(0, -1), Vector2i(0, 1)
			]
			
			for dir in directions:
				var ramp_x = x + dir.x
				var ramp_z = z + dir.y
				
				# Hors limites ou déjà dans l'enfant ?
				if ramp_x < 0 or ramp_x >= grid.size() or ramp_z < 0 or ramp_z >= grid[0].size():
					continue
				if platform.contains_position(ramp_x, ramp_z):
					continue
				
				# Déjà occupé ?
				if grid[ramp_x][ramp_z][platform.height] != 0:
					continue
				
				# Repose sur le parent ?
				var parent_level = platform.height - 1
				if grid[ramp_x][ramp_z][parent_level] != 0:
					external_positions.append(Vector2i(ramp_x, ramp_z))
	
	if not external_positions.is_empty():
		external_positions.shuffle()
		var chosen = external_positions[0]
		platform.ramps.append(chosen)
		# NE PAS marquer dans la grille - rampe extérieure
		print("    🔧 Rampe forcée (extérieure): [%d,%d] sur parent Y=%d" % 
			[chosen.x, chosen.y, parent.height])
		return
	
	# PRIORITÉ 2 : Remplacer un bloc de bord par une rampe INTÉRIEURE
	var edge_positions = []
	for x in range(platform.x, platform.x + platform.width):
		for z in range(platform.z, platform.z + platform.depth):
			if platform.is_on_edge(x, z):
				edge_positions.append(Vector2i(x, z))
	
	if edge_positions.is_empty():
		print("    ❌ Impossible de forcer une rampe (pas de bord)!")
		return
	
	edge_positions.shuffle()
	var chosen = edge_positions[0]
	
	platform.ramps.append(chosen)
	grid[chosen.x][chosen.y][platform.height] = 2
	print("    🔧 Rampe forcée (intérieure): [%d,%d] Y=%d (remplacement bloc)" % 
		[chosen.x, chosen.y, platform.height])

# Vérifie que 2 cases sont libres devant la rampe
static func _check_two_spaces_free(
	grid: Array,
	map_size: int,
	ramp_x: int,
	ramp_z: int,
	dir: Vector2i
) -> bool:
	
	for i in range(1, 3):
		var check_x = ramp_x + dir.x * i
		var check_z = ramp_z + dir.y * i
		
		if check_x < 0 or check_x >= map_size or check_z < 0 or check_z >= map_size:
			return false
		
		if grid[check_x][check_z][0] != 0:
			return false
	
	return true

# ========================================
# PLACEMENT DES PLATEFORMES
# ========================================

static func _try_place_platform(
	grid: Array,
	map_size: int,
	max_height: int,
	rng: RandomNumberGenerator,
	level: int,
	min_size: int,
	max_size: int,
	min_gap: int
) -> Platform:
	
	var width = rng.randi_range(min_size, min(max_size, map_size))
	var depth = rng.randi_range(min_size, min(max_size, map_size))
	
	if map_size - width < 0 or map_size - depth < 0:
		return null
	
	var x = rng.randi_range(0, map_size - width)
	var z = rng.randi_range(0, map_size - depth)
	
	if not _check_space_available(grid, map_size, x, z, width, depth, level, min_gap):
		return null
	
	return Platform.new(x, z, width, depth, level)

static func _check_space_available(
	grid: Array,
	map_size: int,
	x: int, z: int,
	width: int, depth: int,
	level: int,
	min_gap: int
) -> bool:
	
	var check_x_start = max(0, x - min_gap)
	var check_x_end = min(map_size, x + width + min_gap)
	var check_z_start = max(0, z - min_gap)
	var check_z_end = min(map_size, z + depth + min_gap)
	
	for cx in range(check_x_start, check_x_end):
		for cz in range(check_z_start, check_z_end):
			if grid[cx][cz][level] != 0:
				return false
	
	return true

static func _try_stack_platform(
	grid: Array,
	map_size: int,
	max_height: int,
	rng: RandomNumberGenerator,
	base_platform: Platform,
	min_size: int,
	max_size: int
) -> Platform:
	
	var new_level = base_platform.height + 1
	
	if new_level >= max_height:
		return null
	
	# RÈGLE : Taille minimale 2x2 pour éviter les plateformes trop petites
	var min_width = max(2, min_size)
	var min_depth = max(2, min_size)
	
	# La plateforme enfant doit faire au moins 2x2
	# Et ne peut pas dépasser la taille du parent
	var max_width = base_platform.width
	var max_depth = base_platform.depth
	
	# Si le parent est trop petit (moins de 2x2), on ne peut pas empiler
	if max_width < min_width or max_depth < min_depth:
		return null
	
	var width = rng.randi_range(min_width, max_width)
	var depth = rng.randi_range(min_depth, max_depth)
	
	var max_offset_x = base_platform.width - width
	var max_offset_z = base_platform.depth - depth
	
	var offset_x = rng.randi_range(0, max_offset_x) if max_offset_x > 0 else 0
	var offset_z = rng.randi_range(0, max_offset_z) if max_offset_z > 0 else 0
	
	var x = base_platform.x + offset_x
	var z = base_platform.z + offset_z
	
	# Vérifier que l'espace est libre
	for cx in range(x, x + width):
		for cz in range(z, z + depth):
			if grid[cx][cz][new_level] != 0:
				return null
			if grid[cx][cz][base_platform.height] != 1:
				return null
	
	return Platform.new(x, z, width, depth, new_level)

static func _fill_grid(grid: Array, platform: Platform) -> void:
	for x in range(platform.x, platform.x + platform.width):
		for z in range(platform.z, platform.z + platform.depth):
			# Marquer comme plateforme (1)
			# Les rampes seront marquées plus tard (2)
			grid[x][z][platform.height] = 1
	
	print("    🔧 Plateforme Y=%d: pos[%d,%d] size[%dx%d]" % [
		platform.height, platform.x, platform.z,
		platform.width, platform.depth
	])
