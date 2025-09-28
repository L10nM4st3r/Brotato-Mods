extends Node

const MOD_DIR_NAME := "Oudstand-DamageMeter"

func _init():
	var extensions_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME).plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("ui/hud/player_damage_updater.gd"))
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("ui/hud/player_damage_positioning.gd"))

func _ready():
	pass
