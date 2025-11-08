extends Area3D

@export var damage: int = 5
@export var radius: float = 3.0:
	set(value):
		radius = value
		update_collision_and_mesh()
@export var tick_rate: float = 2.0  # Nombre de ticks de dégâts par seconde

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var damage_timer: float = 0.0
var enemies_in_range: Array[Node3D] = []

func _ready():
	add_to_group("aura")
	
	# Connecter les signaux de détection
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	
	# Initialiser la taille
	update_collision_and_mesh()
	
	print("✨ Aura ready - Rayon: ", radius, " - Dégâts: ", damage)

func _physics_process(delta: float) -> void:
	# Timer pour les ticks de dégâts
	damage_timer += delta
	
	var tick_interval = 1.0 / tick_rate if tick_rate > 0 else 1.0
	
	if damage_timer >= tick_interval:
		apply_damage_to_enemies()
		damage_timer = 0.0

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and not enemies_in_range.has(body):
		enemies_in_range.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("enemy") and enemies_in_range.has(body):
		enemies_in_range.erase(body)

func apply_damage_to_enemies() -> void:
	# Nettoyer les ennemis invalides
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	
	if enemies_in_range.is_empty():
		return
	
	# Appliquer les dégâts à tous les ennemis dans la zone
	for enemy in enemies_in_range:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

func update_collision_and_mesh() -> void:
	if not collision_shape or not mesh_instance:
		await ready  # Attendre que les nodes soient prêts
		if not collision_shape or not mesh_instance:
			return
	
	# Mettre à jour la CollisionShape (cylindre)
	var cylinder_shape: CylinderShape3D = collision_shape.shape
	if cylinder_shape:
		cylinder_shape.radius = radius
		cylinder_shape.height = 2.0  # Hauteur fixe, peut être paramétrable
	
	# Mettre à jour le Mesh (cylindre)
	var cylinder_mesh: CylinderMesh = mesh_instance.mesh
	if cylinder_mesh:
		cylinder_mesh.top_radius = radius
		cylinder_mesh.bottom_radius = radius
		cylinder_mesh.height = 2.0  # Même hauteur que la collision
