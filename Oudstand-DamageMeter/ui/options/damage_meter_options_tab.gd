extends ScrollContainer
# Controller for the Damage Meter options tab in the game's settings menu

const MOD_NAME := "DamageMeter"
const CONFIG_PATHS := [
	"/root/ModLoader/Oudstand-DamageMeter/DamageMeterConfig",
	"/root/DamageMeterConfig"
]

var config_manager = null

onready var opacity_slider = $"%OpacitySlider"
onready var number_of_sources_slider = $"%NumberOfSourcesSlider"
onready var show_item_count_button = $"%ShowItemCountButton"
onready var show_dps_button = $"%ShowDPSButton"
onready var show_percentage_button = $"%ShowPercentageButton"


func _ready() -> void:
	call_deferred("_initialize_ui")


func _initialize_ui() -> void:
	config_manager = _find_config_manager()

	if is_instance_valid(config_manager):
		_load_config_values()
		_connect_signals()
	else:
		ModLoaderLog.error("DamageMeterConfig not found!", MOD_NAME)


func _find_config_manager() -> Node:
	for path in CONFIG_PATHS:
		var node = get_node_or_null(path)
		if is_instance_valid(node):
			return node
	return null

func _load_config_values() -> void:
	opacity_slider.set_value(config_manager.BAR_OPACITY)
	number_of_sources_slider.set_value(float(config_manager.TOP_K))
	_update_number_of_sources_display(config_manager.TOP_K)

	show_item_count_button.pressed = config_manager.SHOW_ITEM_COUNT
	show_dps_button.pressed = config_manager.SHOW_DPS
	show_percentage_button.pressed = config_manager.SHOW_PERCENTAGE


func _update_number_of_sources_display(value: int) -> void:
	var value_label = number_of_sources_slider.get_node_or_null("Value")
	if value_label:
		value_label.text = str(value)


func _connect_signals() -> void:
	opacity_slider.connect("value_changed", self, "_on_opacity_changed")
	number_of_sources_slider.connect("value_changed", self, "_on_number_of_sources_changed")
	show_item_count_button.connect("toggled", self, "_on_show_item_count_toggled")
	show_dps_button.connect("toggled", self, "_on_show_dps_toggled")
	show_percentage_button.connect("toggled", self, "_on_show_percentage_toggled")


func _update_config(property: String, value) -> void:
	if not is_instance_valid(config_manager):
		return

	config_manager.set(property, value)
	config_manager._save_config()
	config_manager.emit_signal("config_changed")


func _on_opacity_changed(value: float) -> void:
	_update_config("BAR_OPACITY", clamp(value, 0.3, 1.0))


func _on_number_of_sources_changed(value: float) -> void:
	var clamped_value = int(clamp(value, 1.0, 25.0))
	_update_number_of_sources_display(clamped_value)
	_update_config("TOP_K", clamped_value)


func _on_show_item_count_toggled(button_pressed: bool) -> void:
	_update_config("SHOW_ITEM_COUNT", button_pressed)


func _on_show_dps_toggled(button_pressed: bool) -> void:
	_update_config("SHOW_DPS", button_pressed)


func _on_show_percentage_toggled(button_pressed: bool) -> void:
	_update_config("SHOW_PERCENTAGE", button_pressed)
