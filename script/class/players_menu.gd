class_name PlayerData
extends Resource

@export var name: String = ""
@export_multiline var bio: String = ""
@export_enum("Flingue", "Firewall", "Ver") var base_weapon: String = "Flingue"
@export var hp: int = 100
@export var xp: float = 1.0
@export var dmg: float = 1.0
@export var harvest: float = 1.0
@export_enum("Insignificant", "Surveillance", "Classified") var threat: int = 0
