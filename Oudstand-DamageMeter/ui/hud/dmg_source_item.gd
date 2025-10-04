extends Control

const SPACING_LEFT: int = 8
const SPACING_RIGHT: int = 12

onready var content: HBoxContainer = $Content
onready var icon_bg: Panel = $Content/IconBackground
onready var icon: TextureRect = $Content/IconBackground/Icon
onready var label: Label = $Content/Label

var _is_right: bool = false

func set_data(source_info: Dictionary) -> void:
	var source = source_info.get("source")
	if not is_instance_valid(source) or not "icon" in source:
		return
	
	var damage = source_info.get("damage", 0)
	
	# Zeige nur den Gesamtschaden (ohne Anzahl)
	label.text = Text.get_formatted_number(damage)
	
	if is_instance_valid(icon):
		icon.texture = source.icon
	
	# Hintergrundfarbe basierend auf Seltenheit
	if "tier" in source:
		var is_cursed = source.is_cursed if "is_cursed" in source else false
		_update_background_color(source.tier, is_cursed)

func _update_background_color(tier: int, is_cursed: bool) -> void:
	if not is_instance_valid(icon_bg):
		return
	
	var stylebox = icon_bg.get_stylebox("panel")
	if stylebox == null:
		stylebox = StyleBoxFlat.new()
	else:
		stylebox = stylebox.duplicate()
	
	icon_bg.add_stylebox_override("panel", stylebox)
	
	# ItemService nutzt die gleichen Farben wie im Inventar
	ItemService.change_inventory_element_stylebox_from_tier(stylebox, tier, 0.3)
	
	# Cursed Overlay (falls verfügbar)
	if is_cursed and icon_bg.has_method("_update_stylebox"):
		icon_bg._update_stylebox(true)

func set_mod_alignment(is_right: bool) -> void:
	if _is_right == is_right:
		return
	
	_is_right = is_right
	
	content.anchor_left = 1.0 if is_right else 0.0
	content.anchor_right = content.anchor_left
	
	if is_right:
		label.rect_min_size.x = 80 
		label.align = Label.ALIGN_RIGHT 
		content.move_child(label, 0)
		content.move_child(icon_bg, 1)
	else:
		label.rect_min_size.x = 0
		label.align = Label.ALIGN_LEFT
		content.move_child(icon_bg, 0)
		content.move_child(label, 1)
	
	content.add_constant_override("separation", SPACING_RIGHT if is_right else SPACING_LEFT)
	
	_update_margins()
	call_deferred("_update_margins")

func _update_margins() -> void:
	if not is_instance_valid(content):
		return
	
	var size = content.get_combined_minimum_size()
	
	if _is_right:
		content.margin_left = -size.x
		content.margin_right = 0
	else:
		content.margin_left = 0
		content.margin_right = size.x
