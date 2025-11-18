extends WeaponBase

@export var projectile_scene: PackedScene

func _ready():
	weapon_id = "basic_gun"
	weapon_name = "Pistolet de Base"
	base_damage = 10.0
	base_fire_rate = 1.0
	base_range = 30.0
	
	super._ready()

func setup() -> void:
	pass

func fire() -> void:
	# CRITICAL: Vérifier que tout est valide avant de tirer
	if not is_active or not is_instance_valid(self):
		return
	
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
	
	# Vérifier que la scène est encore accessible
	if not get_tree() or not get_tree().current_scene:
		return
	
	var target = find_closest_enemy()
	spawn_projectile(target)
	start_cooldown()

func find_closest_enemy() -> Node3D:
	if not GameManager or not GameManager.enemy_manager:
		return null
	
	var closest_enemy: Node3D = null
	var closest_dist: float = final_range + 1.0
	
	for enemy in GameManager.enemy_manager.registered_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var d = player.global_position.distance_to(enemy.global_position)
		if d <= final_range and d < closest_dist:
			closest_dist = d
			closest_enemy = enemy
	
	return closest_enemy

func spawn_projectile(target: Node3D) -> void:
	# CRITICAL: Vérifications complètes avant spawn
	if not is_active or not is_instance_valid(self):
		return
	
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
	
	# Vérifier que get_tree() est accessible
	var tree = player.get_tree()
	if not tree or not tree.current_scene:
		return
	
	var projectile = projectile_scene.instantiate()
	tree.current_scene.add_child(projectile)
	
	var forward_dir: Vector3 = -player.global_transform.basis.z.normalized()
	var start_pos: Vector3 = player.global_position + forward_dir * 0.8 + Vector3(0, 0.5, 0)
	
	projectile.look_at_from_position(start_pos, start_pos + forward_dir, Vector3.UP)
	
	if "damage" in projectile:
		projectile.damage = int(final_damage)
	
	if "search_range" in projectile:
		projectile.search_range = final_range
	
	if target:
		if "target" in projectile:
			projectile.target = target
	else:
		if "direction" in projectile:
			projectile.direction = forward_dir
