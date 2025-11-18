extends Node

var probe : int = 0
var dmg_aura : float = 0.0
var dmg_base : float = 0.0
var dmg_bounce : float = 0.0

func add_probe_count() -> void :
	probe = probe + 1
	
func add_dmg_aura_count(dmg : float) -> void :
	dmg_aura = dmg_aura + dmg
	
func add_dmg_base_count(dmg : float) -> void :
	dmg_base = dmg_base + dmg
	
func add_dmg_bounce_count(dmg : float) -> void :
	dmg_bounce = dmg_bounce + dmg
	
func reset() -> void :
	probe = 0
	dmg_aura = 0.0
	dmg_base = 0.0
	dmg_bounce = 0.0
