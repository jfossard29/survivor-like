class_name Amelioration
var name: String
var description: String
var apply_effect: Callable
var rarity: String
@export var icon: String = "⚡"  # Emoji pour l'icône
func _init(_name: String, _desc: String, _effect: Callable, _rarity: String = "common"):
	name = _name
	description = _desc
	apply_effect = _effect
	rarity = _rarity

func apply():
	if apply_effect:
		apply_effect.call()
		print("Amelioration appliquée:", name)
	else:
		print("Amelioration.apply: pas d'effet pour", name)
