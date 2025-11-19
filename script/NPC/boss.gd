extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var cached_direction = Vector3.ZERO
var can_attack = false

@export var speed: float = 2.0
@export var damage: int = 30
@export var max_health: int = 500
@export var experience_scene: PackedScene
@export var debug: bool = false
@export var hitbox: Area3D
@onready var rayon_template: MeshInstance3D = $Corps/rayon

var boss_health_ui: CanvasLayer = null

@export_group("Attack")
@export var attack_interval: float = 5.0
@export var attacks_per_salvo: int = 3
@export var attack_delay: float = 0.8
@export var warning_duration: float = 1.0
@export var attack_radius: float = 8.0
@export var cylinder_radius: float = 2.0
@export var cylinder_height: float = 5.0
@export var rayon_animation_duration: float = 0.5
@export var prediction_distance: float = 3.0

var current_health: int
var is_attacking: bool = false
var player_ref: Node3D = null
var last_contact_time: float = 0.0
var contact_cooldown: float = 2.0
var is_dead: bool = false
var active_effects: Array = []
var active_tweens: Array = []  # Nouveau: tracker les tweens

func _ready():
	add_to_group("enemy")
	GameManager.enemy_manager.register_enemy(self)
	current_health = max_health

	await get_tree().process_frame
	player_ref = GameManager.get_player()
	
	if debug and player_ref:
		print("🎯 Boss a trouvé le joueur:", player_ref.name)
	elif debug:
		print("⚠️ Boss n'a pas trouvé le joueur!")
	
	_register_with_ui()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_start_attack_cycle()

func _register_with_ui() -> void:
	boss_health_ui = get_tree().root.find_child("BossHealthUI", true, false)
	if boss_health_ui:
		boss_health_ui.register_boss(self, max_health)

func _exit_tree():
	_immediate_cleanup()
	GameManager.enemy_manager.unregister_enemy(self)
	
	if boss_health_ui and is_instance_valid(boss_health_ui):
		if boss_health_ui.has_method("unregister_boss"):
			boss_health_ui.unregister_boss(self)

func _on_hitbox_body_entered(body: Node3D) -> void:
	if is_dead:
		return
		
	if body.is_in_group("player_projectile") or body.name.begins_with("Projectile"):
		var damage_amount = 10
		
		if body.has_method("get_damage"):
			damage_amount = body.get_damage()
		
		take_damage(damage_amount)
		
		if debug:
			print("💥 Projectile a touché le boss! Dégâts: ", damage_amount)
		
		if body.has_method("queue_free"):
			body.queue_free()

func update_health_display():
	if boss_health_ui and is_instance_valid(boss_health_ui):
		if boss_health_ui.has_method("update_boss_health"):
			boss_health_ui.update_boss_health(self, current_health, max_health)

func _get_player_position() -> Vector3:
	if not player_ref or not is_instance_valid(player_ref):
		return global_position
	return player_ref.global_position

func _get_player_velocity() -> Vector3:
	if not player_ref or not is_instance_valid(player_ref):
		return Vector3.ZERO
	
	if player_ref is CharacterBody3D:
		return player_ref.velocity
	
	return Vector3.ZERO

func _predict_player_position() -> Vector3:
	var current_pos = _get_player_position()
	var player_velocity = _get_player_velocity()
	
	player_velocity.y = 0
	
	if player_velocity.length() < 0.5:
		return current_pos
	
	var predicted_offset = player_velocity.normalized() * prediction_distance
	return current_pos + predicted_offset

func _physics_process(delta: float) -> void:
	# ✅ Vérification critique en premier
	if not is_inside_tree() or is_dead:
		return
	
	var tree = get_tree()
	if not tree or tree.paused:
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
		var player_pos = _get_player_position()
		var look_dir = player_pos - global_position
		look_dir.y = 0
		
		if look_dir.length() > 0.1:
			look_at(global_position + look_dir, Vector3.UP)
			
			if not is_attacking:
				cached_direction = look_dir.normalized()
	
	velocity.x = cached_direction.x * speed
	velocity.z = cached_direction.z * speed
	
	move_and_slide()
	_push_player_if_colliding()
	_check_player_collision()

func _push_player_if_colliding() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref):
		return
	
	if not player_ref is CharacterBody3D:
		return
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider == player_ref:
			var push_direction = (player_ref.global_position - global_position).normalized()
			push_direction.y = 0
			
			var push_force = speed * 5.0
			player_ref.velocity.x = push_direction.x * push_force
			player_ref.velocity.z = push_direction.z * push_force
			
			if debug:
				print("Boss pousse le joueur!")
			return

func _start_attack_cycle() -> void:
	while is_instance_valid(self) and not is_dead and is_inside_tree():
		var elapsed = 0.0
		while elapsed < attack_interval and not is_dead and is_inside_tree():
			await get_tree().process_frame
			
			# ✅ Vérifications critiques après chaque await
			if not is_instance_valid(self) or is_dead or not is_inside_tree():
				return
			
			var tree = get_tree()
			if not tree or tree.paused:
				continue
			
			elapsed += get_process_delta_time()
		
		# ✅ Vérifications avant l'attaque
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			return
		
		if player_ref and is_instance_valid(player_ref):
			await _perform_attack_salvo()

func _check_player_collision() -> void:
	if is_dead:
		return
		
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_contact_time < contact_cooldown:
		return
	
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		
		if collider and (collider.is_in_group("player") or collider.get_parent().is_in_group("player")):
			var target = collider if collider.has_method("take_damage") else collider.get_parent()
			
			if target and target.has_method("take_damage"):
				target.take_damage(damage)
				last_contact_time = now
				if debug:
					print("Boss a touché le joueur par contact physique!")
				return

func _perform_attack_salvo() -> void:
	if is_dead or not is_inside_tree():
		return
		
	is_attacking = true
	
	for i in range(attacks_per_salvo):
		# ✅ Vérifications à chaque itération
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			break
		
		if not player_ref or not is_instance_valid(player_ref):
			break
		
		var predicted_pos = _predict_player_position()
		
		var pos: Vector3
		if i == 0:
			pos = predicted_pos
		else:
			var angle = randf() * TAU
			var distance = randf_range(0, cylinder_radius * 1.5)
			var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
			pos = predicted_pos + offset
		
		var look_dir = pos - global_position
		look_dir.y = 0
		if look_dir.length() > 0.1:
			look_at(global_position + look_dir, Vector3.UP)
		
		_create_warning_zone(pos)
		
		# ✅ Attente sécurisée
		var elapsed = 0.0
		while elapsed < attack_delay and not is_dead and is_inside_tree():
			await get_tree().process_frame
			
			if not is_instance_valid(self) or is_dead or not is_inside_tree():
				is_attacking = false
				return
			
			var tree = get_tree()
			if not tree or tree.paused:
				continue
			
			elapsed += get_process_delta_time()
	
	is_attacking = false

func _create_warning_zone(position: Vector3) -> void:
	if is_dead or not is_inside_tree():
		return
	
	var tree = get_tree()
	if not tree or not tree.current_scene or not is_instance_valid(tree.current_scene):
		return
	
	var warning = Node3D.new()
	tree.current_scene.add_child(warning)
	warning.global_position = position
	warning.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	active_effects.append(warning)
	
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
	
	# ✅ Attente sécurisée
	var elapsed = 0.0
	while elapsed < warning_duration and not is_dead and is_inside_tree() and is_instance_valid(warning):
		await get_tree().process_frame
		
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			if is_instance_valid(warning):
				active_effects.erase(warning)
				warning.queue_free()
			return
		
		var tree_check = get_tree()
		if not tree_check or tree_check.paused:
			continue
		
		elapsed += get_process_delta_time()
	
	if is_instance_valid(warning):
		active_effects.erase(warning)
		
		if not is_dead and is_inside_tree():
			var tree_check = get_tree()
			if tree_check and tree_check.current_scene:
				_create_attack_zone(position)
		
		warning.queue_free()

func _animate_warning(mesh: MeshInstance3D, duration: float) -> void:
	if is_dead or not is_inside_tree() or not is_instance_valid(mesh):
		return
	
	var tween = create_tween()
	active_tweens.append(tween)  # ✅ Tracker le tween
	
	tween.set_loops()
	tween.tween_property(mesh, "scale", Vector3(1.2, 1, 1.2), 0.3)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1, 1.0), 0.3)
	
	var elapsed = 0.0
	while elapsed < duration and not is_dead and is_inside_tree():
		await get_tree().process_frame
		
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			if is_instance_valid(tween):
				active_tweens.erase(tween)
				tween.kill()
			return
		
		var tree = get_tree()
		if not tree or tree.paused:
			continue
		
		elapsed += get_process_delta_time()
	
	if is_instance_valid(tween):
		active_tweens.erase(tween)
		tween.kill()

func _create_attack_zone(position: Vector3) -> void:
	if is_dead or not is_inside_tree():
		return
	
	var tree = get_tree()
	if not tree or not tree.current_scene or not is_instance_valid(tree.current_scene):
		return
	
	var attack = Area3D.new()
	tree.current_scene.add_child(attack)
	attack.global_position = position
	attack.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	active_effects.append(attack)
	
	attack.collision_layer = 0
	attack.collision_mask = 4
	
	var shape = CollisionShape3D.new()
	var s = CylinderShape3D.new()
	s.radius = cylinder_radius
	s.height = cylinder_height
	shape.shape = s
	attack.add_child(shape)
	shape.position.y = cylinder_height / 2
	
	attack.body_entered.connect(_on_attack_hit.bind(attack))
	
	if debug:
		print("🔴 Zone d'attaque créée à ", position)
	
	_animate_rayons(position)
	
	# ✅ Attente sécurisée
	var elapsed = 0.0
	while elapsed < 0.5 and not is_dead and is_inside_tree() and is_instance_valid(attack):
		await get_tree().process_frame
		
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			if is_instance_valid(attack):
				active_effects.erase(attack)
				attack.queue_free()
			return
		
		var tree_check = get_tree()
		if not tree_check or tree_check.paused:
			continue
		
		elapsed += get_process_delta_time()
	
	if is_instance_valid(attack):
		active_effects.erase(attack)
		attack.queue_free()

func _animate_rayons(position: Vector3) -> void:
	if is_dead or not rayon_template or not is_inside_tree():
		return
	
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	
	var rayon_haut = rayon_template.duplicate()
	tree.current_scene.add_child(rayon_haut)
	rayon_haut.global_position = position + Vector3(0, cylinder_height, 0)
	rayon_haut.visible = true
	rayon_haut.scale = Vector3(1, 0, 1)
	active_effects.append(rayon_haut)
	
	var rayon_bas = rayon_template.duplicate()
	tree.current_scene.add_child(rayon_bas)
	rayon_bas.global_position = position
	rayon_bas.visible = true
	rayon_bas.scale = Vector3(1, 0, 1)
	active_effects.append(rayon_bas)
	
	var tween = create_tween()
	active_tweens.append(tween)  # ✅ Tracker le tween
	
	tween.set_parallel(true)
	tween.tween_property(rayon_haut, "scale", Vector3(1, 1, 1), rayon_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(rayon_haut, "position:y", position.y + cylinder_height / 2, rayon_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(rayon_bas, "scale", Vector3(1, 1, 1), rayon_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(rayon_bas, "position:y", position.y + cylinder_height / 2, rayon_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# ✅ Attente sécurisée
	var elapsed = 0.0
	while elapsed < rayon_animation_duration * 0.5 and not is_dead and is_inside_tree():
		await get_tree().process_frame
		
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			_cleanup_rayons(rayon_haut, rayon_bas, tween)
			return
		
		var tree_check = get_tree()
		if not tree_check or tree_check.paused:
			continue
		
		elapsed += get_process_delta_time()
	
	if is_dead or not is_inside_tree():
		_cleanup_rayons(rayon_haut, rayon_bas, tween)
		return
	
	var fade_tween = create_tween()
	active_tweens.append(fade_tween)
	
	fade_tween.set_parallel(true)
	fade_tween.tween_property(rayon_haut, "scale", Vector3(0, 0, 0), rayon_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(rayon_bas, "scale", Vector3(0, 0, 0), rayon_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	elapsed = 0.0
	while elapsed < rayon_animation_duration * 0.5 and not is_dead and is_inside_tree():
		await get_tree().process_frame
		
		if not is_instance_valid(self) or is_dead or not is_inside_tree():
			_cleanup_rayons(rayon_haut, rayon_bas, fade_tween)
			return
		
		var tree_check = get_tree()
		if not tree_check or tree_check.paused:
			continue
		
		elapsed += get_process_delta_time()
	
	_cleanup_rayons(rayon_haut, rayon_bas, fade_tween)

func _cleanup_rayons(rayon_haut: Variant, rayon_bas: Variant, tween: Variant) -> void:
	if tween != null and is_instance_valid(tween):
		active_tweens.erase(tween)
		tween.kill()
	
	if rayon_haut != null and is_instance_valid(rayon_haut):
		active_effects.erase(rayon_haut)
		rayon_haut.queue_free()
	
	if rayon_bas != null and is_instance_valid(rayon_bas):
		active_effects.erase(rayon_bas)
		rayon_bas.queue_free()

func _on_attack_hit(body: Node, attack_area: Area3D) -> void:
	if is_dead:
		return
		
	if debug:
		print("🎯 Quelque chose est entré dans la zone d'attaque: ", body.name)
	
	var is_player = body.is_in_group("player") or (body.get_parent() and body.get_parent().is_in_group("player"))
	
	if is_player:
		var target = body if body.has_method("take_damage") else body.get_parent()
		
		if target and target.has_method("take_damage"):
			target.take_damage(damage)
			if debug:
				print("✅ Boss a touché le joueur! Dégâts infligés: ", damage)
			if is_instance_valid(attack_area):
				attack_area.queue_free()

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	current_health -= amount
	current_health = max(0, current_health)
	update_health_display()
	
	if debug:
		print("Boss touché ! PV restants :", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func _immediate_cleanup() -> void:
	"""Nettoyer immédiatement tous les effets et animations"""
	is_dead = true
	is_attacking = false
	
	set_process(false)
	set_physics_process(false)
	
	# ✅ Nettoyer TOUS les tweens actifs
	for tween in active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()
	
	# ✅ Nettoyer tous les effets visuels
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.set_process(false)
			effect.set_physics_process(false)
			effect.hide()
			effect.queue_free()
	active_effects.clear()

func die() -> void:
	if is_dead:
		return
	
	_immediate_cleanup()
	
	print("💀 Boss vaincu!")
	
	if experience_scene:
		var tree = get_tree()
		if tree and tree.current_scene and is_instance_valid(tree.current_scene):
			var parent = get_parent()
			if parent and is_instance_valid(parent):
				for i in range(10):
					var xp = experience_scene.instantiate()
					parent.add_child(xp)
					xp.global_position = global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	
	queue_free()
