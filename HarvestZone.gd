extends Area3D

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))

func _on_area_entered(area: Area3D):
	if area.is_in_group("experience"):
		print("🧲 Expérience détectée (via area_entered) !")
		area.start_following(get_parent())
