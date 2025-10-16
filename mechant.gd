extends Area3D

@export var speed: float = 5.0
@export var stop_distance: float = 0.0
@export var damage: int = 25
var hp = 50
var player: Node3D = null
var has_attacked: bool = false


func _ready() -> void:
	# Connecte le signal de détection de corps
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Trouve le joueur dans le groupe "player"
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("✅ Joueur trouvé :", player.name)
	else:
		print("❌ ERREUR : Aucun joueur trouvé dans le groupe 'player' !")


func _physics_process(delta: float) -> void:
	if not player or has_attacked:
		return
	
	# Calculer la direction vers le joueur (X et Z seulement)
	var direction = Vector3.ZERO
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > stop_distance:
		direction.x = player.global_position.x - global_position.x
		direction.z = player.global_position.z - global_position.z
		direction = direction.normalized()
		
		# Faire tourner l’Area (utile si ton Area a un mesh visible)
		if direction.length() > 0.1:
			var look_target = global_position + direction
			look_target.y = global_position.y
			look_at(look_target, Vector3.UP)
		
		# Déplacer le PNJ (si l’Area est attachée à un parent mobile)
		global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if has_attacked:
		return
	
	if body.is_in_group("player"):
		print("💥 Le joueur est entré dans la zone !")
		has_attacked = true
		
		# Inflige des dégâts
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Supprime l’ennemi
		queue_free()

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		queue_free()
