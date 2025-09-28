extends Node

func reorder_for_top_player():
	var container = get_parent()
	var total_damage_bar = container.get_node("TotalDamageBar")
	container.move_child(total_damage_bar, 0)