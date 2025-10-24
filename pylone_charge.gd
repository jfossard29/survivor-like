extends Node3D

# Paramètres de charge
@export var charge_duration: float = 5.0
@export var detection_radius: float = 13.0
@export var begin_color: Color = Color("#ff0004") # Couleur de départ (rouge)
@export var end_color: Color = Color("#00ffff") # Couleur finale (cyan)
@export var debug_mode: bool = true

# Références internes
var area_3d: Area3D
var collision_shape: CollisionShape3D
var visual_indicator: MeshInstance3D
var mesh_instance: MeshInstance3D
var shader_material: ShaderMaterial

# État de charge
var charge_progress: float = 0.0
var is_player_inside: bool = false
var is_charged: bool = false

# Référence au GameManager
var game_manager: Node = null

func _ready() -> void:
	# Récupère le GameManager
	game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("register_pylon"):
		game_manager.register_pylon(self)
		if debug_mode:
			print("Pylône enregistré auprès du GameManager")
	else:
		push_warning("GameManager introuvable ou méthode register_pylon manquante")
	
	if debug_mode:
		print("Pylône initialisé à position: ", global_position)
	
	_setup_area3d()
	_setup_visual_indicator()
	_find_mesh_instance()
	_update_shader_color()
	
	if debug_mode:
		print("  - Area3D créée avec rayon: ", detection_radius)
		print("  - MeshInstance trouvée: ", mesh_instance != null)
		print("  - ShaderMaterial trouvé: ", shader_material != null)

func _setup_area3d() -> void:
	area_3d = Area3D.new()
	area_3d.name = "DetectionArea"
	area_3d.collision_layer = 256
	area_3d.collision_mask = 4
	add_child(area_3d)
	
	if debug_mode:
		print("Area3D configurée - Layer: 8 (", area_3d.collision_layer, ") Mask: 3 (", area_3d.collision_mask, ")")
	
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var sphere = SphereShape3D.new()
	sphere.radius = detection_radius
	collision_shape.shape = sphere
	area_3d.add_child(collision_shape)
	
	area_3d.body_entered.connect(_on_body_entered)
	area_3d.body_exited.connect(_on_body_exited)

func _setup_visual_indicator() -> void:
	visual_indicator = MeshInstance3D.new()
	visual_indicator.name = "VisualIndicator"
	
	var torus = TorusMesh.new()
	torus.inner_radius = detection_radius - 0.5
	torus.outer_radius = detection_radius
	torus.rings = 32
	torus.ring_segments = 16
	visual_indicator.mesh = torus
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	mat.emission_enabled = true
	mat.emission = begin_color
	mat.emission_energy_multiplier = 0.0
	visual_indicator.material_override = mat
	
	visual_indicator.position = Vector3(0, 0.1, 0)
	visual_indicator.rotation_degrees = Vector3(0, 0, 0)
	add_child(visual_indicator)

func _find_mesh_instance() -> void:
	mesh_instance = _find_mesh_recursive(self)
	if not mesh_instance:
		if debug_mode:
			print("Aucun MeshInstance3D trouvé dans le pylône.")
		return

	# Priorité à material_override (car c'est ce qu'utilise le générateur)
	if mesh_instance.material_override is ShaderMaterial:
		shader_material = mesh_instance.material_override
	elif mesh_instance.material_overlay is ShaderMaterial:
		shader_material = mesh_instance.material_overlay
	else:
		# Vérifie aussi les matériaux de surface
		var mesh = mesh_instance.mesh
		if mesh and mesh.get_surface_count() > 0:
			var mat = mesh.surface_get_material(0)
			if mat is ShaderMaterial:
				shader_material = mat

	if debug_mode:
		print("Shader trouvé :", shader_material != null)
		if shader_material:
			print("Matériau source :", shader_material)
			print("  Appliqué via override :", mesh_instance.material_override == shader_material)

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node != visual_indicator:
		return node
	for child in node.get_children():
		if child is MeshInstance3D and child != visual_indicator:
			return child
		var result = _find_mesh_recursive(child)
		if result:
			return result
	return null

func _on_body_entered(body: Node3D) -> void:
	if debug_mode:
		print("Pylône: Corps détecté - ", body.name)
	is_player_inside = true
	_show_indicator(true)

func _on_body_exited(body: Node3D) -> void:
	if debug_mode:
		print("Pylône: Corps sorti - ", body.name)
	is_player_inside = false
	_show_indicator(false)

func _show_indicator(visible: bool) -> void:
	if not visual_indicator:
		return
	var mat = visual_indicator.material_override as StandardMaterial3D
	if mat:
		var tween = create_tween()
		var target_alpha = 0.3 if visible else 0.0
		tween.tween_property(mat, "albedo_color:a", target_alpha, 0.3)

func _process(delta: float) -> void:
	if is_charged:
		return
	
	if is_player_inside:
		charge_progress = min(1.0, charge_progress + (delta / charge_duration))
	else:
		charge_progress = max(0.0, charge_progress - (delta / (charge_duration * 2.0)))
	
	_update_shader_color()
	_update_indicator_progress()
	
	if charge_progress >= 1.0 and not is_charged:
		_on_fully_charged()

func _update_shader_color() -> void:
	if not shader_material:
		return
	
	# Interpolation dans l'espace HSV pour éviter de passer par le blanc
	var h1 = begin_color.h
	var s1 = begin_color.s
	var v1 = begin_color.v
	
	var h2 = end_color.h
	var s2 = end_color.s
	var v2 = end_color.v
	
	# Interpoler en HSV
	var current_h = lerp(h1, h2, charge_progress)
	var current_s = lerp(s1, s2, charge_progress)
	var current_v = lerp(v1, v2, charge_progress)
	
	# Créer la couleur finale depuis HSV
	var current_color = Color.from_hsv(current_h, current_s, current_v)
	shader_material.set_shader_parameter("neon_color", current_color)

func _update_indicator_progress() -> void:
	if not visual_indicator:
		return
	var mat = visual_indicator.material_override as StandardMaterial3D
	if mat:
		# Interpolation de la couleur de l'indicateur en HSV
		var h1 = begin_color.h
		var s1 = begin_color.s
		var v1 = begin_color.v
		
		var h2 = end_color.h
		var s2 = end_color.s
		var v2 = end_color.v
		
		var current_h = lerp(h1, h2, charge_progress)
		var current_s = lerp(s1, s2, charge_progress)
		var current_v = lerp(v1, v2, charge_progress)
		
		var current_indicator_color = Color.from_hsv(current_h, current_s, current_v)
		mat.emission = current_indicator_color
		mat.emission_energy_multiplier = charge_progress * 5.0

func _on_fully_charged() -> void:
	is_charged = true
	
	# Notifie le GameManager
	if game_manager and game_manager.has_method("notify_pylon_charged"):
		game_manager.notify_pylon_charged(self)
		if debug_mode:
			print("GameManager notifié du chargement du pylône")
	
	if debug_mode:
		print("Pylône 100% chargé ! Désactivation de la zone de détection...")
	
	# Faire disparaître l'indicateur visuel
	if visual_indicator:
		var mat = visual_indicator.material_override as StandardMaterial3D
		if mat:
			var tween = create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	
	# Retirer l'Area3D de détection
	if area_3d:
		area_3d.queue_free()
		area_3d = null

func _exit_tree() -> void:
	# Sécurité : désenregistre si pas encore fait
	if is_charged and game_manager and game_manager.has_method("unregister_pylon"):
		game_manager.unregister_pylon(self)
