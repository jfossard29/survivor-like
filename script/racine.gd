extends Node3D

@export var pnj_scene: PackedScene
@export var boss_scene: PackedScene
@export var player: CharacterBody3D
@export var spawn_interval: float = 3.0
@export var max_pnjs: int = 50
@export var min_spawn_distance: float = 8.0
@export var boss_spawn_distance: float = 15.0

var current_pnjs: Array = []
var spawn_radius: float = 5.0
var spawn_zone: Area3D = null
var is_paused: bool = false

func _ready():
	print("🔧 Spawner _ready() appelé")
	
	if player:
		GameManager.set_player(player)
		_cache_spawn_zone()
	else:
		push_error("❌ SPAWNER: Pas de référence au player!")
	
	# Vérifier que la scène de boss existe
	if not boss_scene:
		push_error("❌ SPAWNER: boss_scene n'est pas assigné!")
	else:
		print("✅ Boss scene assigné: ", boss_scene.resource_path)
	
	# Connecter au signal de pause
	call_deferred("_connect_pause_menu")
	
	# Connecter au signal de boss AVANT que le timer ne démarre
	if GameManager:
		print("✅ Connexion au signal boss_spawn_requested")
		GameManager.boss_spawn_requested.connect(_on_boss_spawn_requested)
	else:
		push_error("❌ GameManager n'existe pas!")
	
	spawn_loop()

func _connect_pause_menu() -> void:
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_signal("game_paused"):
		pause_menu.game_paused.connect(_on_game_paused)

func _on_game_paused(paused: bool) -> void:
	is_paused = paused

func _on_boss_spawn_requested() -> void:
	print("🔥 Signal boss_spawn_requested reçu!")
	spawn_boss()

func _cache_spawn_zone():
	spawn_zone = player.get_node_or_null("SpawnZone")
	if not spawn_zone:
		push_warning("⚠️ Le joueur n'a pas de SpawnZone (Area3D).")
		return
	
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
	
	var space_state = get_world_3d().direct_space_state
	
	for attempt in range(5):
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)
		
		var ray_start = world_pos + Vector3.UP * 5.0
		var ray_end = world_pos + Vector3.DOWN * 10.0
		
		var params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		params.exclude = [player]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		params.collision_mask = 1
		
		var result = space_state.intersect_ray(params)
		if result and result.collider:
			var collider = result.collider
			if collider.is_in_group("terrain") and not collider.is_in_group("InvisibleWalls"):
				_instantiate_pnj(result.position)
				return
	
	var fallback_angle = randf() * TAU
	var fallback_distance = randf_range(min_spawn_distance, spawn_radius)
	var fallback_offset = Vector3(cos(fallback_angle) * fallback_distance, 0, sin(fallback_angle) * fallback_distance)
	var fallback_pos = player.global_position + fallback_offset
	_instantiate_pnj(fallback_pos)

func spawn_boss() -> void:
	print("🔥 spawn_boss() appelée")
	
	if not boss_scene:
		push_error("❌ boss_scene est null!")
		return
	
	if not player:
		push_error("❌ player est null!")
		return
	
	if not spawn_zone:
		push_error("❌ spawn_zone est null!")
		return
	
	print("✅ Toutes les références sont valides")
	
	var space_state = get_world_3d().direct_space_state
	var boss_spawned = false
	
	# Essayer plusieurs positions
	for attempt in range(10):
		var angle = randf() * TAU
		var distance = boss_spawn_distance
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)
		
		print("🎯 Tentative ", attempt + 1, " à position: ", world_pos)
		
		var ray_start = world_pos + Vector3.UP * 5.0
		var ray_end = world_pos + Vector3.DOWN * 10.0
		
		var params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		params.exclude = [player]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		params.collision_mask = 1
		
		var result = space_state.intersect_ray(params)
		if result and result.collider:
			print("  ✅ Sol trouvé à: ", result.position)
			var collider = result.collider
			if collider.is_in_group("terrain") and not collider.is_in_group("InvisibleWalls"):
				_instantiate_boss(result.position)
				boss_spawned = true
				return
			else:
				print("  ⚠️ Collider n'est pas terrain ou est InvisibleWall")
		else:
			print("  ❌ Aucun sol trouvé")
	
	if not boss_spawned:
		print("⚠️ Spawn de secours du boss")
		var fallback_pos = player.global_position + Vector3.FORWARD * boss_spawn_distance
		fallback_pos.y = player.global_position.y
		_instantiate_boss(fallback_pos)

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
