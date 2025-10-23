extends Node3D

# Paramètres de charge
@export var charge_duration: float = 5.0  # Temps en secondes pour charger complètement
@export var detection_radius: float = 5.0  # Rayon de détection du joueur
@export var start_color: Color = Color("#ff1633")  # Couleur de départ
@export var end_color: Color = Color("#00ffff")  # Couleur finale (cyan)

# Références internes
var area_3d: Area3D
var collision_shape: CollisionShape3D
var visual_indicator: MeshInstance3D
var mesh_instance: MeshInstance3D
var shader_material: ShaderMaterial

# État de charge
var charge_progress: float = 0.0  # 0.0 à 1.0
var is_player_inside: bool = false
var is_charged: bool = false

func _ready() -> void:
	_setup_area3d()
	_setup_visual_indicator()
	_find_mesh_instance()
	_update_shader_color()

func _setup_area3d() -> void:
	# Créer l'Area3D
	area_3d = Area3D.new()
	area_3d.name = "DetectionArea"
	area_3d.collision_layer = 256
	area_3d.collision_mask = 4  # Détecte le layer 1 (joueur)
	add_child(area_3d)
	
	# Créer la collision sphérique
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var sphere = SphereShape3D.new()
	sphere.radius = detection_radius
	collision_shape.shape = sphere
	area_3d.add_child(collision_shape)
	
	# Connecter les signaux
	area_3d.body_entered.connect(_on_body_entered)
	area_3d.body_exited.connect(_on_body_exited)

func _setup_visual_indicator() -> void:
	# Créer un anneau visuel pour indiquer la zone
	visual_indicator = MeshInstance3D.new()
	visual_indicator.name = "VisualIndicator"
	
	# Créer un torus (anneau)
	var torus = TorusMesh.new()
	torus.inner_radius = detection_radius - 0.5
	torus.outer_radius = detection_radius
	torus.rings = 32
	torus.ring_segments = 16
	visual_indicator.mesh = torus
	
	# Matériau transparent avec émission
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)  # Invisible par défaut
	mat.emission_enabled = true
	mat.emission = start_color
	mat.emission_energy_multiplier = 2.0
	visual_indicator.material_override = mat
	
	# Positionner l'anneau au sol
	visual_indicator.position = Vector3(0, 0.1, 0)
	visual_indicator.rotation_degrees = Vector3(-90, 0, 0)  # Horizontal
	
	add_child(visual_indicator)

func _find_mesh_instance() -> void:
	# Trouver le MeshInstance3D du pylône

	
	# Récupérer le ShaderMaterial
	if mesh_instance and mesh_instance.material_override is ShaderMaterial:
		shader_material = mesh_instance.material_override

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		is_player_inside = true
		_show_indicator(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		is_player_inside = false
		_show_indicator(false)

func _show_indicator(visible: bool) -> void:
	if not visual_indicator:
		return
	
	var mat = visual_indicator.material_override as StandardMaterial3D
	if mat:
		if visible:
			# Afficher l'anneau avec fade in
			var tween = create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.3, 0.3)
		else:
			# Cacher l'anneau avec fade out
			var tween = create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)

func _process(delta: float) -> void:
	if is_charged:
		return
	
	# Mettre à jour la charge
	if is_player_inside:
		charge_progress = min(1.0, charge_progress + (delta / charge_duration))
	else:
		# Décharge lente si le joueur part
		charge_progress = max(0.0, charge_progress - (delta / (charge_duration * 2.0)))
	
	# Mettre à jour la couleur du shader
	_update_shader_color()
	
	# Mettre à jour l'indicateur visuel
	_update_indicator_progress()
	
	# Vérifier si complètement chargé
	if charge_progress >= 1.0:
		_on_fully_charged()

func _update_shader_color() -> void:
	if not shader_material:
		return
	
	# Interpoler entre start_color et end_color
	var current_color = start_color.lerp(end_color, charge_progress)
	shader_material.set_shader_parameter("neon_color", current_color)

func _update_indicator_progress() -> void:
	if not visual_indicator:
		return
	
	var mat = visual_indicator.material_override as StandardMaterial3D
	if mat:
		# Changer la couleur de l'anneau selon la progression
		var indicator_color = start_color.lerp(end_color, charge_progress)
		mat.emission = indicator_color
		
		# Augmenter l'intensité avec la progression
		mat.emission_energy_multiplier = 2.0 + (charge_progress * 3.0)

func _on_fully_charged() -> void:
	is_charged = true
	print("Pylône chargé !")
	
	# Animation de disparition
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Faire disparaître le pylône
	if mesh_instance:
		tween.tween_property(mesh_instance, "scale", Vector3.ZERO, 0.5)
	
	# Faire disparaître l'indicateur
	if visual_indicator:
		var mat = visual_indicator.material_override as StandardMaterial3D
		if mat:
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	
	# Supprimer le pylône après l'animation
	tween.chain().tween_callback(queue_free)
