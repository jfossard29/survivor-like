extends Node3D

# Hauteur des murs
@export var wall_height: float = 20.0
# Épaisseur des murs
@export var wall_thickness: float = 2.0
# Ajouter un plafond ?
@export var add_ceiling: bool = true

func _ready():
	_create_walls()

func _create_walls():
	# Récupère le sol dans le parent (StaticBody3D)
	var map_root = get_parent()
	var static_body := map_root.get_node_or_null("StaticBody3D")
	if not static_body:
		push_error("❌ Aucun StaticBody3D trouvé dans la map.")
		return

	var collision_shape := static_body.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		push_error("❌ Aucun CollisionShape3D trouvé dans le StaticBody3D.")
		return

	var shape := collision_shape.shape as BoxShape3D
	if not shape:
		push_error("❌ Le CollisionShape3D n'est pas un BoxShape3D.")
		return

	# Dimensions de la map
	var map_size_x = shape.extents.x * 2 + 1.0
	var map_size_z = shape.extents.z * 2 + 1.0
	var y_offset = shape.extents.y

	# Crée un StaticBody3D pour contenir tous les murs
	var borders = StaticBody3D.new()
	borders.name = "InvisibleWalls"
	add_child(borders)  # <- on ajoute seulement ici

	var half_x = map_size_x / 2
	var half_z = map_size_z / 2

	# Définition des murs (position et taille)
	var walls = {
		"north": { "pos": Vector3(0, wall_height/2 + y_offset, -half_z), "size": Vector3(half_x, wall_height/2, wall_thickness) },
		"south": { "pos": Vector3(0, wall_height/2 + y_offset, half_z), "size": Vector3(half_x, wall_height/2, wall_thickness) },
		"west":  { "pos": Vector3(-half_x, wall_height/2 + y_offset, 0), "size": Vector3(wall_thickness, wall_height/2, half_z) },
		"east":  { "pos": Vector3(half_x, wall_height/2 + y_offset, 0), "size": Vector3(wall_thickness, wall_height/2, half_z) }
	}

	# Création des CollisionShape3D pour chaque mur
	for dir in walls.keys():
		var wall_data = walls[dir]
		var shape_node = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.extents = wall_data["size"]  # taille du mur
		shape_node.shape = box
		shape_node.position = wall_data["pos"]  # position relative au StaticBody3D
		borders.add_child(shape_node)

	# Ajouter un plafond optionnel
	if add_ceiling:
		var top = CollisionShape3D.new()
		var top_box = BoxShape3D.new()
		top_box.extents = Vector3(half_x, wall_thickness, half_z)
		top.shape = top_box
		top.position = Vector3(0, wall_height + y_offset, 0)
		borders.add_child(top)
