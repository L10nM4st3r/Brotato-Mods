extends Node

const MOD_ID := "Oudstand-FocusFix"
const MOD_DIR_NAME := "Oudstand-FocusFix"

func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	# No extensions installed to avoid ANY parser interaction with vanilla classes during load.
	# We will rely on pure runtime node manipulation if possible, OR we accept that we cannot fix 'init' crash via ModLoader 
	# without triggering parser errors in this brittle decompilation.
	
	# Attempting a different strategy:
	# Install an extension for 'main.gd' (or root) to inject the FocusEmulator early?
	# No, the crash happens when Options Menu opens (init).
	
	# Let's try installing ONLY the menu_options_extension.gd again but CLEAN.
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("menu_options_extension.gd"))
