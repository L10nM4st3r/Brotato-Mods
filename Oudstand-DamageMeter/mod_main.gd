extends Node

const MOD_DIR_NAME := "Oudstand-DamageMeter"
const MOD_ID := "Oudstand-DamageMeter"

var config_manager = null


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)

	_load_translations(mod_dir_path)
	_setup_autoloads(mod_dir_path)
	_install_extensions(mod_dir_path)


func _load_translations(mod_dir_path: String) -> void:
	var translations_dir := mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir.plus_file("DamageMeter.en.translation"))
	ModLoaderMod.add_translation(translations_dir.plus_file("DamageMeter.de.translation"))


func _setup_autoloads(mod_dir_path: String) -> void:
	config_manager = _create_autoload(
		mod_dir_path.plus_file("config_manager.gd"),
		"DamageMeterConfig"
	)

	var charm_tracker := _create_autoload(
		mod_dir_path.plus_file("extensions/charm_tracker.gd"),
		"DamageMeterCharmTracker"
	)

	var options_injector := _create_autoload(
		mod_dir_path.plus_file("ui/options/options_menu_injector.gd"),
		"DamageMeterOptionsInjector"
	)


func _create_autoload(script_path: String, node_name: String) -> Node:
	var script = load(script_path)
	var instance = script.new()
	instance.name = node_name
	add_child(instance)
	return instance


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("enemy_extension.gd"))

	var ui_extensions_dir := mod_dir_path.plus_file("ui/hud")
	ModLoaderMod.install_script_extension(ui_extensions_dir.plus_file("player_damage_updater.gd"))
	ModLoaderMod.install_script_extension(ui_extensions_dir.plus_file("main_extension.gd"))

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
