@tool
extends Node3D

# paramètres
@export var map_size: int = 100  # Taille réelle de la map en unités
@export var tile_size: float = 2.0
@export var platform_height: float = 5.0
@export var platform_coverage: float = 0.06
@export var min_platform_tiles: int = 4
@export var max_platform_tiles: int = 20
@export var max_attempts_place: int = 3000
@export var seed: int = 0
@export var tile_gap: int = 2
@export var stacked_platform_chance: float = 0.5  # 50% de chance d'empiler
@export var auto_generate_on_play: bool = true  # Génère automatiquement au lancement
# exported property with setter/getter
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
		# En mode jeu, génère automatiquement si activé
		if auto_generate_on_play:
			generate()
		print("MapGenerator ready (game mode).")

func generate() -> void:
	print("Génération exécutée depuis l'éditeur.")
	_cleanup_previous()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.001, 0.107, 0.0, 0.502)  # gris clair, alpha 0.5
	
	# Calcul du nombre de tuiles basé sur map_size et tile_size
	var N = max(1, int(floor(float(map_size) / tile_size)))
	var M = N

	var rng = RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

	# Hauteur initiale (stocke maintenant le niveau de hauteur)
	var hm := []
	for x in range(N + 1):
		var col := []
		for z in range(M + 1):
			col.append(0.0)
		hm.append(col)

	# Liste des plateformes placées pour l'empilement
	var placed_platforms := []

	# Cible de tuiles à couvrir (niveau 0 uniquement)
	var total_tiles = float(N) * float(M)
	var target_tiles = int(clamp(platform_coverage * total_tiles, 1, total_tiles))

	var tiles_placed = 0
	var attempts = 0
	
	# PHASE 1: Placement des plateformes au sol
	while tiles_placed < target_tiles and attempts < max_attempts_place:
		attempts += 1
		var w = rng.randi_range(min_platform_tiles, max_platform_tiles)
		var h = rng.randi_range(min_platform_tiles, max_platform_tiles)
		if w > N: w = N
		if h > M: h = M
		var x0 = rng.randi_range(0, N - w)
		var z0 = rng.randi_range(0, M - h)

		# Vérifie qu'on respecte l'espacement
		var ok = true
		for xi in range(max(0, x0 - tile_gap), min(N, x0 + w + tile_gap)):
			for zi in range(max(0, z0 - tile_gap), min(M, z0 + h + tile_gap)):
				if hm[xi][zi] > 0.0:
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue

		# Place la plateforme niveau 1
		for xi in range(x0, x0 + w):
			for zi in range(z0, z0 + h):
				hm[xi][zi] = platform_height
				tiles_placed += 1

		# Stocke la plateforme pour empilement potentiel
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
		
		# 50% de chance d'empiler
		if rng.randf() > stacked_platform_chance:
			continue
		
		# Essayer de placer une plateforme plus petite sur celle-ci
		var max_w = base_plat.w - tile_gap * 2
		var max_h = base_plat.h - tile_gap * 2
		
		if max_w < min_platform_tiles or max_h < min_platform_tiles:
			continue  # Plateforme de base trop petite
		
		var w = rng.randi_range(min_platform_tiles, min(max_platform_tiles, max_w))
		var h = rng.randi_range(min_platform_tiles, min(max_platform_tiles, max_h))
		
		# Position aléatoire sur la plateforme de base (avec marge)
		var offset_x = rng.randi_range(tile_gap, base_plat.w - w - tile_gap)
		var offset_z = rng.randi_range(tile_gap, base_plat.h - h - tile_gap)
		
		var x0 = base_plat.x + offset_x
		var z0 = base_plat.z + offset_z
		var new_level = base_plat.level + 1
		var new_height = new_level * platform_height
		
		# Place la plateforme empilée
		for xi in range(x0, x0 + w):
			for zi in range(z0, z0 + h):
				hm[xi][zi] = new_height
		
		# Stocke pour potentiel empilement supplémentaire
		placed_platforms.append({
			"x": x0,
			"z": z0,
			"w": w,
			"h": h,
			"level": new_level
		})

	# Créer le StaticBody3D principal
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = NAME_BODY
	sb.collision_layer = 2  # Layer 2
	sb.collision_mask = 4   # Mask 4
	sb.add_to_group("terrain")
	var center = Vector3(N * tile_size * 0.5, 0, M * tile_size * 0.5)

	# Construction du mesh avec murs droits
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(N):
		for z in range(M):
			var y = float(hm[x][z])
			var p00 = Vector3(x * tile_size, y, z * tile_size)
			var p10 = Vector3((x + 1) * tile_size, y, z * tile_size)
			var p11 = Vector3((x + 1) * tile_size, y, (z + 1) * tile_size)
			var p01 = Vector3(x * tile_size, y, (z + 1) * tile_size)

			# Top
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p11)
			st.add_vertex(p01)
			st.add_vertex(p00)

			if y > 0.0:
				var bottom = 0.0
				var bp00 = Vector3(x * tile_size, bottom, z * tile_size)
				var bp10 = Vector3((x + 1) * tile_size, bottom, z * tile_size)
				var bp11 = Vector3((x + 1) * tile_size, bottom, (z + 1) * tile_size)
				var bp01 = Vector3(x * tile_size, bottom, (z + 1) * tile_size)

				# -X
				st.add_vertex(bp00)
				st.add_vertex(p00)
				st.add_vertex(p01)
				st.add_vertex(p01)
				st.add_vertex(bp01)
				st.add_vertex(bp00)

				# +X
				st.add_vertex(p10)
				st.add_vertex(bp10)
				st.add_vertex(bp11)
				st.add_vertex(bp11)
				st.add_vertex(p11)
				st.add_vertex(p10)

				# -Z
				st.add_vertex(bp00)
				st.add_vertex(bp10)
				st.add_vertex(p10)
				st.add_vertex(p10)
				st.add_vertex(p00)
				st.add_vertex(bp00)

				# +Z
				st.add_vertex(p01)
				st.add_vertex(p11)
				st.add_vertex(bp11)
				st.add_vertex(bp11)
				st.add_vertex(bp01)
				st.add_vertex(p01)

	st.generate_normals()
	var mesh = st.commit() as ArrayMesh

	# Créer le MeshInstance3D pour les plateformes
	var mi = MeshInstance3D.new()
	mi.name = "PlatformsMesh"
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = -center
	sb.add_child(mi)

	# Créer la collision pour le mesh des plateformes
	var cs_platforms = CollisionShape3D.new()
	cs_platforms.name = "PlatformsCollision"
	if mesh.get_surface_count() > 0:
		var arrs = mesh.surface_get_arrays(0)
		if arrs.size() > Mesh.ARRAY_VERTEX and arrs[Mesh.ARRAY_VERTEX]:
			var verts = arrs[Mesh.ARRAY_VERTEX]
			var conc = ConcavePolygonShape3D.new()
			conc.data = verts
			cs_platforms.shape = conc
	cs_platforms.position = -center
	sb.add_child(cs_platforms)

	# Générer les rampes et les ajouter au StaticBody
	for plat in placed_platforms:
		_generate_ramps(plat.x, plat.z, plat.w, plat.h, plat.level, hm, N, M, tile_size, platform_height, rng, sb, center)

	add_child(sb)

	print("MapGenerator: génération terminée. size=", N, "x", M, " tiles:", tiles_placed, " plateformes:", placed_platforms.size())

# ---------------------------------------------------
func _generate_ramps(x0, z0, w, h, level, hm, N, M, tile_size, platform_height, rng, sb: StaticBody3D, center: Vector3):
	var directions = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
	directions.shuffle()
	var current_height = level * platform_height
	
	for dir in directions:
		var nx = x0
		var nz = z0
		if dir.x > 0:
			nx = x0 + w      # bord droit
			nz = z0 + rng.randi_range(0, h-1)
		elif dir.x < 0:
			nx = x0 - 1     # bord gauche
			nz = z0 + rng.randi_range(0, h-1)
		elif dir.y > 0:
			nx = x0 + rng.randi_range(0, w-1)
			nz = z0 + h      # bord avant
		elif dir.y < 0:
			nx = x0 + rng.randi_range(0, w-1)
			nz = z0 - 1     # bord arrière

		# Vérifie que la tuile voisine existe et a la bonne hauteur
		if nx >= 0 and nx < N and nz >= 0 and nz < M:
			var neighbor_height = hm[nx][nz]
			# La rampe va du niveau inférieur vers le niveau actuel
			if neighbor_height == current_height - platform_height:
				_add_ramp(Vector3(nx, 0, nz), dir, tile_size, platform_height, level, sb, center)
				break

func _add_ramp(origin: Vector3, dir: Vector2, tile_size: float, height: float, level: int, sb: StaticBody3D, center: Vector3) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.5)  # Couleur différente pour les rampes
	
	# Créer le mesh de la rampe
	var mesh = PrismMesh.new()
	mesh.size = Vector3(tile_size, height, tile_size)
	
	# Position de base de la tuile (au niveau inférieur)
	var base_height = (level - 1) * height
	var x_pos = origin.x * tile_size + tile_size * 0.5
	var z_pos = origin.z * tile_size + tile_size * 0.5
	
	var ramp_mi = MeshInstance3D.new()
	ramp_mi.name = "Ramp_" + str(origin.x) + "_" + str(origin.z)
	ramp_mi.mesh = mesh
	ramp_mi.material_override = mat
	
	# Configuration selon la direction
	if dir.x > 0:
		# Rampe vers la droite (+X)
		mesh.left_to_right = 0.0
		ramp_mi.rotation_degrees = Vector3(0, 0, 0)
	elif dir.x < 0:
		# Rampe vers la gauche (-X)
		mesh.left_to_right = 1.0
		ramp_mi.rotation_degrees = Vector3(0, 0, 0)
	elif dir.y > 0:
		# Rampe vers l'avant (+Z)
		mesh.left_to_right = 1.0
		ramp_mi.rotation_degrees = Vector3(0, 90, 0)
	elif dir.y < 0:
		# Rampe vers l'arrière (-Z)
		mesh.left_to_right = 0.0
		ramp_mi.rotation_degrees = Vector3(0, 90, 0)
	
	ramp_mi.position = Vector3(x_pos, base_height + height * 0.5, z_pos) - center
	sb.add_child(ramp_mi)
	
	# Créer la collision pour la rampe
	var cs_ramp = CollisionShape3D.new()
	cs_ramp.name = "RampCollision_" + str(origin.x) + "_" + str(origin.z)
	
	# Convertir le PrismMesh en ConvexPolygonShape3D
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
	
	cs_ramp.position = ramp_mi.position
	cs_ramp.rotation = ramp_mi.rotation
	sb.add_child(cs_ramp)

func _cleanup_previous() -> void:
	for child in get_children():
		child.queue_free()
