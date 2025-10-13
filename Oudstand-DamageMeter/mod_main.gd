extends Node

const MOD_DIR_NAME := "Oudstand-DamageMeter"
const MOD_ID := "Oudstand-DamageMeter"

var config_manager = null

func _init():
	var mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)

	# Add translations
	var translations_dir_path = mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir_path.plus_file("DamageMeter.en.translation"))
	ModLoaderMod.add_translation(translations_dir_path.plus_file("DamageMeter.de.translation"))

	# Add ConfigManager as an autoload (singleton)
	var config_script = load(mod_dir_path.plus_file("config_manager.gd"))
	config_manager = config_script.new()
	config_manager.name = "DamageMeterConfig"
	add_child(config_manager)

	var extensions_dir_path = mod_dir_path.plus_file("ui/hud")
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("player_damage_updater.gd"))
	# Don't extend player_ui_elements.gd - it causes signal duplication issues
	# ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("player_damage_positioning.gd"))

	# Instead, extend Main.gd to handle positioning
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("main_extension.gd"))

func _ready():
	# Initialize config for ModLoader (like Trade mod does)
	_init_config()

func _init_config() -> void:
	var data = ModLoaderStore.mod_data[MOD_ID]
	if data == null:
		return

	var version = data.manifest.version_number
	ModLoaderLog.info("Current Version is %s" % version, MOD_ID)

	var config = ModLoaderConfig.get_config(MOD_ID, version)
	if config == null:
		var default_config = ModLoaderConfig.get_default_config(MOD_ID)
		if default_config != null:
			config = ModLoaderConfig.create_config(MOD_ID, version, default_config.data)
		else:
			config = ModLoaderConfig.create_config(MOD_ID, version, {})

	if config != null and ModLoaderConfig.get_current_config_name(MOD_ID) != version:
		ModLoaderConfig.set_current_config(config)
		if config.is_valid():
			config.save_to_file()
			ModLoaderLog.info("Saved config to: %s" % config.save_path, MOD_ID)
