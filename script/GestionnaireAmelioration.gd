extends Node

@export var nombre_de_choix: int = 3
@onready var game_manager = GameManager if Engine.has_singleton("GameManager") else null
var toutes_les_ameliorations: Array[Amelioration] = []

func get_ameliorations_random(player: CharacterBody3D) -> Array[Amelioration]:
	var toutes = [
		Amelioration.new("Dégâts +20%", "Augmente les dégâts de 20%", func(): player.damage *= 1.2),
		Amelioration.new("Vitesse +15%", "Augmente la vitesse de déplacement", func(): player.move_speed *= 1.15),
		Amelioration.new("Cadence +10%", "Réduit le délai de tir", func(): player.fire_interval *= 0.9),
		Amelioration.new("PV +25%", "Augmente les PV max", func(): player.max_health *= 1.25),
		Amelioration.new("Saut +1", "Augmente la hauteur de saut", func(): player.jump_speed += 1.0),
		Amelioration.new("XP +10%", "Augmente le taux d'expérience", func():
		if Engine.has_singleton("GameManager"):
			GameManager.xp_multiplier *= 1.10
			GameManager.emit_signal("multipliers_changed")
		),
		Amelioration.new("Récolte +10%", "Augmente la portée de collecte", func():
		if Engine.has_singleton("GameManager"):
			GameManager.pickup_scale_multiplier *= 1.10
			GameManager.emit_signal("multipliers_changed")
		# appliquer immédiatement au joueur si possible
		if player.has_node("Recolte"):
			player.get_node("Recolte").set_pickup_radius_multiplier(GameManager.pickup_scale_multiplier)
		)

	]

	toutes.shuffle()
	var selection: Array[Amelioration] = []
	for i in range(min(nombre_de_choix, toutes.size())):
		selection.append(toutes[i])
	return selection
