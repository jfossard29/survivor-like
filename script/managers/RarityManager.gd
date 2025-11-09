extends Node

# === CONFIGURATION DES RARETÉS ===
const RARITY_WEIGHTS = {
	"common": 100.0,      # Poids de base
	"uncommon": 40.0,     # 40% aussi commun que common
	"rare": 15.0,         # 15% aussi commun que common
	"legendary": 3.0,     # 3% aussi commun que common
	"unique": 0.5         # 0.5% aussi commun que common
}

# Multiplicateurs de stats par rareté
const RARITY_STAT_MULTIPLIERS = {
	"common": 1.0,
	"uncommon": 1.5,
	"rare": 2.0,
	"legendary": 3.0,
	"unique": 5.0
}

# === SYSTÈME DE LUCK ===
var base_luck: float = 0.0  # Luck de base du joueur (0-100)

# Chaque point de luck augmente les poids des raretés supérieures
const LUCK_SCALING = {
	"common": 0.0,        # La luck ne change pas les commons
	"uncommon": 0.5,      # +0.5% de poids par point de luck
	"rare": 0.3,          # +0.3% de poids par point de luck
	"legendary": 0.15,    # +0.15% de poids par point de luck
	"unique": 0.05        # +0.05% de poids par point de luck
}

func get_adjusted_weights() -> Dictionary:
	"""Calcule les poids ajustés en fonction de la luck"""
	var adjusted = {}
	
	for rarity in RARITY_WEIGHTS.keys():
		var base_weight = RARITY_WEIGHTS[rarity]
		var luck_bonus = LUCK_SCALING[rarity] * base_luck
		
		# Le poids final = poids de base * (1 + bonus de luck en %)
		adjusted[rarity] = base_weight * (1.0 + luck_bonus / 100.0)
	
	return adjusted

func roll_rarity() -> String:
	"""Tire une rareté aléatoire selon les poids ajustés"""
	var weights = get_adjusted_weights()
	
	# Calculer le poids total
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	# Tirer un nombre aléatoire
	var roll = randf() * total_weight
	
	# Trouver la rareté correspondante
	var cumulative = 0.0
	for rarity in ["common", "uncommon", "rare", "legendary", "unique"]:
		cumulative += weights[rarity]
		if roll <= cumulative:
			return rarity
	
	return "common"  # Fallback

func add_luck(amount: float) -> void:
	"""Ajoute de la luck au joueur"""
	base_luck += amount
	base_luck = clamp(base_luck, 0.0, 100.0)  # Limiter entre 0 et 100
	print("🍀 Luck: ", base_luck, "%")

func get_rarity_chances() -> Dictionary:
	"""Retourne les pourcentages de chance réels pour chaque rareté"""
	var weights = get_adjusted_weights()
	var total = 0.0
	for w in weights.values():
		total += w
	
	var chances = {}
	for rarity in weights.keys():
		chances[rarity] = (weights[rarity] / total) * 100.0
	
	return chances

func print_chances() -> void:
	"""Affiche les chances actuelles (debug)"""
	var chances = get_rarity_chances()
	print("\n=== CHANCES DE RARETÉ (Luck: ", base_luck, "%) ===")
	for rarity in ["common", "uncommon", "rare", "legendary", "unique"]:
		print(rarity.capitalize(), ": ", "%.2f" % chances[rarity], "%")

func get_stat_multiplier(rarity: String) -> float:
	"""Retourne le multiplicateur de stats pour une rareté"""
	return RARITY_STAT_MULTIPLIERS.get(rarity, 1.0)
