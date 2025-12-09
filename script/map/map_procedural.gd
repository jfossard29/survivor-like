@tool
extends Node3D

@export var map_size: int = 30:
	set(value):
		map_size = value
		if Engine.is_editor_hint():
			_update_grid()

@export var max_height: int = 5:
	set(value):
		max_height = value
		if Engine.is_editor_hint():
			_update_grid()

@export var bloc_size: float = 10.0

@export var seed: int = 0:
	set(value):
		seed = value
		if Engine.is_editor_hint():
			_update_grid()

@export_group("Platform Generation")
@export_range(0.0, 1.0, 0.01) var platform_coverage: float = 0.15
@export_range(2, 10) var min_platform_size: int = 3
@export_range(5, 20) var max_platform_size: int = 8
@export_range(0, 5) var min_gap: int = 1
@export_range(0.0, 1.0, 0.1) var stacking_chance: float = 0.5
@export var max_attempts: int = 3000

@export_group("Debug & Visualization")
@export var show_grid_in_console: bool = false:
	set(value):
		show_grid_in_console = value
		if value and Engine.is_editor_hint():
			print_grid_to_console()

@export var show_detailed_info: bool = false:
	set(value):
		show_detailed_info = value
		if value and Engine.is_editor_hint():
			print_detailed_info()

@export var generate_platforms: bool = false:
	set(value):
		generate_platforms = false
		if value and Engine.is_editor_hint():
			_generate_platforms()

var grid: Array = []
var platforms: Array = []
var stats: Dictionary = {
	"total_cells": 0,
	"filled_cells": 0,
	"platforms_count": 0,
	"max_height_used": 0
}

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_grid()

func _update_grid() -> void:
	print("\n🔄 Mise à jour de la grille...")
	_initialize_grid()
	_calculate_stats()
	print("✅ Grille initialisée: ", map_size, "x", map_size, "x", max_height)

func _initialize_grid() -> void:
	if grid.size() != map_size:
		grid.clear()
		for x in range(map_size):
			var column_z = []
			for z in range(map_size):
				var column_y = []
				for y in range(max_height):
					column_y.append(0)
				column_z.append(column_y)
			grid.append(column_z)
	else:
		for x in range(map_size):
			for z in range(map_size):
				for y in range(max_height):
					grid[x][z][y] = 0

func _calculate_stats() -> void:
	stats.total_cells = map_size * map_size * max_height
	stats.filled_cells = 0
	stats.max_height_used = 0
	stats.platforms_count = platforms.size()
	
	for x in range(map_size):
		for z in range(map_size):
			for y in range(max_height):
				if grid[x][z][y] != 0:
					stats.filled_cells += 1
					stats.max_height_used = max(stats.max_height_used, y + 1)

func print_grid_to_console() -> void:
	print("\n═══════════════════════════════════════")
	print("🗺️  VISUALISATION DE LA GRILLE")
	print("═══════════════════════════════════════")
	print("Dimensions: ", map_size, "x", map_size, "x", max_height)
	print("Seed: ", seed)
	print("\nLégende:")
	print("  . = vide")
	print("  0-9 = numéro du niveau Y")
	print("═══════════════════════════════════════\n")
	
	for y in range(max_height):
		print("--- NIVEAU Y = ", y, " ---")
		var header = "   "
		for x in range(min(map_size, 50)):
			header += str(x % 10)
		print(header)
		
		for z in range(min(map_size, 50)):
			var line = str(z).pad_zeros(2) + " "
			for x in range(min(map_size, 50)):
				if grid[x][z][y] != 0:
					line += str(y)
				else:
					line += "."
			print(line)
		print("")

func print_detailed_info() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║   INFORMATIONS DÉTAILLÉES            ║")
	print("╚══════════════════════════════════════╝")
	print("Plateformes: ", platforms.size())
	print("Cellules remplies: ", stats.filled_cells)

func _generate_platforms() -> void:
	var ground_platforms : Array = []
	var stacked_platforms : Array = []
	var filled_cells := 0
	var target_cells := int(map_size * map_size * platform_coverage)

	print("\n🏗️ === GÉNÉRATION DES PLATEFORMES ===")
	print("📊 Objectif: %d cellules sur %d (%.1f%%)" %
		[target_cells, map_size * map_size, platform_coverage * 100.0])

	# ───────────────────────────────────────────────
	# PHASE 1 — Plateformes au sol (Y = 0)
	# ───────────────────────────────────────────────
	print("\n🔷 PHASE 1: Plateformes au sol (Y=0)")
	var attempts := 0

	while filled_cells < target_cells and attempts < max_attempts:
		attempts += 1

		var width = randi_range(min_platform_size, max_platform_size)
		var depth = randi_range(min_platform_size, max_platform_size)
		var x = randi_range(0, map_size - width)
		var z = randi_range(0, map_size - depth)

		if not _can_place_platform(x, z, 0, width, depth):
			continue

		var platform = {
			"x": x,
			"z": z,
			"y": 0,
			"width": width,
			"depth": depth
		}

		_fill_grid(platform)
		filled_cells += width * depth
		ground_platforms.append(platform)

		if ground_platforms.size() % 5 == 0 and show_detailed_info:
			print("  ✓ %d plateformes | %d/%d cellules (%.1f%%)" % [
				ground_platforms.size(),
				filled_cells,
				target_cells,
				(float(filled_cells) / target_cells) * 100.0
			])

	print("\n✅ Phase 1 terminée:")
	print("  • Plateformes créées:", ground_platforms.size())
	print("  • Cellules remplies: %d/%d (%.1f%%)" %
		[filled_cells, target_cells, (float(filled_cells) / target_cells) * 100.0])
	print("  • Tentatives:", attempts)


	# ───────────────────────────────────────────────
	# PHASE 2 — Plateformes empilées (Y > 0)
	# ───────────────────────────────────────────────
	print("\n🔶 PHASE 2: Empilement de plateformes")
	print("  Chance d'empilement: %d%%" % int(stacking_chance * 100))

	var success := 0
	var reject_height := 0
	var reject_size := 0
	var reject_space := 0
	var reject_access := 0

	for base in ground_platforms:
		if randf() > stacking_chance:
			continue

		if base.y + 1 >= max_height:
			reject_height += 1
			continue

		var new_y = base.y + 1

		var new_width = randi_range(min_platform_size, base.width)
		var new_depth = randi_range(min_platform_size, base.depth)

		if new_width < min_platform_size or new_depth < min_platform_size:
			reject_size += 1
			continue

		var offset_x = randi_range(0, base.width - new_width)
		var offset_z = randi_range(0, base.depth - new_depth)

		var new_x = base.x + offset_x
		var new_z = base.z + offset_z

		var valid := true

		for cx in range(new_x, new_x + new_width):
			for cz in range(new_z, new_z + new_depth):

				# Vérifie toute la colonne sous la plateforme
				for cy in range(new_y):
					if grid[cx][cz][cy] == 0:
						valid = false
						reject_access += 1
						break

				if not valid:
					break

				# doit être vide à la hauteur cible
				if grid[cx][cz][new_y] != 0:
					valid = false
					reject_space += 1
					break

			if not valid:
				break


		if not valid:
			continue

		var stacked = {
			"x": new_x,
			"z": new_z,
			"y": new_y,
			"width": new_width,
			"depth": new_depth
		}

		if show_detailed_info:
			print("    🔧 Y=%d pos[%d,%d] size[%dx%d]" %
				[new_y, new_x, new_z, new_width, new_depth])

		_fill_grid(stacked)
		stacked_platforms.append(stacked)
		success += 1


	print("\n✅ Phase 2 terminée:")
	print("  • Plateformes empilées:", stacked_platforms.size())
	print("  • Total plateformes:", ground_platforms.size() + stacked_platforms.size())

	print("\n📊 Raisons de rejet:")
	print("  • Succès:", success)
	print("  • Hauteur max:", reject_height)
	print("  • Base trop petite:", reject_size)
	print("  • Pas d'espace:", reject_space)
	print("  • Pas de support:", reject_access)

	print("\n🎉 GÉNÉRATION TERMINÉE")
	print("  • Cellules remplies:", count_filled_cells(), "/", total_cells_2d())


# ────────── UTILITAIRES ──────────

func _can_place_platform(x:int, z:int, y:int, w:int, d:int) -> bool:
	for cx in range(x - min_gap, x + w + min_gap):
		for cz in range(z - min_gap, z + d + min_gap):
			if cx < 0 or cz < 0 or cx >= map_size or cz >= map_size:
				return false
			if grid[cx][cz][y] != 0:
				return false
	return true


func _fill_grid(platform: Dictionary) -> void:
	var y: int = int(platform["y"])
	var stored_value: int = y + 1

	for x in range(platform["x"], platform["x"] + platform["width"]):
		for z in range(platform["z"], platform["z"] + platform["depth"]):
			grid[x][z][y] = stored_value



func count_filled_cells() -> int:
	var total := 0
	for x in range(map_size):
		for z in range(map_size):
			for y in range(max_height):
				if grid[x][z][y] != 0:
					total += 1
	return total


func total_cells_2d() -> int:
	return map_size * map_size
