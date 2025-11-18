extends Node

const MOD_ID := "Oudstand-FocusFix"
const MOD_DIR_NAME := "Oudstand-FocusFix"


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_install_extensions(mod_dir_path)


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("utils_focus_emulator_extension.gd"))
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("menu_options_extension.gd"))
