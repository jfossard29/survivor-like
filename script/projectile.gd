extends Area3D

@export var speed: float = 20.0
@export var damage: int = 10
@export var lifetime: float = 2.0
@export var search_range: float = 30.0

var target: Node3D = null
var direction: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("projectile")

	# Connecte les signaux de collision
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

	# Recherche du PNJ le plus proche
	var pnjs = get_tree().get_nodes_in_group("pnj")
	var closest_dist = search_range + 1.0
	for p in pnjs:
		if not is_instance_valid(p):
			continue
		var d = global_position.distance_to(p.global_position)
		if d <= search_range and d < closest_dist:
			closest_dist = d
			target = p

	# Si aucun PNJ trouvé, tirer tout droit
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
	if area.is_in_group("pnj"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("pnj"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
