extends Node3D

@export var spawn_zone: NodePath
@export var pnj_scene: PackedScene
@export var max_pnj: int = 5
@export var spawn_interval: float = 3.0  # secondes

var zone: Area3D
var spawned_pnj: Array = []


func _ready():
	zone = get_node(spawn_zone)
	# Lancer la coroutine de spawn
	spawn_timer()


func spawn_timer():
	# Spawn PNJ de manière répétée
	while true:
		if spawned_pnj.size() < max_pnj:
			spawn_pnj()
		await get_tree().create_timer(spawn_interval).timeout


func spawn_pnj():
	if not zone or not pnj_scene:
		return
	
	# Calculer une position aléatoire dans la zone
	var shape = zone.get_node("CollisionShape3D").shape
	if shape is BoxShape3D:
		var extents = shape.extents
		var random_pos = Vector3(
			randf_range(-extents.x, extents.x),
			1.6,
			randf_range(-extents.z, extents.z)
		)

		# Ajouter la position de l’Area
		random_pos += zone.global_position
		
		# Instance du PNJ
		var pnj = pnj_scene.instantiate()
		pnj.global_position = random_pos
		get_parent().call_deferred("add_child", pnj)
		spawned_pnj.append(pnj)
