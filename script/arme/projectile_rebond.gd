extends Area3D
@export var speed: float = 25.0
@export var damage: int = 8
@export var lifetime: float = 3.0
@export var search_range: float = 30.0  # Range initiale (sera écrasée par l'arme)
@export var bounce_range: float = 5.0  # Range de base pour les rebonds
@export var max_bounces: int = 3  # Nombre maximum de rebonds

var target: Node3D = null
var direction: Vector3 = Vector3.ZERO
var bounces_remaining: int = max_bounces
var hit_enemies: Array[Node3D] = []  # Liste des ennemis déjà touchés
var is_first_shot: bool = true  # Pour différencier le tir initial des rebonds
var current_detection_range: float = 0.0  # Range actuelle de détection

func _ready():
	add_to_group("projectile")
	add_to_group("player_projectile")
	
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Initialiser la range de détection avec search_range
	current_detection_range = search_range
	
	# Recherche de l'ennemi le plus proche initial (utilise search_range)
	find_next_target()
	
	# Si aucune cible trouvée au départ, tirer tout droit
	if target == null:
		print("⚠️ Aucune cible initiale trouvée, tir en ligne droite")
		direction = -global_transform.basis.z.normalized()
	
	# Auto-destruction après un délai
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
		look_at(target.global_position, Vector3.UP)
	elif direction != Vector3.ZERO:
		global_position += direction * speed * delta
		look_at(global_position + direction, Vector3.UP)
	else:
		# Aucune cible et aucune direction = on détruit
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Détecte les ennemis (PNJ et boss)
	if body.is_in_group("enemy"):
		# Vérifier si l'ennemi n'a pas déjà été touché
		if body in hit_enemies:
			return
		
		# Infliger les dégâts
		if body.has_method("take_damage"):
			body.take_damage(damage)
			GameManager.count_manager.add_dmg_bounce_count(damage)
		
		# Ajouter l'ennemi à la liste des touchés
		hit_enemies.append(body)
		
		# Vérifier s'il reste des rebonds
		if bounces_remaining > 0:
			bounces_remaining -= 1
			is_first_shot = false  # Les prochains seront des rebonds
			
			# IMPORTANT : Remplacer la range de détection par celle de l'ennemi touché
			var hit_enemy_radius = get_enemy_collision_radius(body)
			current_detection_range = bounce_range + hit_enemy_radius
			
			print("🎯 Rebond ! Nouvelle range de détection : ", current_detection_range, " (base: ", bounce_range, " + rayon ennemi: ", hit_enemy_radius, ")")
			
			find_next_target()
			
			# Si aucune cible trouvée pour rebondir, détruire le projectile
			if target == null:
				print("🔚 Aucune cible pour rebond, destruction")
				queue_free()
		else:
			# Plus de rebonds disponibles
			queue_free()

func find_next_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	var closest_dist = current_detection_range + 1.0
	var new_target: Node3D = null
	
	for enemy in enemies:
		# Vérifier que l'ennemi est valide et pas déjà touché
		if not is_instance_valid(enemy) or enemy in hit_enemies:
			continue
		
		var d = global_position.distance_to(enemy.global_position)
		
		# Utiliser current_detection_range qui a déjà le rayon de l'ennemi précédent
		if d <= current_detection_range and d < closest_dist:
			closest_dist = d
			new_target = enemy
	
	# Assigner la nouvelle cible
	if new_target != null:
		target = new_target
		direction = Vector3.ZERO
		print("✅ Nouvelle cible trouvée à ", closest_dist, "m")
	else:
		# Aucune cible trouvée
		target = null
		direction = Vector3.ZERO

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

func get_damage() -> int:
	return damage
