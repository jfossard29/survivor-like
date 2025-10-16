extends Node3D

@export var spawn_zone: NodePath  # SpawnRoot
@export var pnj_scene: PackedScene
@export var max_pnj: int = 5
@export var spawn_interval: float = 3.0

var zone: Node3D
var spawned_pnj: Array = []

func _ready():
	zone = get_node(spawn_zone) as Node3D
	await get_tree().process_frame
	spawn_timer()

func spawn_timer():
	while true:
		# Nettoyer les PNJ morts
		for i in range(spawned_pnj.size() - 1, -1, -1):
			if not is_instance_valid(spawned_pnj[i]):
				spawned_pnj.remove_at(i)
		
		# Spawn si en dessous du max
		if spawned_pnj.size() < max_pnj:
			spawn_pnj()
		
		await get_tree().create_timer(spawn_interval).timeout

func spawn_pnj():
	if not zone or not pnj_scene:
		return
	
	var static_body = zone.get_node("StaticBody3D") as StaticBody3D
	if not static_body:
		return
	
	var shape_node = static_body.get_node("CollisionShape3D") as CollisionShape3D
	if not shape_node:
		return
	
	var shape = shape_node.shape
	if shape is BoxShape3D:
		var extents = shape.extents
		var random_pos = Vector3(
			randf_range(-extents.x, extents.x),
			1.6,
			randf_range(-extents.z, extents.z)
		) + static_body.global_position

		var pnj = pnj_scene.instantiate()
		get_parent().add_child(pnj)
		pnj.global_position = random_pos
		spawned_pnj.append(pnj)
