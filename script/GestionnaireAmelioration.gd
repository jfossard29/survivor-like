extends Node

@export var nombre_de_choix: int = 3

func get_ameliorations_random(player: CharacterBody3D) -> Array[Amelioration]:
	var available = []
	
	# === AMÉLIORATIONS GÉNÉRALES DU JOUEUR ===
	var rarity = _roll_rarity()
	var multiplier = _get_rarity_multiplier(rarity)
	
	available.append(Amelioration.new(
		"Vitesse +%d%%" % int(5 * multiplier), 
		"Augmente la vitesse de déplacement", 
		func(): player.move_speed *= (1.0 + 0.05 * multiplier),
		rarity
	))
	
	rarity = _roll_rarity()
	multiplier = _get_rarity_multiplier(rarity)
	available.append(Amelioration.new(
		"PV Max +%d%%" % int(10 * multiplier), 
		"Augmente les PV max et restaure la vie", 
		func(): 
			player.max_health *= (1.0 + 0.10 * multiplier)
			player.current_health = player.max_health
			player.update_health_display(),
		rarity
	))
	
	rarity = _roll_rarity()
	multiplier = _get_rarity_multiplier(rarity)
	available.append(Amelioration.new(
		"Saut +%d" % int(1 * multiplier), 
		"Augmente la hauteur de saut", 
		func(): player.jump_speed += (1.0 * multiplier),
		rarity
	))
	
	rarity = _roll_rarity()
	multiplier = _get_rarity_multiplier(rarity)
	available.append(Amelioration.new(
		"XP +%d%%" % int(10 * multiplier), 
		"Augmente le taux d'expérience", 
		func():
			GameManager.xp_multiplier *= (1.0 + 0.10 * multiplier)
			GameManager.emit_signal("multipliers_changed"),
		rarity
	))
	
	rarity = _roll_rarity()
	multiplier = _get_rarity_multiplier(rarity)
	available.append(Amelioration.new(
		"Récolte +%d%%" % int(15 * multiplier), 
		"Augmente la portée de collecte", 
		func():
			GameManager.pickup_scale_multiplier *= (1.0 + 0.15 * multiplier)
			GameManager.emit_signal("multipliers_changed")
			if player.has_node("Recolte"):
				player.get_node("Recolte").set_pickup_radius_multiplier(GameManager.pickup_scale_multiplier),
		rarity
	))
	
	# Amélioration spéciale: Luck
	rarity = _roll_rarity()
	multiplier = _get_rarity_multiplier(rarity)
	available.append(Amelioration.new(
		"Chance +%d" % int(5 * multiplier),
		"Augmente la qualité des améliorations futures",
		func(): 
			RarityManager.add_luck(5 * multiplier),
		rarity
	))
	
	# === ARME DE BASE (basic_gun) ===
	if not WeaponManager.has_weapon("basic_gun"):
		rarity = _roll_rarity()
		available.append(Amelioration.new(
			"Pistolet de Base",
			"Débloquer l'arme de base",
			func(): player._create_basic_weapon(),
			rarity
		))
	else:
		var basic = WeaponManager.get_weapon("basic_gun")
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Pistolet: +%d Dégâts" % int(1 * multiplier),
			"Augmente les dégâts de base",
			func(): basic.add_flat_damage(1.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Pistolet: +%d%% Dégâts" % int(10 * multiplier),
			"Augmente les dégâts de 10%",
			func(): basic.add_damage_multiplier(10.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Pistolet: +%d%% Cadence" % int(5 * multiplier),
			"Tire plus rapidement",
			func(): basic.add_fire_rate(5.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Pistolet: +%d%% Portée" % int(10 * multiplier),
			"Augmente la portée d'attaque",
			func(): basic.add_range(10.0 * multiplier),
			rarity
		))
	
	# === AURA ===
	if not WeaponManager.has_weapon("aura"):
		rarity = _roll_rarity()
		available.append(Amelioration.new(
			"Aura de Dégâts",
			"Débloquer une aura qui blesse les ennemis proches",
			func(): player._create_aura_weapon(),
			rarity
		))
	else:
		var aura = WeaponManager.get_weapon("aura")
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Aura: +%d Dégâts" % int(1 * multiplier),
			"Augmente les dégâts de base",
			func(): aura.add_flat_damage(1.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Aura: +%d%% Dégâts" % int(10 * multiplier),
			"Augmente les dégâts de 10%",
			func(): aura.add_damage_multiplier(10.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Aura: +%d%% Portée" % int(10 * multiplier),
			"Augmente le rayon de l'aura",
			func(): aura.add_range(10.0 * multiplier),
			rarity
		))
	
	# === RICOCHET ===
	if not WeaponManager.has_weapon("ricochet"):
		rarity = _roll_rarity()
		available.append(Amelioration.new(
			"Fusil à Ricochet",
			"Débloquer une arme qui rebondit d'ennemi en ennemi",
			func(): player._create_ricochet_weapon(),
			rarity
		))
	else:
		var ricochet = WeaponManager.get_weapon("ricochet")
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Ricochet: +%d Dégâts" % int(1 * multiplier),
			"Augmente les dégâts de base",
			func(): ricochet.add_flat_damage(1.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Ricochet: +%d%% Dégâts" % int(10 * multiplier),
			"Augmente les dégâts de 10%",
			func(): ricochet.add_damage_multiplier(10.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Ricochet: +%d%% Cadence" % int(5 * multiplier),
			"Tire plus rapidement",
			func(): ricochet.add_fire_rate(5.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Ricochet: +%d%% Portée" % int(10 * multiplier),
			"Augmente la portée et la distance de rebond",
			func(): ricochet.add_range(10.0 * multiplier),
			rarity
		))
		
		rarity = _roll_rarity()
		multiplier = _get_rarity_multiplier(rarity)
		available.append(Amelioration.new(
			"Ricochet: +%d Rebond" % int(1 * multiplier),
			"Ajoute un ricochet supplémentaire",
			func(): ricochet.add_bounce_count(int(1 * multiplier)),
			rarity
		))
	
	# Mélanger et sélectionner
	available.shuffle()
	var selection: Array[Amelioration] = []
	for i in range(min(nombre_de_choix, available.size())):
		selection.append(available[i])
	
	return selection

func _roll_rarity() -> String:
	"""Tire une rareté aléatoire"""
	return RarityManager.roll_rarity()

func _get_rarity_multiplier(rarity: String) -> float:
	"""Obtient le multiplicateur de stats pour une rareté"""
	return RarityManager.get_stat_multiplier(rarity)
