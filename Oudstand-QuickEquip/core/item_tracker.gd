class_name QuickEquipItemTracker
extends Reference

# Tracks given equipment and configs to compute diffs

const MOD_ID := "Oudstand-QuickEquip"
const Utils = preload("res://mods-unpacked/Oudstand-QuickEquip/core/utils.gd")

# Track given equipment instances
var given_weapons := {}  # key -> Array of WeaponData references
var given_items := {}    # key -> Array of ItemData references
var applied_character_abilities := {}  # key -> Array of CharacterData references

# Track last known configs to compute diffs
var last_weapon_config := []
var last_item_config := []
var last_ability_config := []


func track_weapon_instance(weapon_id: String, is_cursed: bool, weapon_data: WeaponData) -> void:
	var key = Utils.make_item_key(weapon_id, is_cursed)
	if not given_weapons.has(key):
		given_weapons[key] = []
	given_weapons[key].append(weapon_data)


func track_item_instance(item_id: String, is_cursed: bool, item_data: ItemData) -> void:
	var key = Utils.make_item_key(item_id, is_cursed)
	if not given_items.has(key):
		given_items[key] = []
	given_items[key].append(item_data)


func track_character_ability(character_id: String, ability_resource: CharacterData) -> void:
	if not applied_character_abilities.has(character_id):
		applied_character_abilities[character_id] = []
	applied_character_abilities[character_id].append(ability_resource)


func update_tracking_configs(weapons_config: Array, items_config: Array, abilities_config: Array) -> void:
	last_weapon_config = Utils.deep_copy_config(weapons_config)
	last_item_config = Utils.deep_copy_config(items_config)
	last_ability_config = Utils.deep_copy_config(abilities_config)
	ModLoaderLog.info("Tracking configs initialized", MOD_ID)


func clear_all() -> void:
	# Clear all tracking data
	given_weapons.clear()
	given_items.clear()
	applied_character_abilities.clear()
	last_weapon_config.clear()
	last_item_config.clear()
	last_ability_config.clear()


func has_tracked_items() -> bool:
	return not last_weapon_config.empty() or not last_item_config.empty() or not last_ability_config.empty()
