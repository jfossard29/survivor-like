extends WeaponBase

@export var projectile_scene: PackedScene

func _ready():
	weapon_id = "basic_gun"
	weapon_name = "Pistolet de Base"
	base_damage = 10.0
	base_fire_rate = 1.0  # 1 tir par seconde
	base_range = 30.0
	
	super._ready()

# Validation après initialisation complète
func setup() -> void:
	if not projectile_scene:
		push_error("❌ BasicWeapon: projectile_scene non assigné!")

func fire() -> void:
	if not projectile_scene or not player:
		return
	
	var target = find_closest_enemy()
	
	# Pas de cible à portée, ne pas tirer
	if not target:
		return
	
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
			if d <= final_range and d < closest_dist:
				closest_dist = d
				closest_enemy = enemy
	
	return closest_enemy

func spawn_projectile(target: Node3D) -> void:
	var projectile = projectile_scene.instantiate()
	player.get_tree().current_scene.add_child(projectile)
	
	var forward_dir: Vector3 = -player.global_transform.basis.z.normalized()
	var start_pos: Vector3 = player.global_position + forward_dir * 0.8 + Vector3(0, 0.5, 0)
	
	projectile.look_at_from_position(start_pos, start_pos + forward_dir, Vector3.UP)
	
	# Passer les stats finales au projectile (vérification sécurisée)
	if "damage" in projectile:
		projectile.damage = int(final_damage)
	
	# Assigner les autres propriétés si elles existent
	if "search_range" in projectile:
		projectile.search_range = final_range
	
	# Assigner la cible
	if target:
		if "target" in projectile:
			projectile.target = target
		print("🎯 Tir vers ", target.name, " - Dégâts: ", int(final_damage))
	else:
		if "direction" in projectile:
			projectile.direction = forward_dir
		print("➡️ Tir droit devant - Dégâts: ", int(final_damage))
