extends RigidBody3D

var _pid := Pid3D.new(1.0,0.1,1.0)
const TARGET_SPEED = 1.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var direction = Vector3(
		Input.get_action_strength("droite") - Input.get_action_strength("gauche"),
		0.0,
		Input.get_action_strength("decelerer") - Input.get_action_strength("accelerer")
	).normalized()
	
	var target_velocity = direction * TARGET_SPEED
	var velocity_error = target_velocity - linear_velocity
	var correction_impulse = _pid.update(velocity_error,delta) * 0.001
	apply_central_impulse(correction_impulse)
