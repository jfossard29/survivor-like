extends RefCounted
class_name Pid3D

var _p: Vector3
var _i: Vector3
var _d: Vector3
var _prev_error: Vector3 = Vector3.ZERO
var _error_integral: Vector3 = Vector3.ZERO

func _init(p: float, i: float, d: float):
	_p = Vector3(p, p, p)
	_i = Vector3(i, i, i)
	_d = Vector3(d, d, d)

func update(error: Vector3, delta: float) -> Vector3:
	_error_integral += error * delta
	var error_derivative = (error - _prev_error) / delta
	_prev_error = error
	return _p * error + _i * _error_integral + _d * error_derivative
