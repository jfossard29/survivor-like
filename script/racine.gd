extends Node3D

@export var pnj_scene: PackedScene
@export var player: CharacterBody3D
@export var spawn_interval: float = 3.0
@export var max_pnjs: int = 10
@export var min_spawn_distance: float = 3.0
var current_pnjs: Array = []

func _ready():
	if player:
		GameManager.set_player(player)
	spawn_loop()

func spawn_loop() -> void:
	while true:
		await get_tree().create_timer(spawn_interval).timeout
		cleanup_pnjs()
		if current_pnjs.size() < max_pnjs:
			spawn_pnj()

func cleanup_pnjs():
	current_pnjs = current_pnjs.filter(func(p): return is_instance_valid(p))

func spawn_pnj():
	if not player:
		return
	
	var spawn_zone = player.get_node_or_null("SpawnZone")
	if not spawn_zone:
		push_warning("⚠️ Le joueur n'a pas de SpawnZone (Area3D).")
		return
	
	var shape_node = spawn_zone.get_node_or_null("CollisionShape3D")
	if not shape_node or not shape_node.shape:
		push_warning("⚠️ SpawnZone n'a pas de forme de collision.")
		return
	
	var zone_shape = shape_node.shape
	var radius := 5.0
	if zone_shape is CylinderShape3D:
		radius = zone_shape.radius
	elif zone_shape is SphereShape3D:
		radius = zone_shape.radius
	
	var space_state = get_world_3d().direct_space_state
	
	for i in range(10):
		var angle = randf() * TAU
		var distance = randf_range(0.0, radius)
		var local_pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var world_pos = spawn_zone.to_global(local_pos)
		world_pos.y = 1.0
		
		if world_pos.distance_to(player.global_position) < min_spawn_distance:
			continue
		
		var ray_start = world_pos + Vector3.UP * 50.0
		var ray_end = world_pos + Vector3.DOWN * 100.0
		var params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		params.exclude = [player]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		
		var result = space_state.intersect_ray(params)
		if result and result.collider:
			var collider = result.collider
			if collider.is_in_group("terrain") and not collider.is_in_group("InvisibleWalls"):
				var ground_pos = result.position
				var pnj = pnj_scene.instantiate()
				get_tree().current_scene.add_child(pnj)
				
				var collider_shape = pnj.get_node_or_null("CollisionShape3D")
				var y_offset = 0.0
				if collider_shape and collider_shape.shape:
					var shape = collider_shape.shape
					if shape is CapsuleShape3D:
						y_offset = shape.height / 2 + shape.radius
					elif shape is BoxShape3D:
						y_offset = shape.extents.y
				
				pnj.global_position = ground_pos + Vector3.UP * (y_offset * 0.9)
				current_pnjs.append(pnj)
				return
	
	print("⚠️ Aucun point de spawn valide trouvé après 10 essais.")
