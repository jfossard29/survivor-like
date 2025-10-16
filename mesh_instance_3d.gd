extends MeshInstance3D

func _physics_process(_delta : float) -> void:
	rotate(Vector3(0,1,0), PI/100)
