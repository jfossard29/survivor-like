extends Node3D

# Hauteur des murs
@export var wall_height: float = 20.0
# Épaisseur des murs
@export var wall_thickness: float = 2.0
# Ajouter un plafond ?
@export var add_ceiling: bool = true

# Taille de la map (sera définie par le parent)
var map_size: Vector2 = Vector2(100, 100)
var y_offset: float = 0.0

func _ready():
	_create_walls()

func _create_walls():
	var map_size_x = map_size.x
	var map_size_z = map_size.y
	
	# Crée un StaticBody3D pour contenir tous les murs
	var borders = StaticBody3D.new()
	borders.name = "InvisibleWalls"
	add_child(borders)
	
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
		box.extents = wall_data["size"]
		shape_node.shape = box
		shape_node.position = wall_data["pos"]
		borders.add_child(shape_node)
	
	# Ajouter un plafond optionnel
	if add_ceiling:
		var top = CollisionShape3D.new()
		var top_box = BoxShape3D.new()
		top_box.extents = Vector3(half_x, wall_thickness, half_z)
		top.shape = top_box
		top.position = Vector3(0, wall_height + y_offset, 0)
		borders.add_child(top)

# Fonction à appeler par le parent pour définir la taille
func set_map_dimensions(size: Vector2, offset_y: float = 0.0):
	map_size = size
	y_offset = offset_y
