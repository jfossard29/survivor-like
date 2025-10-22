@tool
extends Node3D

# Paramètres
@export var map_size: int = 100
@export var bloc_size: float = 10.0  # Taille du bloc préfait (10x10x10)
@export var platform_coverage: float = 0.06
@export var min_platform_blocs: int = 2
@export var max_platform_blocs: int = 8
@export var max_attempts_place: int = 3000
@export var seed: int = 0
@export var bloc_gap: int = 1  # Espacement en nombre de blocs
@export var stacked_platform_chance: float = 0.5
@export var auto_generate_on_play: bool = true
@export_file("*.glb") var bloc_path: String = "res://bloc.glb"  # Chemin vers le modèle

# Exported property avec setter/getter
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
	
	# Vérifier que le bloc existe
	if not ResourceLoader.exists(bloc_path):
		push_error("Le modèle bloc.glb n'existe pas au chemin: " + bloc_path)
		return
	
	# Calcul du nombre de blocs basé sur map_size et bloc_size
	var N = max(1, int(floor(float(map_size) / bloc_size)))
	var M = N
	
	# Validation des paramètres
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

	# Grille de hauteur (stocke le niveau de chaque bloc)
	var hm := []
	for x in range(N + 1):
		var col := []
		for z in range(M + 1):
			col.append(0)  # 0 = pas de bloc, 1+ = niveau
		hm.append(col)

	# Liste des plateformes placées
	var placed_platforms := []

	# Cible de blocs à placer
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

		# Vérifie l'espacement
		var ok = true
		for xi in range(max(0, x0 - bloc_gap), min(N, x0 + w + bloc_gap)):
			for zi in range(max(0, z0 - bloc_gap), min(M, z0 + h + bloc_gap)):
				if hm[xi][zi] > 0:
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue

		# Place la plateforme niveau 1
		for xi in range(x0, x0 + w):
			for zi in range(z0, z0 + h):
				hm[xi][zi] = 1
				blocs_placed += 1

		# Stocke la plateforme
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
		
		# Place la plateforme empilée
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

	# Créer le conteneur principal
	var container = Node3D.new()
	container.name = NAME_BODY
	var center = Vector3(N * bloc_size * 0.5, 0, M * bloc_size * 0.5)

	# Placer les blocs
	var bloc_scene = load(bloc_path)
	for x in range(N):
		for z in range(M):
			var level = hm[x][z]
			if level > 0:
				var bloc_instance = bloc_scene.instantiate()
				bloc_instance.name = "Bloc_" + str(x) + "_" + str(z) + "_L" + str(level)
				
				# Position du bloc
				var x_pos = x * bloc_size + bloc_size * 0.5
				var y_pos = (level - 1) * bloc_size + bloc_size * 0.5
				var z_pos = z * bloc_size + bloc_size * 0.5
				
				bloc_instance.position = Vector3(x_pos, y_pos, z_pos) - center
				container.add_child(bloc_instance)

	# Générer les rampes
	for plat in placed_platforms:
		_generate_ramps(plat.x, plat.z, plat.w, plat.h, plat.level, hm, N, M, bloc_size, rng, container, center)

	add_child(container)

	print("MapGenerator: génération terminée. size=", N, "x", M, " blocs:", blocs_placed, " plateformes:", placed_platforms.size())

# ---------------------------------------------------
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

		# Vérifie la tuile voisine
		if nx >= 0 and nx < N and nz >= 0 and nz < M:
			var neighbor_level = hm[nx][nz]
			if neighbor_level == level - 1:
				_add_ramp(Vector3(nx, 0, nz), dir, bloc_size, level, container, center)
				break

func _add_ramp(origin: Vector3, dir: Vector2, bloc_size: float, level: int, container: Node3D, center: Vector3) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.5)
	
	# Créer le StaticBody pour la rampe
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
	
	# Configuration selon la direction
	if dir.x > 0:
		mesh.left_to_right = 0.0
		ramp_mi.rotation_degrees = Vector3(0, 0, 0)
	elif dir.x < 0:
		mesh.left_to_right = 1.0
		ramp_mi.rotation_degrees = Vector3(0, 0, 0)
	elif dir.y > 0:
		mesh.left_to_right = 0.0
		ramp_mi.rotation_degrees = Vector3(0, -45, 0)
	elif dir.y < 0:
		mesh.left_to_right = 1.0
		ramp_mi.rotation_degrees = Vector3(0, -45, 0)
	
	ramp_body.position = Vector3(x_pos, base_height + bloc_size * 0.5, z_pos) - center
	ramp_body.rotation = ramp_mi.rotation
	ramp_body.add_child(ramp_mi)
	
	# Créer la collision
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

func _cleanup_previous() -> void:
	for child in get_children():
		child.queue_free()
