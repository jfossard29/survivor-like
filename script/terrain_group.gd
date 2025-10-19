extends StaticBody3D


# Permet aux PNJ de spawn dessus
func _ready() -> void:
	add_to_group("terrain")
