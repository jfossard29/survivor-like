extends Area3D

@export var speed: float = 5.0
@export var stop_distance: float = 0.0
@export var damage: int = 25
@export var max_health: int = 50

var player: Node3D = null
var current_health: int
var has_attacked: bool = false

func _ready() -> void:
	current_health = max_health
	connect("body_entered", Callable(self, "_on_body_entered"))
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("✅ Joueur trouvé :", player.name)
	else:
		print("❌ ERREUR : Aucun joueur trouvé dans le groupe 'player' !")

func _physics_process(delta: float) -> void:
	if not player or has_attacked:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= stop_distance:
		return  # Trop proche, stop
	
	# Calcul direction XZ
	var direction = Vector3(
		player.global_position.x - global_position.x,
		0,
		player.global_position.z - global_position.z
	).normalized()
	
	# Rotation vers le joueur
	if direction.length() > 0.1:
		var look_target = global_position + direction
		look_target.y = global_position.y
		look_at(look_target, Vector3.UP)
	
	# Déplacement
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	# Attaque du joueur
	if not has_attacked and body.is_in_group("player"):
		print("💥 Le joueur a été touché !")
		has_attacked = true
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()  # Supprime le PNJ après attaque
		return
	
	# Touché par un projectile
	if body.is_in_group("projectile"):
		if body.has_method("damage"):
			take_damage(body.damage)
		else:
			take_damage(10)  # valeur par défaut
		# Supprimer le projectile
		body.queue_free()

func take_damage(amount: int) -> void:
	current_health -= amount
	print("PNJ touché ! PV restants :", current_health)
	if current_health <= 0:
		die()

func die() -> void:
	print("PNJ mort !")
	queue_free()
