extends "res://ui/hud/player_ui_elements.gd"

func set_hud_position(position_index: int) -> void:
	# Führe zuerst die originale Funktion des Spiels aus
	.set_hud_position(position_index)
	
	var dmg_container = hud_container.get_node_or_null("PlayerDamageContainerP%s" % str(player_index + 1))
	if not is_instance_valid(dmg_container):
		return

	var is_bottom_player = position_index > 1
	var is_right_player = position_index == 1 or position_index == 3
	
	if is_bottom_player:
		hud_container.move_child(dmg_container, 0)
	
	var align_mode = BoxContainer.ALIGN_END if is_right_player else BoxContainer.ALIGN_BEGIN
	if hud_container is HBoxContainer or hud_container is VBoxContainer:
		hud_container.alignment = align_mode
	
	dmg_container.alignment = align_mode
	
	var total_damage_hbox = dmg_container.get_node("TotalDamageBar/Content/HBoxContainer")
	total_damage_hbox.alignment = align_mode
	
	for item in dmg_container.get_node("SourceListBackground/MarginContainer/SourceList").get_children():
		item.set_mod_alignment(is_right_player)

	# NEUE LOGIK: Drehe den ProgressBar für rechte Spieler
	var progress_bar = dmg_container.get_node("TotalDamageBar/ProgressBar")
	if is_right_player:
		progress_bar.rect_rotation = 180
		progress_bar.rect_position = Vector2(0,0) # Position nach Drehung korrigieren
	else:
		progress_bar.rect_rotation = 0

	if not is_bottom_player:
		dmg_container.get_node("ReorderLogic").reorder_for_top_player()