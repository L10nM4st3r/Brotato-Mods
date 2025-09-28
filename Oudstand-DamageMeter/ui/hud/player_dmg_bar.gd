extends VBoxContainer

export(PackedScene) var source_item_scene = null

onready var total_damage_bar = $TotalDamageBar
onready var progress_bar: ProgressBar = $TotalDamageBar/ProgressBar
onready var icon_rect: TextureRect = $TotalDamageBar/Content/HBoxContainer/CharacterIcon
onready var label: Label = $TotalDamageBar/Content/HBoxContainer/DamageLabel
onready var source_list_container: VBoxContainer = $SourceListBackground/MarginContainer/SourceList
onready var hbox_container: HBoxContainer = $TotalDamageBar/Content/HBoxContainer

onready var style_normal = progress_bar.get("custom_styles/fg")
onready var style_top_player = style_normal.duplicate()

func _ready():
	style_top_player.bg_color = Color(0.9, 0.75, 0.3)

func update_total_damage(damage: int, max_damage: int, is_top_player: bool, is_single_player: bool, player_icon: Texture):
	label.text = Text.get_formatted_number(damage)
	if player_icon:
		icon_rect.texture = player_icon
	
	# Die Logik zum Ändern der Füllrichtung wird entfernt, da dies jetzt über die Rotation geschieht.
	if hbox_container.alignment == BoxContainer.ALIGN_END:
		hbox_container.move_child(icon_rect, 1)
		label.align = Label.ALIGN_RIGHT
	else:
		hbox_container.move_child(icon_rect, 0)
		label.align = Label.ALIGN_LEFT

	if is_single_player:
		progress_bar.value = 100
		progress_bar.add_stylebox_override("fg", style_normal)
	else:
		var progress = 0
		if max_damage > 0:
			progress = (float(damage) / max_damage) * 100
		progress_bar.value = progress
		if is_top_player:
			progress_bar.add_stylebox_override("fg", style_top_player)
		else:
			progress_bar.add_stylebox_override("fg", style_normal)

func update_source_list(sources_with_damage: Array):
	for child in source_list_container.get_children():
		child.queue_free()
	
	var count = 0
	for source_info in sources_with_damage:
		if count >= 6: break
		if is_instance_valid(source_info.source):
			var item_instance = source_item_scene.instance()
			source_list_container.add_child(item_instance)
			item_instance.set_data(source_info)
			item_instance.set_mod_alignment(hbox_container.alignment == BoxContainer.ALIGN_END)
			count += 1
