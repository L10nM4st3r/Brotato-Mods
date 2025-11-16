extends Node

const MOD_ID := "Oudstand-QuickEquip"
const MOD_DIR_NAME := "Oudstand-QuickEquip"

var options_registered := false
var registration_retry_count := 0
const MAX_REGISTRATION_RETRIES := 5

# Flag to prevent duplicate items in the same run (used by extension)
var _items_added_this_run := false

# Track tracked equipment and configs to compute diffs
var given_weapons := {}  # key -> Array of WeaponData references
var given_items := {}    # key -> Array of ItemData references
var applied_character_abilities := {}  # key -> Array of CharacterData references
var last_weapon_config := []
var last_item_config := []
var last_ability_config := []


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_load_translations(mod_dir_path)
	_install_extensions(mod_dir_path)


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


func _process(_delta):
	# Reset tracking when returning to menu
	if is_instance_valid(RunData) and RunData.get_player_count() == 0:
		if not last_weapon_config.empty() or not last_item_config.empty() or not last_ability_config.empty():
			_clear_all_tracking()
			ModLoaderLog.info("Back in menu. QuickEquip tracking reset.", MOD_ID)


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
	given_weapons.clear()
	given_items.clear()
	applied_character_abilities.clear()
	last_weapon_config.clear()
	last_item_config.clear()
	last_ability_config.clear()


func _clear_all_given_items() -> void:
	var player_index = 0

	_remove_all_tracked_weapons(player_index)
	_remove_all_tracked_items(player_index)
	_clear_character_abilities()
	last_weapon_config.clear()
	last_item_config.clear()
	last_ability_config.clear()

	ModLoaderLog.info("Cleared all QuickEquip items", MOD_ID)


func _clear_character_abilities() -> void:
	if applied_character_abilities.empty():
		return

	var player_index = 0
	var can_remove = is_instance_valid(RunData) and RunData.get_player_count() > player_index

	if not can_remove:
		applied_character_abilities.clear()
		return

	var keys := applied_character_abilities.keys()
	for key in keys:
		_remove_character_abilities(key, applied_character_abilities[key].size(), player_index)

	applied_character_abilities.clear()


func _sync_character_abilities(desired_config: Array, player_index: int) -> void:
	if not is_instance_valid(ItemService):
		ModLoaderLog.error("ItemService not available, cannot apply character abilities.", MOD_ID)
		return

	var desired_map = _config_array_to_map(desired_config, false)
	var current_map = _config_array_to_map(last_ability_config, false)

	for key in current_map.keys():
		var current_count = current_map[key].count
		var desired_count = 0
		if desired_map.has(key):
			desired_count = desired_map[key].count
		var to_remove = current_count - desired_count
		if to_remove > 0:
			_remove_character_abilities(key, to_remove, player_index)

	for key in desired_map.keys():
		var desired_count = desired_map[key].count
		var current_count = 0
		if current_map.has(key):
			current_count = current_map[key].count
		var to_add = desired_count - current_count
		if to_add > 0:
			_add_character_abilities(key, to_add, player_index)

	last_ability_config = _deep_copy_config(desired_config)

func _sync_weapons_config(desired_config: Array, dlc_data, player_index: int) -> void:
	var desired_map = _config_array_to_map(desired_config)
	var current_map = _config_array_to_map(last_weapon_config)

	for key in current_map.keys():
		var current_count = current_map[key].count
		var desired_count = 0
		if desired_map.has(key):
			desired_count = desired_map[key].count
		var to_remove = current_count - desired_count
		if to_remove > 0:
			_remove_tracked_weapons(key, to_remove, player_index)

	for key in desired_map.keys():
		var desired_count = desired_map[key].count
		var current_count = 0
		if current_map.has(key):
			current_count = current_map[key].count
		var to_add = desired_count - current_count
		if to_add > 0:
			var entry = desired_map[key]
			_add_weapon_instances(entry.id, entry.cursed, to_add, dlc_data, player_index)

	last_weapon_config = _deep_copy_config(desired_config)


func _sync_items_config(desired_config: Array, dlc_data, player_index: int) -> void:
	var desired_map = _config_array_to_map(desired_config)
	var current_map = _config_array_to_map(last_item_config)

	for key in current_map.keys():
		var current_count = current_map[key].count
		var desired_count = 0
		if desired_map.has(key):
			desired_count = desired_map[key].count
		var to_remove = current_count - desired_count
		if to_remove > 0:
			_remove_tracked_items(key, to_remove, player_index)

	for key in desired_map.keys():
		var desired_count = desired_map[key].count
		var current_count = 0
		if current_map.has(key):
			current_count = current_map[key].count
		var to_add = desired_count - current_count
		if to_add > 0:
			var entry = desired_map[key]
			_add_item_instances(entry.id, entry.cursed, to_add, dlc_data, player_index)

	last_item_config = _deep_copy_config(desired_config)


func _add_weapon_instances(weapon_id: String, is_cursed: bool, count: int, dlc_data, player_index: int) -> void:
	if count <= 0:
		return
	var base_weapon = _get_weapon_template(weapon_id)
	if base_weapon == null:
		ModLoaderLog.error("Weapon not found in ItemService.weapons: %s" % weapon_id, MOD_ID)
		return

	for _i in range(count):
		var weapon = base_weapon.duplicate()

		if is_cursed and dlc_data:
			weapon = dlc_data.curse_item(weapon, player_index, true)
		else:
			weapon.is_cursed = is_cursed

		var returned_weapon = RunData.add_weapon(weapon, player_index)
		_equip_weapon_on_player(returned_weapon, player_index)
		_track_weapon_instance(weapon_id, is_cursed, returned_weapon)


func _add_item_instances(item_id: String, is_cursed: bool, count: int, dlc_data, player_index: int) -> void:
	if count <= 0:
		return

	var item = ItemService.get_element(ItemService.items, item_id)
	if not is_instance_valid(item):
		ModLoaderLog.error("Failed to create item: %s" % item_id, MOD_ID)
		return

	for _i in range(count):
		var item_copy = item.duplicate()

		if is_cursed and dlc_data:
			item_copy = dlc_data.curse_item(item_copy, player_index, true)
		else:
			item_copy.is_cursed = is_cursed

		RunData.add_item(item_copy, player_index)
		_track_item_instance(item_id, is_cursed, item_copy)


func _add_character_abilities(character_id: String, count: int, player_index: int) -> void:
	if count <= 0:
		return

	var character_data = ItemService.get_element(ItemService.characters, character_id)
	if not is_instance_valid(character_data):
		ModLoaderLog.error("Character ability not found: %s" % character_id, MOD_ID)
		return

	for _i in range(count):
		var ability_copy = character_data.duplicate()
		RunData.add_item(ability_copy, player_index)
		_track_character_ability(character_id, ability_copy)


func _remove_tracked_weapons(key: String, count: int, player_index: int) -> void:
	if count <= 0 or not given_weapons.has(key):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		given_weapons.erase(key)
		return

	var weapon_list: Array = given_weapons[key]
	for _i in range(min(count, weapon_list.size())):
		var weapon_data = weapon_list.pop_back()
		_remove_weapon_resource(weapon_data, player_index)

	if weapon_list.empty():
		given_weapons.erase(key)
	else:
		given_weapons[key] = weapon_list


func _remove_tracked_items(key: String, count: int, player_index: int) -> void:
	if count <= 0 or not given_items.has(key):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		given_items.erase(key)
		return

	var item_list: Array = given_items[key]
	for _i in range(min(count, item_list.size())):
		var item_data = item_list.pop_back()
		if is_instance_valid(item_data):
			RunData.remove_item(item_data, player_index)

	if item_list.empty():
		given_items.erase(key)
	else:
		given_items[key] = item_list


func _remove_character_abilities(key: String, count: int, player_index: int) -> void:
	if count <= 0 or not applied_character_abilities.has(key):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		applied_character_abilities.erase(key)
		return

	var ability_list: Array = applied_character_abilities[key]
	for _i in range(min(count, ability_list.size())):
		var ability_resource = ability_list.pop_back()
		if is_instance_valid(ability_resource):
			RunData.remove_item(ability_resource, player_index, true)

	if ability_list.empty():
		applied_character_abilities.erase(key)
	else:
		applied_character_abilities[key] = ability_list


func _remove_all_tracked_weapons(player_index: int) -> void:
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		given_weapons.clear()
		return
	for key in given_weapons.keys():
		_remove_tracked_weapons(key, given_weapons[key].size(), player_index)
	given_weapons.clear()


func _remove_all_tracked_items(player_index: int) -> void:
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		given_items.clear()
		return
	for key in given_items.keys():
		_remove_tracked_items(key, given_items[key].size(), player_index)
	given_items.clear()


func _remove_weapon_resource(weapon_data: WeaponData, player_index: int) -> void:
	if not is_instance_valid(weapon_data):
		return

	var current_weapons = RunData.get_player_weapons(player_index)
	for i in range(current_weapons.size()):
		if current_weapons[i] == weapon_data:
			_remove_weapon_node_at_pos(player_index, i)
			RunData.remove_weapon_by_index(i, player_index)
			return


func _remove_weapon_node_at_pos(player_index: int, weapon_pos: int) -> void:
	var main = get_tree().get_current_scene()
	if not is_instance_valid(main) or not ("_players" in main):
		return
	var player = main._players[player_index]
	if not is_instance_valid(player) or not ("current_weapons" in player):
		return

	var nodes_to_remove = []
	for weapon_node in player.current_weapons:
		if is_instance_valid(weapon_node) and weapon_node.weapon_pos == weapon_pos:
			nodes_to_remove.append(weapon_node)

	for node in nodes_to_remove:
		player.current_weapons.erase(node)
		node.queue_free()

	for i in range(player.current_weapons.size()):
		player.current_weapons[i].weapon_pos = i


func _track_weapon_instance(weapon_id: String, is_cursed: bool, weapon_data: WeaponData) -> void:
	var key = _make_item_key(weapon_id, is_cursed)
	if not given_weapons.has(key):
		given_weapons[key] = []
	given_weapons[key].append(weapon_data)


func _track_item_instance(item_id: String, is_cursed: bool, item_data: ItemData) -> void:
	var key = _make_item_key(item_id, is_cursed)
	if not given_items.has(key):
		given_items[key] = []
	given_items[key].append(item_data)


func _track_character_ability(character_id: String, ability_resource: CharacterData) -> void:
	if not applied_character_abilities.has(character_id):
		applied_character_abilities[character_id] = []
	applied_character_abilities[character_id].append(ability_resource)


# Called by extension after adding initial items
func _update_tracking_configs(weapons_config: Array, items_config: Array, abilities_config: Array) -> void:
	last_weapon_config = _deep_copy_config(weapons_config)
	last_item_config = _deep_copy_config(items_config)
	last_ability_config = _deep_copy_config(abilities_config)
	ModLoaderLog.info("Tracking configs initialized from extension", MOD_ID)


func _equip_weapon_on_player(weapon_data: WeaponData, player_index: int) -> void:
	var main = get_tree().get_current_scene()
	if is_instance_valid(main) and "_players" in main:
		var player = main._players[player_index]
		if is_instance_valid(player) and player.has_method("add_weapon"):
			var weapon_pos = player.current_weapons.size()
			player.add_weapon(weapon_data, weapon_pos)


func _get_weapon_template(weapon_id: String):
	if not is_instance_valid(ItemService):
		return null
	var all_weapons_list = ItemService.get("weapons")
	if all_weapons_list == null:
		return null

	for weapon in all_weapons_list:
		var current_weapon_id = weapon.my_id if "my_id" in weapon else ""
		if not current_weapon_id.empty() and current_weapon_id == weapon_id:
			return weapon

	return null


func _make_item_key(id: String, is_cursed: bool) -> String:
	return "%s|%s" % [id, String(is_cursed)]


func _config_array_to_map(config: Array, include_cursed: bool = true) -> Dictionary:
	var result = {}
	for entry in config:
		if not entry is Dictionary:
			continue
		var id = entry.get("id", "")
		if id.empty():
			continue
		var count = int(entry.get("count", 1))
		if count <= 0:
			continue
		var cursed = include_cursed and bool(entry.get("cursed", false))
		var key = id
		if include_cursed:
			key = _make_item_key(id, cursed)
		if result.has(key):
			result[key].count += count
		else:
			result[key] = {"id": id, "cursed": cursed, "count": count}
	return result


func _deep_copy_config(config: Array) -> Array:
	var copy = []
	for entry in config:
		if entry is Dictionary:
			copy.append(entry.duplicate(true))
	return copy


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

	# Get the DLC curse function if available
	var dlc_data = null
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		dlc_data = ProgressData.get_dlc_data("abyssal_terrors")

	# --- Config sync logic ---
	_sync_weapons_config(weapons_to_give, dlc_data, player_index)
	_sync_items_config(items_to_give, dlc_data, player_index)
	_sync_character_abilities(abilities_to_apply, player_index)

	ModLoaderLog.info("Items synced successfully during run", MOD_ID)

	# UI Refresh: Force player entity and stats update
	yield(get_tree(), "idle_frame")

	# Get the main scene to access players
	var main = get_tree().get_current_scene()
	if is_instance_valid(main) and "_players" in main:
		for i in range(main._players.size()):
			var player = main._players[i]
			if is_instance_valid(player) and player.has_method("update_player_stats"):
				player.update_player_stats(false)

	# Reset linked stats to recalculate all stat bonuses
	for i in RunData.get_player_count():
		LinkedStats.reset_player(i)
