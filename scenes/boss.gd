extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var cached_direction = Vector3.ZERO
var has_attacked = false  # Compatibilité avec le système de ciblage

@export var speed: float = 2.0
@export var damage: int = 30
@export var max_health: float = 500.0
@export var experience_scene: PackedScene
@export var debug: bool = true
@export var hitbox: Area3D  # Area3D pour détecter les projectiles
@onready var health_bar: ProgressBar = $PV/ProgressBar

# Paramètres d'attaque
@export_group("Attack")
@export var attack_interval: float = 5.0
@export var attacks_per_salvo: int = 3
@export var attack_delay: float = 0.8
@export var warning_duration: float = 1.0
@export var attack_radius: float = 8.0
@export var cylinder_radius: float = 2.0
@export var cylinder_height: float = 5.0

var current_health: float
var is_attacking: bool = false
var attack_timer: float = 0.0
var player_ref: CharacterBody3D = null
var last_contact_time: float = 0.0
var contact_cooldown: float = 2.0

# Tween pour la barre de vie
var health_tween: Tween = null

func _ready():
	add_to_group("enemy")
	add_to_group("boss")
	GameManager.register_enemy(self)
	current_health = max_health
	
	player_ref = GameManager.player_reference
	
	if health_bar:
		_setup_health_bar()
	
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	else:
		push_warning("⚠️ Aucune Area3D assignée au boss pour détecter les projectiles!")
	
	_start_attack_cycle()

func _exit_tree():
	GameManager.unregister_enemy(self)

func _on_hitbox_body_entered(body: Node3D) -> void:
	# Détecter les projectiles du joueur (layer 4)
	if body.is_in_group("player_projectile") or body.name.begins_with("Projectile"):
		var damage_amount = 10  # Dégâts par défaut
		
		if body.has_method("get_damage"):
			damage_amount = body.get_damage()
		
		take_damage(damage_amount)
		
		if debug:
			print("💥 Projectile a touché le boss! Dégâts: ", damage_amount)
		
		if body.has_method("queue_free"):
			body.queue_free()

func _setup_health_bar() -> void:
	health_bar.visible = true
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Initialiser la couleur de la barre
	var stylebox = health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		stylebox.bg_color = Color(1, 0, 0)  # Rouge par défaut

func update_health_display():
	
	if !health_bar:
		return
	
	var ratio = current_health / max_health
	
	# Tuer l'ancien tween proprement
	if health_tween and health_tween.is_valid():
		health_tween.kill()
	
	health_tween = create_tween()
	health_tween.tween_property(health_bar, "value", ratio * health_bar.max_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Animation de couleur simplifiée
	var stylebox = health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if stylebox:
		var color_tween = create_tween()
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0.3, 0.3), 0.1)
		color_tween.tween_property(stylebox, "bg_color", Color(1, 0, 0), 0.3)

func _physics_process(delta: float) -> void:
	# Pause : ne rien faire si le jeu est en pause
	if get_tree().paused:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if is_attacking:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	
	if player_ref and is_instance_valid(player_ref):
		var look_dir = player_ref.global_position - global_position
		look_dir.y = 0
		if look_dir.length() > 0.1:
			look_at(global_position + look_dir, Vector3.UP)
	
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed
	
	move_and_slide()
	_check_player_collision()

func _start_attack_cycle() -> void:
	while is_instance_valid(self):
		# Attendre en respectant la pause
		var elapsed = 0.0
		while elapsed < attack_interval:
			await get_tree().process_frame
			if not get_tree().paused:
				elapsed += get_process_delta_time()
		
		if is_instance_valid(self) and player_ref and is_instance_valid(player_ref):
			await _perform_attack_salvo()

func _check_player_collision() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_contact_time < contact_cooldown:
		return
	
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		
		if collider and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
				last_contact_time = now
				if debug:
					print("Boss a touché le joueur par contact physique!")
				return

func _perform_attack_salvo() -> void:
	is_attacking = true
	
	for i in range(attacks_per_salvo):
		if not is_instance_valid(self) or not player_ref or not is_instance_valid(player_ref):
			break
		
		var angle = randf() * TAU
		var distance = randf_range(0, attack_radius)
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var pos = player_ref.global_position + offset
		
		var look_dir = pos - global_position
		look_dir.y = 0
		if look_dir.length() > 0.1:
			look_at(global_position + look_dir, Vector3.UP)
		
		_create_warning_zone(pos)
		
		# Attendre en respectant la pause
		var elapsed = 0.0
		while elapsed < attack_delay:
			await get_tree().process_frame
			if not get_tree().paused:
				elapsed += get_process_delta_time()
	
	is_attacking = false

func _create_warning_zone(position: Vector3) -> void:
	var warning = Node3D.new()
	get_tree().current_scene.add_child(warning)
	warning.global_position = position
	warning.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = cylinder_radius
	cyl.bottom_radius = cylinder_radius
	cyl.height = 0.1
	mesh.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	
	warning.add_child(mesh)
	mesh.position.y = 0.05
	
	_animate_warning(mesh, warning_duration)
	
	# Attendre en respectant la pause
	var elapsed = 0.0
	while elapsed < warning_duration:
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()
	
	if is_instance_valid(warning):
		_create_attack_zone(position)
		warning.queue_free()

func _animate_warning(mesh: MeshInstance3D, duration: float) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mesh, "scale", Vector3(1.2, 1, 1.2), 0.3)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1, 1.0), 0.3)
	
	# Attendre en respectant la pause
	var elapsed = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()
	
	if is_instance_valid(tween):
		tween.kill()

func _create_attack_zone(position: Vector3) -> void:
	var attack = Area3D.new()
	get_tree().current_scene.add_child(attack)
	attack.global_position = position
	attack.process_mode = Node.PROCESS_MODE_PAUSABLE
	attack.collision_layer = 256    # même couche que le boss
	attack.collision_mask = 4       # couche du joueur

	# --- Mesh visuel ---
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = cylinder_radius
	cyl.bottom_radius = cylinder_radius
	cyl.height = cylinder_height
	mesh.mesh = cyl

	# --- Shader du cylindre ---
	var shader_code = """
		shader_type spatial;
		render_mode blend_add, cull_disabled, unshaded;

		uniform vec4 neon_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
		uniform float speed : hint_range(0.0, 5.0) = 1.5;
		uniform float width : hint_range(0.01, 1.0) = 0.15;

		void fragment() {
			float y = UV.y * 2.0 - 1.0; // -1 bas, +1 haut
			float t = mod(TIME * speed, 2.0);

			// Onde montant et descendant
			float up = smoothstep(1.0 - width, 1.0, y + t);
			float down = smoothstep(1.0 - width, 1.0, -y + t);

			float glow = clamp(up + down, 0.0, 1.0);

			ALBEDO = neon_color.rgb * glow;
			ALPHA = 0.25 + glow * 0.75;
		}
	"""

	var shader = Shader.new()
	shader.code = shader_code
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	mesh.material_override = shader_mat

	attack.add_child(mesh)
	mesh.position.y = cylinder_height / 2

	# --- Collision ---
	var shape = CollisionShape3D.new()
	var s = CylinderShape3D.new()
	s.radius = cylinder_radius
	s.height = cylinder_height
	shape.shape = s
	attack.add_child(shape)
	shape.position.y = cylinder_height / 2

	# --- Détection ---
	attack.body_entered.connect(_on_attack_hit.bind(attack))

	# --- Apparition progressive ---
	mesh.scale = Vector3(0.1, 0, 0.1)
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.2)

	# --- Durée de vie ---
	var elapsed = 0.0
	while elapsed < 0.5:
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()

	if is_instance_valid(attack):
		attack.queue_free()

func _on_attack_hit(body: Node, attack_area: Area3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		if debug:
			print("Boss a touché le joueur!")
		if is_instance_valid(attack_area):
			attack_area.queue_free()

func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(0, current_health)
	update_health_display()
	
	if debug:
		print("Boss touché ! PV restants :", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("💀 Boss vaincu!")
	if health_bar:
		health_bar.visible = false
	
	if experience_scene:
		for i in range(10):
			var xp = experience_scene.instantiate()
			get_parent().add_child(xp)
			xp.global_position = global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	
	queue_free()
