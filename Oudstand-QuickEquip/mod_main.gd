extends Node

const MOD_ID := "Oudstand-QuickEquip"
const MOD_DIR_NAME := "Oudstand-QuickEquip"

# ModOptions registration state
var options_registered := false
var registration_retry_count := 0
const MAX_REGISTRATION_RETRIES := 5

# Flag to prevent duplicate items in the same run (used by extension)
var _items_added_this_run := false

# Core modules (no type hints - loaded dynamically in _init)
var _tracker
var _sync_manager


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_load_core_modules(mod_dir_path)
	_load_translations(mod_dir_path)
	_install_extensions(mod_dir_path)


func _load_core_modules(mod_dir_path: String) -> void:
	var core_dir := mod_dir_path.plus_file("core")

	# Load utility class
	var utils_script = load(core_dir.plus_file("utils.gd"))

	# Load and instantiate tracker
	var tracker_script = load(core_dir.plus_file("item_tracker.gd"))
	_tracker = tracker_script.new()

	# Load and instantiate sync manager (pass self as owner node)
	var sync_manager_script = load(core_dir.plus_file("item_sync_manager.gd"))
	_sync_manager = sync_manager_script.new(_tracker, self)


func _load_translations(mod_dir_path: String) -> void:
	var translations_dir := mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir.plus_file("QuickEquip.en.translation"))
	ModLoaderMod.add_translation(translations_dir.plus_file("QuickEquip.de.translation"))


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("run_data_extension.gd"))
	# Fix vanilla division by zero bug when removing projectile items (e.g., Alien Eyes)
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("projectile_effect_extension.gd"))


func _ready():
	ModLoaderLog.info("QuickEquip Mod ready!", MOD_ID)
	# Try to register options with a delay to ensure ModOptions is ready
	call_deferred("_register_mod_options")


func _process(_delta):
	# Reset tracking when returning to menu
	if is_instance_valid(RunData) and RunData.get_player_count() == 0:
		if _tracker.has_tracked_items():
			_clear_all_tracking()
			ModLoaderLog.info("Back in menu. QuickEquip tracking reset.", MOD_ID)


func _get_mod_options() -> Node:
	# Get sibling mod node (both are children of ModLoader)
	var parent = get_parent()
	if not parent:
		return null
	var mod_options_mod = parent.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	return mod_options_mod.get_node_or_null("ModOptions")


func _register_mod_options() -> void:
	if options_registered:
		return

	var mod_options = _get_mod_options()
	if not mod_options:
		# Retry registration if ModOptions isn't ready yet
		registration_retry_count += 1
		if registration_retry_count < MAX_REGISTRATION_RETRIES:
			yield(get_tree().create_timer(0.2), "timeout")
			_register_mod_options()
		else:
			ModLoaderLog.error("Failed to register options after %d retries" % MAX_REGISTRATION_RETRIES, MOD_ID)
		return

	mod_options.register_mod_options("QuickEquip", {
		"tab_title": "Quick Equip",
		"options": [
			{
				"type": "item_selector",
				"id": "weapons_list",
				"label": "QUICKEQUIP_WEAPONS_LABEL",
				"default": [],
				"item_type": "weapon",
				"help_text": "QUICKEQUIP_WEAPONS_HELP"
			},
			{
				"type": "item_selector",
				"id": "items_list",
				"label": "QUICKEQUIP_ITEMS_LABEL",
				"default": [],
				"item_type": "item",
				"help_text": "QUICKEQUIP_ITEMS_HELP"
			},
			{
				"type": "item_selector",
				"id": "abilities_list",
				"label": "QUICKEQUIP_ABILITIES_LABEL",
				"default": [],
				"item_type": "character",
				"help_text": "QUICKEQUIP_ABILITIES_HELP",
				"show_count": false,
				"show_cursed": false
			}
		],
		"info_text": "QUICKEQUIP_INFO_TEXT"
	})

	options_registered = true
	ModLoaderLog.info("QuickEquip options registered successfully", MOD_ID)

	# Connect to config changes to reapply items when options change during a run
	if not mod_options.is_connected("config_changed", self, "_on_config_changed"):
		mod_options.connect("config_changed", self, "_on_config_changed")


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	# Only react to QuickEquip config changes
	if mod_id != "QuickEquip":
		return

	# Only reapply items if a run is active
	if not is_instance_valid(RunData) or RunData.get_player_count() == 0:
		return

	# Only reapply if tracked options changed
	if option_id == "weapons_list" or option_id == "items_list" or option_id == "abilities_list":
		ModLoaderLog.info("Items configuration changed during run, syncing items...", MOD_ID)
		_sync_items_during_run()


func _clear_all_tracking() -> void:
	# Clear all tracking data when returning to menu
	# Note: We don't remove items here since the run is ending anyway
	_items_added_this_run = false
	_tracker.clear_all()


func _sync_items_during_run():
	# This function handles dynamic config changes during an active run
	# Initial items are added via the RunData extension at run start
	var player_index = 0

	# Read configuration from ModOptions
	var mod_options = _get_mod_options()
	if not mod_options:
		ModLoaderLog.error("ModOptions not available", MOD_ID)
		return

	# Get lists from ModOptions
	var weapons_to_give = mod_options.get_value("QuickEquip", "weapons_list")
	var items_to_give = mod_options.get_value("QuickEquip", "items_list")
	var abilities_to_apply = mod_options.get_value("QuickEquip", "abilities_list")

	if not weapons_to_give is Array:
		weapons_to_give = []
	if not items_to_give is Array:
		items_to_give = []
	if not abilities_to_apply is Array:
		abilities_to_apply = []

	# Sync via manager
	_sync_manager.sync_items(weapons_to_give, items_to_give, abilities_to_apply, player_index)


# === Extension Interface ===
# These methods are called by run_data_extension.gd

func _track_weapon_instance(weapon_id: String, is_cursed: bool, weapon_data: WeaponData) -> void:
	_tracker.track_weapon_instance(weapon_id, is_cursed, weapon_data)


func _track_item_instance(item_id: String, is_cursed: bool, item_data: ItemData) -> void:
	_tracker.track_item_instance(item_id, is_cursed, item_data)


func _track_character_ability(character_id: String, ability_resource: CharacterData) -> void:
	_tracker.track_character_ability(character_id, ability_resource)


func _update_tracking_configs(weapons_config: Array, items_config: Array, abilities_config: Array) -> void:
	_tracker.update_tracking_configs(weapons_config, items_config, abilities_config)
