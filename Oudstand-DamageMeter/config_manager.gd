extends Node
# Manages configuration for the Damage Meter mod
# Saves and loads settings from user://

const MOD_NAME := "DamageMeter"
const CONFIG_PATH := "user://Oudstand-DamageMeter_config.json"

# Default configuration values
const DEFAULT_TOP_K := 6
const DEFAULT_OPACITY := 1.0
const MIN_TOP_K := 1
const MAX_TOP_K := 25
const MIN_OPACITY := 0.3
const MAX_OPACITY := 1.0

var TOP_K: int = DEFAULT_TOP_K
var SHOW_ITEM_COUNT: bool = false
var SHOW_DPS: bool = false
var BAR_OPACITY: float = DEFAULT_OPACITY
var SHOW_PERCENTAGE: bool = true

signal config_changed()


func _ready() -> void:
	_load_saved_config()
	ModLoaderLog.info("ConfigManager initialized", MOD_NAME)

func _save_config() -> void:
	var config := {
		"number_of_sources": TOP_K,
		"show_item_count": SHOW_ITEM_COUNT,
		"show_dps": SHOW_DPS,
		"opacity": BAR_OPACITY,
		"show_percentage": SHOW_PERCENTAGE
	}

	var file := File.new()
	if file.open(CONFIG_PATH, File.WRITE) != OK:
		ModLoaderLog.warning("Failed to save config to %s" % CONFIG_PATH, MOD_NAME)
		return

	file.store_string(JSON.print(config, "\t"))
	file.close()


func _load_saved_config() -> void:
	var file := File.new()
	if not file.file_exists(CONFIG_PATH):
		ModLoaderLog.info("No saved config found, using defaults", MOD_NAME)
		return

	if file.open(CONFIG_PATH, File.READ) != OK:
		ModLoaderLog.warning("Failed to read config from %s" % CONFIG_PATH, MOD_NAME)
		return

	var json_text := file.get_as_text()
	file.close()

	var parse_result := JSON.parse(json_text)
	if parse_result.error != OK:
		ModLoaderLog.warning("Failed to parse config JSON: %s" % parse_result.error_string, MOD_NAME)
		return

	var config = parse_result.result
	if not config is Dictionary:
		return

	_apply_config_values(config)
	ModLoaderLog.info("Loaded config: TOP_K=%d, OPACITY=%.2f, DPS=%s, ITEM_COUNT=%s, PERCENTAGE=%s" % [
		TOP_K, BAR_OPACITY, SHOW_DPS, SHOW_ITEM_COUNT, SHOW_PERCENTAGE
	], MOD_NAME)


func _apply_config_values(config: Dictionary) -> void:
	if config.has("number_of_sources"):
		TOP_K = int(clamp(config.number_of_sources, MIN_TOP_K, MAX_TOP_K))
	if config.has("opacity"):
		BAR_OPACITY = clamp(float(config.opacity), MIN_OPACITY, MAX_OPACITY)
	if config.has("show_item_count"):
		SHOW_ITEM_COUNT = bool(config.show_item_count)
	if config.has("show_dps"):
		SHOW_DPS = bool(config.show_dps)
	if config.has("show_percentage"):
		SHOW_PERCENTAGE = bool(config.show_percentage)
