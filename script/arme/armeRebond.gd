extends WeaponBase
@export var projectile_scene: PackedScene

func _ready():
	weapon_id = "bounce_gun"
	weapon_name = "Pistolet à Rebond"
	base_damage = 8.0
	base_fire_rate = 0.8
	base_range = 30.0
	
	super._ready()

func setup() -> void:
	pass

func fire() -> void:
	var target = find_closest_enemy()
	spawn_projectile(target)
	start_cooldown()

func find_closest_enemy() -> Node3D:
	var closest_enemy: Node3D = null
	var closest_dist: float = final_range + 1.0
	
	if GameManager and GameManager.registered_enemies:
		for enemy in GameManager.registered_enemies:
			if not is_instance_valid(enemy):
				continue
			
			var d = player.global_position.distance_to(enemy.global_position)
			var enemy_radius = get_enemy_collision_radius(enemy)
			
			if d <= (final_range + enemy_radius) and d < closest_dist:
				closest_dist = d
				closest_enemy = enemy
	
	return closest_enemy

func get_enemy_collision_radius(enemy: Node3D) -> float:
	var max_radius: float = 0.0
	
	for child in enemy.get_children():
		if child is CollisionShape3D:
			max_radius = max(max_radius, get_shape_radius(child.shape))
		elif child is Area3D:
			for area_child in child.get_children():
				if area_child is CollisionShape3D:
					max_radius = max(max_radius, get_shape_radius(area_child.shape))
	
	return max_radius

func get_shape_radius(shape: Shape3D) -> float:
	if shape is SphereShape3D:
		return shape.radius
	elif shape is CapsuleShape3D:
		return shape.radius
	elif shape is BoxShape3D:
		var size = shape.size
		return max(size.x, size.z) / 2.0
	elif shape is CylinderShape3D:
		return shape.radius
	return 0.0

func spawn_projectile(target: Node3D) -> void:
	var projectile = projectile_scene.instantiate()
	player.get_tree().current_scene.add_child(projectile)
	
	var forward_dir: Vector3 = -player.global_transform.basis.z.normalized()
	var start_pos: Vector3 = player.global_position + forward_dir * 0.8 + Vector3(0, 0.5, 0)
	
	projectile.look_at_from_position(start_pos, start_pos + forward_dir, Vector3.UP)
	
	if "damage" in projectile:
		projectile.damage = int(final_damage)
	
	if "search_range" in projectile:
		projectile.search_range = final_range
	
	if "bounce_range" in projectile:
		projectile.bounce_range = final_range * 0.5  # Range de rebond = 50% de la range initiale
	
	if target:
		if "target" in projectile:
			projectile.target = target
	else:
		if "direction" in projectile:
			projectile.direction = forward_dir
