extends HBoxContainer

onready var icon_rect: TextureRect = $Icon
onready var label: Label = $DamageLabel

func set_data(source_info):
	var source = source_info.source
	var damage = source_info.damage
	if is_instance_valid(source):
		label.text = Text.get_formatted_number(damage)
		icon_rect.texture = source.icon

# NEUER NAME: Passt die interne Ausrichtung an
func set_mod_alignment(is_right: bool):
	if is_right:
		move_child(icon_rect, 1)
		label.align = Label.ALIGN_RIGHT
	else:
		move_child(icon_rect, 0)
		label.align = Label.ALIGN_LEFT
