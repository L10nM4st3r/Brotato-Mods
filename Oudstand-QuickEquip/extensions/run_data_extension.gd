extends "res://singletons/run_data.gd"

# Extension to add QuickEquip items/weapons/abilities BEFORE players spawn
# This ensures all timers and effects are properly initialized

func add_starting_items_and_weapons() -> void:
	# First, add the regular starting items from the game
	.add_starting_items_and_weapons()

	# QuickEquip items are added in on_wave_start() instead
	# This prevents double-adding items on restart


func on_wave_start(timer) -> void:
	# Call the original function
	.on_wave_start(timer)

	# Add QuickEquip items on Wave 1 (this catches first run from Character Selection)
	# Keep trying until items are added or wave > 1
	if current_wave == 1:
		# Reset the flag at the start of Wave 1 to allow items for new runs
		var mod_loader = get_node_or_null("/root/ModLoader")
		if mod_loader:
			var quick_equip_mod = mod_loader.get_node_or_null("Oudstand-QuickEquip")
			if quick_equip_mod:
				quick_equip_mod.set("_items_added_this_run", false)

		_add_quickequip_items()
		# If items weren't added (options not ready), schedule retry
		if mod_loader:
			var quick_equip_mod = mod_loader.get_node_or_null("Oudstand-QuickEquip")
			if quick_equip_mod and not quick_equip_mod.get("_items_added_this_run"):
				call_deferred("_retry_add_items")


func _retry_add_items() -> void:
	# Retry adding items after a short delay
	yield(get_tree().create_timer(0.3), "timeout")
	if current_wave == 1:
		_add_quickequip_items()


func _add_quickequip_items() -> void:
	# Get the ModOptions node to read QuickEquip configuration
	var mod_loader = get_node_or_null("/root/ModLoader")
	if not mod_loader:
		return

	var quick_equip_mod = mod_loader.get_node_or_null("Oudstand-QuickEquip")
	if not quick_equip_mod:
		return

	# Check if items were already added this run (prevent duplicates)
	if quick_equip_mod.get("_items_added_this_run"):
		return
	quick_equip_mod.set("_items_added_this_run", true)

	var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return

	var mod_options = mod_options_mod.get_node_or_null("ModOptions")
	if not mod_options:
		return

	# Check if QuickEquip options are actually registered
	if not quick_equip_mod.get("options_registered"):
		ModLoaderLog.warning("QuickEquip: Options not yet registered, skipping item addition", "Oudstand-QuickEquip")
		quick_equip_mod.set("_items_added_this_run", false)  # Reset flag for retry
		return

	# Get configured items/weapons/abilities
	var weapons_to_give = mod_options.get_value("QuickEquip", "weapons_list")
	var items_to_give = mod_options.get_value("QuickEquip", "items_list")
	var abilities_to_apply = mod_options.get_value("QuickEquip", "abilities_list")

	# Safety checks - if values are null, options aren't registered yet
	if weapons_to_give == null:
		weapons_to_give = []
	if items_to_give == null:
		items_to_give = []
	if abilities_to_apply == null:
		abilities_to_apply = []

	# Additional type safety checks
	if not weapons_to_give is Array:
		weapons_to_give = []
	if not items_to_give is Array:
		items_to_give = []
	if not abilities_to_apply is Array:
		abilities_to_apply = []

	# If all configs are empty, options probably aren't registered yet
	if weapons_to_give.empty() and items_to_give.empty() and abilities_to_apply.empty():
		ModLoaderLog.warning("QuickEquip: No items configured or options not yet registered", "Oudstand-QuickEquip")
		quick_equip_mod.set("_items_added_this_run", false)  # Reset flag for retry
		return

	# Get DLC data for curse functionality
	var dlc_data = null
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		dlc_data = ProgressData.get_dlc_data("abyssal_terrors")

	var player_index = 0

	# Add weapons and track them
	for weapon_config in weapons_to_give:
		if not weapon_config is Dictionary:
			continue
		var weapon_id = weapon_config.get("id", "")
		if weapon_id.empty():
			continue
		var count = int(weapon_config.get("count", 1))
		var is_cursed = bool(weapon_config.get("cursed", false))

		for _i in range(count):
			var weapon = ItemService.get_element(ItemService.weapons, weapon_id)
			if not is_instance_valid(weapon):
				continue

			var weapon_copy = weapon.duplicate()
			if is_cursed and dlc_data:
				weapon_copy = dlc_data.curse_item(weapon_copy, player_index, true)
			else:
				weapon_copy.is_cursed = is_cursed

			var returned_weapon = add_weapon(weapon_copy, player_index)

			# Track the weapon in mod_main
			# Note: Weapons are automatically equipped when players spawn, no need to call _equip_weapon_on_player
			if quick_equip_mod.has_method("_track_weapon_instance"):
				quick_equip_mod._track_weapon_instance(weapon_id, is_cursed, returned_weapon)

	# Add items and track them
	for item_config in items_to_give:
		if not item_config is Dictionary:
			continue
		var item_id = item_config.get("id", "")
		if item_id.empty():
			continue
		var count = int(item_config.get("count", 1))
		var is_cursed = bool(item_config.get("cursed", false))

		for _i in range(count):
			var item = ItemService.get_element(ItemService.items, item_id)
			if not is_instance_valid(item):
				continue

			var item_copy = item.duplicate()
			if is_cursed and dlc_data:
				item_copy = dlc_data.curse_item(item_copy, player_index, true)
			else:
				item_copy.is_cursed = is_cursed

			add_item(item_copy, player_index)

			# Track the item in mod_main
			if quick_equip_mod.has_method("_track_item_instance"):
				quick_equip_mod._track_item_instance(item_id, is_cursed, item_copy)

	# Add character abilities and track them
	for ability_config in abilities_to_apply:
		if not ability_config is Dictionary:
			continue
		var character_id = ability_config.get("id", "")
		if character_id.empty():
			continue
		var count = int(ability_config.get("count", 1))

		for _i in range(count):
			var character_data = ItemService.get_element(ItemService.characters, character_id)
			if not is_instance_valid(character_data):
				continue

			var ability_copy = character_data.duplicate()
			add_item(ability_copy, player_index)

			# Track the ability in mod_main
			if quick_equip_mod.has_method("_track_character_ability"):
				quick_equip_mod._track_character_ability(character_id, ability_copy)

	# Update tracking configs in mod_main
	if quick_equip_mod.has_method("_update_tracking_configs"):
		quick_equip_mod._update_tracking_configs(weapons_to_give, items_to_give, abilities_to_apply)

	ModLoaderLog.info("QuickEquip: Added items/weapons/abilities at run start (Wave 1)", "Oudstand-QuickEquip")
