# pylon_manager.gd
extends Node

var registered_pylons: Array = []
var charged_pylons_count: int = 0

signal pylon_charged(pylon: Node3D)
signal all_pylons_charged()

func register_pylon(pylon: Node3D) -> void:
	if not registered_pylons.has(pylon):
		registered_pylons.append(pylon)
		print("Pylône enregistré: ", pylon.name, " (Total: ", registered_pylons.size(), ")")

func unregister_pylon(pylon: Node3D) -> void:
	var idx = registered_pylons.find(pylon)
	if idx != -1:
		registered_pylons.remove_at(idx)

func notify_pylon_charged(pylon: Node3D) -> void:
	charged_pylons_count += 1
	pylon_charged.emit(pylon)
	
	print("Pylône chargé: ", pylon.name, " (", charged_pylons_count, "/", registered_pylons.size(), ")")
	
	if charged_pylons_count >= registered_pylons.size():
		all_pylons_charged.emit()
		print("🎉 Tous les pylônes sont chargés!")

func get_pylon_progress() -> Dictionary:
	return {
		"total": registered_pylons.size(),
		"charged": charged_pylons_count,
		"progress": float(charged_pylons_count) / max(1, registered_pylons.size())
	}

func get_total_pylons() -> int:
	return registered_pylons.size()

func get_charged_count() -> int:
	return charged_pylons_count

func reset() -> void:
	charged_pylons_count = 0
	registered_pylons.clear()
