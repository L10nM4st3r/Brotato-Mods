extends Node
# Injects the Damage Meter options tab into Brotato's options menu

const MOD_NAME := "DamageMeter"
const OPTIONS_MENU_SCRIPT := "res://ui/menus/pages/menu_options.gd"

const damage_meter_tab_scene := preload("res://mods-unpacked/Oudstand-DamageMeter/ui/options/damage_meter_options_tab.tscn")

var injected_menus := []


func _ready() -> void:
	call_deferred("_setup_menu_monitor")


func _setup_menu_monitor() -> void:
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node: Node) -> void:
	if _is_options_menu(node) and not injected_menus.has(node):
		_inject_damage_meter_tab(node)


func _is_options_menu(node: Node) -> bool:
	if not node is MarginContainer:
		return false
	var script = node.get_script()
	return script != null and script.resource_path == OPTIONS_MENU_SCRIPT

func _inject_damage_meter_tab(menu_options: MarginContainer) -> void:
	injected_menus.append(menu_options)
	yield(get_tree().create_timer(0.1), "timeout")

	var button_container = menu_options.get_node_or_null("Buttons/HBoxContainer2")
	var tab_container = menu_options.get_node_or_null("Buttons/HBoxContainer3/TabContainer")
	var tab_script_node = menu_options.get_node_or_null("Buttons")

	if not _validate_containers(button_container, tab_container):
		return

	var button = _create_tab_button()
	button_container.add_child(button)

	var tab_instance = _create_tab_instance()
	tab_container.add_child(tab_instance)

	_register_button_with_tab_system(button, tab_script_node)


func _validate_containers(button_container: Node, tab_container: Node) -> bool:
	if not is_instance_valid(button_container):
		ModLoaderLog.error("Could not find button container", MOD_NAME)
		return false
	if not is_instance_valid(tab_container):
		ModLoaderLog.error("Could not find tab container", MOD_NAME)
		return false
	return true


func _create_tab_button() -> Button:
	var button = Button.new()
	button.name = "DamageMeter_but"
	button.text = "DAMAGEMETER_TAB_TITLE"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true

	var button_script = load("res://ui/menus/global/my_menu_button.gd")
	if button_script:
		button.set_script(button_script)

	return button


func _create_tab_instance() -> Control:
	var instance = damage_meter_tab_scene.instance()
	instance.name = "DamageMeter_Container"
	instance.visible = false
	return instance


func _register_button_with_tab_system(button: Button, tab_script_node: Node) -> void:
	if not tab_script_node:
		return

	var buttons_array = tab_script_node.get("buttons_tab_np")
	var buttons_tab = tab_script_node.get("buttons_tab")

	if buttons_array == null or buttons_tab == null:
		return

	var new_tab_index = buttons_array.size()

	buttons_array.append(button.get_path())
	tab_script_node.set("buttons_tab_np", buttons_array)

	buttons_tab.append(button)
	tab_script_node.set("buttons_tab", buttons_tab)

	if buttons_tab.size() > 1:
		var first_button = buttons_tab[0]
		if first_button and first_button.group:
			button.group = first_button.group

	if tab_script_node.has_method("_change_tab"):
		button.connect("pressed", tab_script_node, "_change_tab", [new_tab_index])
