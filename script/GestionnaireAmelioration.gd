extends Node

@export var nombre_de_choix: int = 3

func get_ameliorations_random(player: CharacterBody3D) -> Array[Amelioration]:
	# ✅ Accès direct au singleton WeaponManager (pas via player)
	var available = []
	
	# === AMÉLIORATIONS GÉNÉRALES DU JOUEUR ===
	available.append(Amelioration.new(
		"Vitesse +5%", 
		"Augmente la vitesse de déplacement", 
		func(): player.move_speed *= 1.05
	))
	
	available.append(Amelioration.new(
		"PV Max +10%", 
		"Augmente les PV max et restaure la vie", 
		func(): 
			player.max_health *= 1.10
			player.current_health = player.max_health
			player.update_health_display()
	))
	
	available.append(Amelioration.new(
		"Saut +1", 
		"Augmente la hauteur de saut", 
		func(): player.jump_speed += 1.0
	))
	
	available.append(Amelioration.new(
		"XP +10%", 
		"Augmente le taux d'expérience", 
		func():
			GameManager.xp_multiplier *= 1.10
			GameManager.emit_signal("multipliers_changed")
	))
	
	available.append(Amelioration.new(
		"Récolte +15%", 
		"Augmente la portée de collecte", 
		func():
			GameManager.pickup_scale_multiplier *= 1.15
			GameManager.emit_signal("multipliers_changed")
			if player.has_node("Recolte"):
				player.get_node("Recolte").set_pickup_radius_multiplier(GameManager.pickup_scale_multiplier)
	))
	
	# === ARME DE BASE (basic_gun) ===
	if not WeaponManager.has_weapon("basic_gun"):
		available.append(Amelioration.new(
			"Pistolet de Base",
			"Débloquer l'arme de base",
			func(): player._create_basic_weapon()
		))
	else:
		var basic = WeaponManager.get_weapon("basic_gun")
		
		available.append(Amelioration.new(
			"Pistolet: +1 Dégâts",
			"Augmente les dégâts de base",
			func(): basic.add_flat_damage(1.0)
		))
		
		available.append(Amelioration.new(
			"Pistolet: +10% Dégâts",
			"Augmente les dégâts de 10%",
			func(): basic.add_damage_multiplier(10.0)
		))
		
		available.append(Amelioration.new(
			"Pistolet: +5% Cadence",
			"Tire plus rapidement",
			func(): basic.add_fire_rate(5.0)
		))
		
		available.append(Amelioration.new(
			"Pistolet: +10% Portée",
			"Augmente la portée d'attaque",
			func(): basic.add_range(10.0)
		))
	
	# === AURA ===
	if not WeaponManager.has_weapon("aura"):
		available.append(Amelioration.new(
			"Aura de Dégâts",
			"Débloquer une aura qui blesse les ennemis proches",
			func(): player._create_aura_weapon()
		))
	else:
		var aura = WeaponManager.get_weapon("aura")
		
		available.append(Amelioration.new(
			"Aura: +1 Dégâts",
			"Augmente les dégâts de base",
			func(): aura.add_flat_damage(1.0)
		))
		
		available.append(Amelioration.new(
			"Aura: +10% Dégâts",
			"Augmente les dégâts de 10%",
			func(): aura.add_damage_multiplier(10.0)
		))
		
		available.append(Amelioration.new(
			"Aura: +10% Portée",
			"Augmente le rayon de l'aura",
			func(): aura.add_range(10.0)
		))
	
	# === RICOCHET ===
	if not WeaponManager.has_weapon("ricochet"):
		available.append(Amelioration.new(
			"Fusil à Ricochet",
			"Débloquer une arme qui rebondit d'ennemi en ennemi",
			func(): player._create_ricochet_weapon()
		))
	else:
		var ricochet = WeaponManager.get_weapon("ricochet")
		
		available.append(Amelioration.new(
			"Ricochet: +1 Dégâts",
			"Augmente les dégâts de base",
			func(): ricochet.add_flat_damage(1.0)
		))
		
		available.append(Amelioration.new(
			"Ricochet: +10% Dégâts",
			"Augmente les dégâts de 10%",
			func(): ricochet.add_damage_multiplier(10.0)
		))
		
		available.append(Amelioration.new(
			"Ricochet: +5% Cadence",
			"Tire plus rapidement",
			func(): ricochet.add_fire_rate(5.0)
		))
		
		available.append(Amelioration.new(
			"Ricochet: +10% Portée",
			"Augmente la portée et la distance de rebond",
			func(): ricochet.add_range(10.0)
		))
		
		available.append(Amelioration.new(
			"Ricochet: +1 Rebond",
			"Ajoute un ricochet supplémentaire",
			func(): ricochet.add_bounce_count(1)
		))
	
	# Mélanger et sélectionner
	available.shuffle()
	var selection: Array[Amelioration] = []
	for i in range(min(nombre_de_choix, available.size())):
		selection.append(available[i])
	
	return selection
