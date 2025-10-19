class_name Amelioration

var name: String
var description: String
var apply_effect: Callable

func _init(_name: String, _desc: String, _effect: Callable):
	name = _name
	description = _desc
	apply_effect = _effect
