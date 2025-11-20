extends Node3D

@export var pnj_scene: PackedScene
@export var boss_scene: PackedScene
@export var player_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_pnjs: int = 50
@export var min_spawn_distance: float = 8.0
@export var boss_spawn_distance: float = 15.0

@onready var game_over_canvas : CanvasLayer = $GameOver
@onready var win_canvas : CanvasLayer = $Win
var current_pnjs: Array = []
var spawn_radius: float = 5.0
var spawn_zone: Area3D = null
var is_paused: bool = false
var player: CharacterBody3D = null  # Le joueur est maintenant directement le CharacterBody3D

signal game_over()
signal game_paused(paused: bool)
signal game_won()

func _ready():
	# Récupérer le joueur qui est maintenant un CharacterBody3D
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		player = get_tree().root.find_child("Joueur", true, false)
	
	if not player:
		push_error("❌ SPAWNER: Pas de référence au player!")
		return
	
	print("✅ Spawner a trouvé le joueur: ", player.name, " (Type: ", player.get_class(), ")")
	
	# Assigner les musiques principales uniquement
	MusicManager.main_tracks = [
		preload("res://sounds/Endless_Spiral_of_Chaos.ogg"),
		preload("res://sounds/Endless_Spiral_of_Fight.ogg")
	]
	MusicManager.start_music()
	
	# Vérifier que la scène de boss existe
	if not boss_scene:
		push_error("❌ SPAWNER: boss_scene n'est pas assigné!")
	else:
		print("✅ Boss scene assigné: ", boss_scene.resource_path)
	
	# Connecter au signal de pause
	call_deferred("_connect_pause_menu")
	
	# Connecter au signal de boss
	if GameManager:
		print("✅ Connexion au signal boss_spawn_requested")
		GameManager.timer_manager.boss_spawn_requested.connect(_on_boss_spawn_requested)
	else:
		push_error("❌ GameManager n'existe pas!")
	
	# Attendre que le joueur soit complètement dans l'arbre avant de cacher spawn_zone
	call_deferred("_initialize_spawn_system")
	GameManager.set_game_active(true)
	GameManager.game_over.connect(_game_over_setup)
	GameManager.game_won.connect(_win_setup)

func _initialize_spawn_system():
	# Attendre plusieurs frames pour que tout soit bien dans l'arbre
	for i in range(3):
		await get_tree().process_frame
	
	_cache_spawn_zone()
	
	# Vérifier que spawn_zone est bien dans l'arbre avant de démarrer
	if spawn_zone and spawn_zone.is_inside_tree():
		print("✅ SpawnZone confirmée dans l'arbre, démarrage du spawn_loop")
		spawn_loop()
	else:
		push_error("❌ Impossible d'initialiser le système de spawn")
		if spawn_zone:
			push_error("   SpawnZone existe mais n'est pas dans l'arbre")
		else:
			push_error("   SpawnZone n'existe pas")

func _connect_pause_menu() -> void:
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.connect(_on_game_paused)

func _on_game_paused(paused: bool) -> void:
	is_paused = paused
	MusicManager.set_game_paused(paused)

func _on_boss_spawn_requested() -> void:
	print("🔥 Signal boss_spawn_requested reçu!")
	spawn_boss()

func _cache_spawn_zone():
	if not player:
		push_error("❌ Player n'existe pas")
		return
	
	if not player.is_inside_tree():
		push_error("❌ Player n'est pas dans l'arbre")
		return
	
	# La SpawnZone est maintenant directement dans le CharacterBody3D
	spawn_zone = player.get_node_or_null("SpawnZone")
	if not spawn_zone:
		push_warning("⚠️ Le joueur n'a pas de SpawnZone (Area3D).")
		print("   Structure du joueur:")
		for child in player.get_children():
			print("   - ", child.name, " (", child.get_class(), ")")
		return
	
	print("✅ SpawnZone trouvée: ", spawn_zone.name)
	print("   Dans l'arbre: ", spawn_zone.is_inside_tree())
	
	var shape_node = spawn_zone.get_node_or_null("CollisionShape3D")
	if not shape_node or not shape_node.shape:
		push_warning("⚠️ SpawnZone n'a pas de forme de collision.")
		return
	
	var zone_shape = shape_node.shape
	if zone_shape is CylinderShape3D:
		spawn_radius = zone_shape.radius
	elif zone_shape is SphereShape3D:
		spawn_radius = zone_shape.radius
	
	print("✅ SpawnZone configurée avec rayon: ", spawn_radius)

func spawn_loop() -> void:
	while true:
		await get_tree().create_timer(spawn_interval).timeout
		
		if is_paused:
			continue
		
		cleanup_pnjs()
		
		var to_spawn = max_pnjs - current_pnjs.size()
		for i in range(min(to_spawn, 3)):
			spawn_pnj()

func cleanup_pnjs():
	var i = current_pnjs.size() - 1
	while i >= 0:
		if not is_instance_valid(current_pnjs[i]):
			current_pnjs.remove_at(i)
		i -= 1

func spawn_pnj():
	if not player or not spawn_zone:
		return
	
	if not spawn_zone.is_inside_tree():
		push_warning("⚠️ spawn_zone n'est pas dans l'arbre")
		return
	
	var space_state = get_world_3d().direct_space_state
	
	for attempt in range(10):  # Augmenté à 10 tentatives
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)
		
		# Ray depuis plus haut pour détecter les plateformes au-dessus
		var ray_start = world_pos + Vector3.UP * 20.0
		var ray_end = world_pos + Vector3.DOWN * 30.0
		
		var params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		params.exclude = [player]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		params.collision_mask = 2  # ✅ Layer 2 = sol uniquement
		
		var result = space_state.intersect_ray(params)
		if result and result.collider:
			var hit_pos = result.position
			
			# Vérifier qu'il n'y a rien au-dessus (pas dans le sol)
			var clearance_check = PhysicsRayQueryParameters3D.create(
				hit_pos + Vector3.UP * 0.5,
				hit_pos + Vector3.UP * 3.0
			)
			clearance_check.exclude = [player]
			clearance_check.collide_with_areas = false
			clearance_check.collide_with_bodies = true
			clearance_check.collision_mask = 2
			
			var blocked = space_state.intersect_ray(clearance_check)
			if not blocked:  # Espace libre au-dessus
				_instantiate_pnj(hit_pos)
				return
	
	# Fallback si aucune position valide trouvée
	push_warning("⚠️ Aucune position valide trouvée pour spawn PNJ")

func spawn_boss() -> void:
	print("🔥 spawn_boss() appelée")
	
	if not boss_scene or not player or not spawn_zone:
		push_error("❌ Références manquantes pour spawn boss")
		return
	
	if not spawn_zone.is_inside_tree():
		push_error("❌ spawn_zone n'est pas dans l'arbre")
		return
	
	var space_state = get_world_3d().direct_space_state
	
	for attempt in range(15):  # Plus de tentatives pour le boss
		var angle = randf() * TAU
		var distance = boss_spawn_distance
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)
		
		# Ray depuis plus haut
		var ray_start = world_pos + Vector3.UP * 20.0
		var ray_end = world_pos + Vector3.DOWN * 30.0
		
		var params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		params.exclude = [player]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		params.collision_mask = 2  # ✅ Layer 2 = sol uniquement
		
		var result = space_state.intersect_ray(params)
		if result and result.collider:
			var hit_pos = result.position
			
			# Vérifier l'espace libre (boss plus grand, 5m de hauteur)
			var clearance_check = PhysicsRayQueryParameters3D.create(
				hit_pos + Vector3.UP * 0.5,
				hit_pos + Vector3.UP * 5.0
			)
			clearance_check.exclude = [player]
			clearance_check.collide_with_areas = false
			clearance_check.collide_with_bodies = true
			clearance_check.collision_mask = 2
			
			var blocked = space_state.intersect_ray(clearance_check)
			if not blocked:
				_instantiate_boss(hit_pos)
				print("🎉 Boss spawné à: ", hit_pos)
				return
	
	push_error("❌ Impossible de trouver une position valide pour le boss")

func _instantiate_pnj(ground_pos: Vector3):
	var pnj = pnj_scene.instantiate()
	get_tree().current_scene.add_child(pnj)
	
	var y_offset = 1.0
	var collider_shape = pnj.get_node_or_null("CollisionShape3D")
	if collider_shape and collider_shape.shape:
		var shape = collider_shape.shape
		if shape is CapsuleShape3D:
			y_offset = shape.height / 2 + shape.radius
		elif shape is BoxShape3D:
			y_offset = shape.size.y / 2
	
	pnj.global_position = ground_pos + Vector3.UP * y_offset
	current_pnjs.append(pnj)

func _instantiate_boss(ground_pos: Vector3):
	print("🔥 _instantiate_boss() appelée à position: ", ground_pos)
	
	var boss = boss_scene.instantiate()
	print("✅ Boss instancié: ", boss)
	
	get_tree().current_scene.add_child(boss)
	print("✅ Boss ajouté à la scène")
	
	var y_offset = 2.0
	var collider_shape = boss.get_node_or_null("CollisionShape3D")
	if collider_shape and collider_shape.shape:
		var shape = collider_shape.shape
		if shape is CapsuleShape3D:
			y_offset = shape.height / 2 + shape.radius
		elif shape is BoxShape3D:
			y_offset = shape.size.y / 2
	
	boss.global_position = ground_pos + Vector3.UP * y_offset
	print("🎉 Boss spawné avec succès à: ", boss.global_position)

func _game_over_setup():
	game_over_canvas.visible = true
	game_over_canvas.setup_game_over()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_paused.emit(true)
	
func _win_setup():
	win_canvas.visible = true
	win_canvas.setup_win()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_paused.emit(true)
