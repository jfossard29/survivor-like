extends Area3D

@export var speed: float = 20.0
@export var damage: int = 10
@export var lifetime: float = 2.0
@export var search_range: float = 30.0  # zone de recherche du PNJ

var target: Node3D = null
var direction: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("projectile")
	
	# Chercher le PNJ le plus proche
	var pnjs = get_tree().get_nodes_in_group("pnj")
	var closest_dist = search_range + 1.0
	for p in pnjs:
		# S'assurer que c'est bien un PNJ et pas le joueur
		if not is_instance_valid(p) or not p.is_in_group("pnj"):
			continue
		
		var d = global_position.distance_to(p.global_position)
		if d <= search_range and d < closest_dist:
			closest_dist = d
			target = p
	
	# Si aucun PNJ trouvé, tirer droit devant
	if target == null and direction == Vector3.ZERO:
		direction = -transform.basis.z
		direction.y = 0
		direction = direction.normalized()
	
	# Supprimer après 'lifetime' secondes
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
	if area.is_in_group("pnj"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
