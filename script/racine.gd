extends Node3D

@export var pnj_scene: PackedScene
@export var player: CharacterBody3D
@export var spawn_interval: float = 3.0
@export var max_pnjs: int = 10
@export var min_spawn_distance: float = 3.0

var current_pnjs: Array = []
var spawn_radius: float = 5.0
var spawn_zone: Area3D = null

func _ready():
	if player:
		GameManager.set_player(player)
		_cache_spawn_zone()
	spawn_loop()

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

func spawn_loop() -> void:
	while true:
		await get_tree().create_timer(spawn_interval).timeout
		cleanup_pnjs()
		
		# Spawner plusieurs ennemis d'un coup si nécessaire (plus efficace)
		var to_spawn = max_pnjs - current_pnjs.size()
		for i in range(min(to_spawn, 3)):  # Max 3 par cycle
			spawn_pnj()

func cleanup_pnjs():
	# Nettoyage optimisé
	var i = current_pnjs.size() - 1
	while i >= 0:
		if not is_instance_valid(current_pnjs[i]):
			current_pnjs.remove_at(i)
		i -= 1

func spawn_pnj():
	if not player or not spawn_zone:
		return
	
	var space_state = get_world_3d().direct_space_state
	
	# Réduire les tentatives de 10 à 5
	for attempt in range(5):
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)
		
		# Raycast optimisé : distance plus courte
		var ray_start = world_pos + Vector3.UP * 5.0  # 5m au lieu de 50m
		var ray_end = world_pos + Vector3.DOWN * 10.0  # 10m au lieu de 100m
		
		var params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		params.exclude = [player]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		params.collision_mask = 1  # Layer 1 uniquement (terrain)
		
		var result = space_state.intersect_ray(params)
		if result and result.collider:
			var collider = result.collider
			if collider.is_in_group("terrain") and not collider.is_in_group("InvisibleWalls"):
				_instantiate_pnj(result.position)
				return
	
	# Spawn de secours sans raycast si tous les essais échouent
	var fallback_pos = player.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	fallback_pos.y = player.global_position.y
	_instantiate_pnj(fallback_pos)

func _instantiate_pnj(ground_pos: Vector3):
	var pnj = pnj_scene.instantiate()
	get_tree().current_scene.add_child(pnj)
	
	# Calcul du offset Y optimisé
	var y_offset = 1.0  # Valeur par défaut
	var collider_shape = pnj.get_node_or_null("CollisionShape3D")
	if collider_shape and collider_shape.shape:
		var shape = collider_shape.shape
		if shape is CapsuleShape3D:
			y_offset = shape.height / 2 + shape.radius
		elif shape is BoxShape3D:
			y_offset = shape.size.y / 2  # size au lieu de extents dans Godot 4
	
	pnj.global_position = ground_pos + Vector3.UP * y_offset
	current_pnjs.append(pnj)
