extends CharacterBody3D

@export var projectile_scene: PackedScene
@export var max_health = 100
@export var fire_interval: float = 1.0
@export var fire_range: float = 30.0  # portée de détection des PNJ
var current_health = 100
var can_fire: bool = true
# Référence au label d'affichage des PV
@onready var health_label: Label = $"../CanvasLayer/Panel/PV/Label"

@export var speed: float = 5.0
@export var turn_speed: float = 0.8
@export var camera: Camera3D
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity: float = 0.002  # Ajuste selon ton confort
@export var pivot_camera: Node3D
@export var jump_speed: float = 5.0  # Ajuste selon la hauteur de saut
var camera_pitch: float = 0.0  # pour limiter la rotation verticale

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Tir automatique
	if can_fire:
		fire_projectile()
		can_fire = false
		await get_tree().create_timer(fire_interval).timeout
		can_fire = true

	# Appliquer la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	get_input(delta)
	move_and_slide()

func get_input(delta: float) -> void:
	var vy: float = velocity.y

	# Déplacement avant/arrière
	var forward_input: float = Input.get_axis("decelerer", "accelerer")  # S/W ou Z/S
	# Déplacement gauche/droite
	var strafe_input: float = Input.get_axis("gauche", "droite")  # Q/D

	# Calcul de la direction avant
	var forward_dir: Vector3 = -transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()

	# Calcul de la direction droite
	var right_dir: Vector3 = transform.basis.x
	right_dir.y = 0
	right_dir = right_dir.normalized()

	# Combinaison du mouvement
	var move_dir: Vector3 = forward_dir * forward_input + right_dir * strafe_input
	move_dir = move_dir.normalized() if move_dir.length() > 0 else Vector3.ZERO

	# Appliquer la vitesse
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	# Saut
	if is_on_floor() and Input.is_action_just_pressed("sauter"):
		velocity.y = jump_speed
	else:
		velocity.y = vy


	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# rotation horizontale du joueur (yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)

		# rotation verticale du pivot de la caméra (pitch)
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, -1.5, 1.5)
		pivot_camera.rotation.x = camera_pitch

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)  # Ne pas descendre en dessous de 0
	
	print("Joueur touché ! PV restants : ", current_health)
	update_health_display()
	
	# Vérifier si le joueur est mort
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)  # Ne pas dépasser le max
	update_health_display()

func update_health_display():
	if health_label:
		health_label.text = str(current_health)
	else:
		print("ERREUR : Label 'nombre' introuvable dans PV/nombre")

func die():
	print("Le joueur est mort !")
	
func fire_projectile():
	if projectile_scene == null:
		return

	var pnjs = get_tree().get_nodes_in_group("pnj")
	var closest_pnj: Node3D = null
	var closest_dist: float = fire_range + 1.0
	
	for p in pnjs:
		var d = global_position.distance_to(p.global_position)
		if d <= fire_range and d < closest_dist:
			closest_dist = d
			closest_pnj = p

	# Instance du projectile
	var projectile = projectile_scene.instantiate()

	# D'abord, on ajoute le projectile au tree
	get_tree().current_scene.add_child(projectile)

	# Ensuite, on peut calculer et appliquer position/orientation
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var start_pos: Vector3 = global_position + forward_dir * 0.8
	projectile.look_at_from_position(start_pos, start_pos + forward_dir, Vector3.UP)

	# Définir la direction du projectile
	if closest_pnj != null:
		projectile.target = closest_pnj
	else:
		projectile.direction = forward_dir
