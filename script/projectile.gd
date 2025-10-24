extends Area3D

@export var speed: float = 20.0
@export var damage: int = 10
@export var lifetime: float = 2.0
@export var search_range: float = 30.0

var target: Node3D = null
var direction: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("projectile")
	add_to_group("player_projectile")  # Groupe pour identification par les ennemis
	
	# Connecte les signaux de collision
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Recherche de l'ennemi le plus proche (PNJ ou boss)
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_dist = search_range + 1.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var d = global_position.distance_to(enemy.global_position)
		if d <= search_range and d < closest_dist:
			closest_dist = d
			target = enemy
	
	# Si aucun ennemi trouvé, tirer tout droit
	if target == null and direction == Vector3.ZERO:
		direction = -global_transform.basis.z
		direction.y = 0
		direction = direction.normalized()
	
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
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	# Détecte les ennemis (PNJ et boss)
	if area.is_in_group("enemy") or area.get_parent().is_in_group("enemy"):
		var enemy = area if area.is_in_group("enemy") else area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Détecte les ennemis (PNJ et boss)
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

func get_damage() -> int:
	return damage
