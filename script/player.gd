extends CharacterBody3D

@export var projectile_scene: PackedScene
@export var base_projectile_speed: float = 20.0
@export var max_health: float = 100.0
@export var base_damage: int = 10
@export var base_speed: float = 5.0
@export var base_fire_interval: float = 1.0
@export var fire_range: float = 30.0
@export var turn_speed: float = 0.8
@export var camera: Camera3D
@export var xp_to_next_level: float = 100.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity: float = 0.002
@export var pivot_camera: Node3D
@export var jump_speed: float = 5.0
@onready var health_bar: ProgressBar = $"../CanvasLayer/Panel/PV/ProgressBar"
@onready var experience_bar: ProgressBar = $"../CanvasLayer/Panel/Experience/ProgressBar"
@onready var recolte: Area3D = $Recolte
@onready var popup_multi: CanvasLayer = $"../Amelioration"
@onready var tween := create_tween()
@onready var amelioration_manager: Node = $"../AmeliorationManager"
var camera_pitch: float = 0.0
var current_health: float = 100.0
var current_experience: float = 0.0
var level: int = 1
var experience_to_next_level: float = 100.0

var can_fire: bool = true
var damage: int
var move_speed: float
var fire_interval: float
var projectile_speed: float
var ameliorations_en_attente: Array[Amelioration] = []
var base_radius: float = 1.0
var radius_multiplier: float = 1.0

func _ready():
	add_to_group("player")
	update_stats()
	update_health_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if recolte:
		recolte.connect("area_entered", Callable(self, "_on_harvest_zone_entered"))


	
func update_stats():
	damage = base_damage + (level - 1) * 2
	move_speed = base_speed + (level - 1) * 0.3
	fire_interval = base_fire_interval * pow(0.95, level - 1) # cadence un peu plus rapide
	projectile_speed = base_projectile_speed + (level - 1) * 1.5
	if Engine.has_singleton("GameManager"):
		recolte.set_pickup_radius_multiplier(GameManager.pickup_scale_multiplier)

func level_up():
	# Animation spéciale quand on monte de niveau (barre bleue pulse plusieurs fois)
	var stylebox = experience_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var flash = create_tween()
		for i in range(3):
			flash.tween_property(stylebox, "bg_color", Color(0.6, 0.8, 1), 0.1)
			flash.tween_property(stylebox, "bg_color", Color(0.2, 0.4, 1), 0.1)
			
	level += 1
	xp_to_next_level *= 1.25
	move_speed += 0.2
	fire_interval = max(0.3, fire_interval - 0.05)

	var choix = amelioration_manager.get_ameliorations_random(self)
	popup_multi.afficher(choix)



	
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
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

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

	update_health_display()
	
	# Vérifier si le joueur est mort
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)  # Ne pas dépasser le max
	update_health_display()

func update_health_display():
	if not health_bar:
		return
	var ratio = current_health / max_health
	tween.kill() # évite d’empiler les tweens
	tween = create_tween()
	tween.tween_property(health_bar, "value", ratio * health_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Animation de couleur : passe du rouge foncé au rouge vif brièvement
	var stylebox = health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		stylebox.bg_color = Color(1, 0, 0)
		var pulse_tween = create_tween()
		pulse_tween.tween_property(stylebox, "bg_color", Color(1, 0.2, 0.2), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pulse_tween.tween_property(stylebox, "bg_color", Color(1, 0, 0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func die():
	print("Le joueur est mort !")
	
func fire_projectile():
	if projectile_scene == null or not can_fire:
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
	get_tree().current_scene.add_child(projectile)

	# Position et direction de départ
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var start_pos: Vector3 = global_position + forward_dir * 0.8
	projectile.look_at_from_position(start_pos, start_pos + forward_dir, Vector3.UP)

	# On passe les stats du joueur
	projectile.damage = damage
	projectile.speed = projectile_speed

	# Ciblage
	if closest_pnj != null:
		projectile.target = closest_pnj
	else:
		projectile.direction = forward_dir

	# Gestion de la cadence
	can_fire = false
	await get_tree().create_timer(fire_interval).timeout
	can_fire = true
	
func _on_harvest_zone_entered(body: Node) -> void:
	if body.is_in_group("experience"):
		body.start_following(self)
		
func add_experience(amount: float):
	current_experience += amount
	update_experience_bar()

	while current_experience >= xp_to_next_level:
		current_experience -= xp_to_next_level
		level_up()


func update_experience_bar():
	if not experience_bar:
		return
	var ratio = current_experience / xp_to_next_level
	tween.kill()
	tween = create_tween()
	tween.tween_property(experience_bar, "value", ratio * experience_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Pulse bleu clair quand on gagne de l'XP
	var stylebox = experience_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		stylebox.bg_color = Color(0.2, 0.4, 1)
		var pulse_tween = create_tween()
		pulse_tween.tween_property(stylebox, "bg_color", Color(0.4, 0.6, 1), 0.15)
		pulse_tween.tween_property(stylebox, "bg_color", Color(0.2, 0.4, 1), 0.4)

func apply_pickup_multiplier(mult: float) -> void:
	if recolte and recolte.has_method("add_pickup_radius_multiplier"):
		recolte.add_pickup_radius_multiplier(mult)
