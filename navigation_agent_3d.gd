extends NavigationAgent3D

func _ready() -> void:
	var agent: RID = get_rid()

	# Disable avoidance
	NavigationServer3D.agent_set_avoidance_enabled(agent, false)
	# Delete avoidance callback
	NavigationServer3D.agent_set_avoidance_callback(agent, Callable())
