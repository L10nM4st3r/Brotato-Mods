extends "res://ui/menus/pages/menu_options.gd"


func _on_BackButton_pressed() -> void:
	var target: Control = focus_before_created

	if target == null or not is_instance_valid(target):
		target = _resolve_focus_restore_target()
		focus_before_created = target

	if target != null and target.is_visible_in_tree():
		target.grab_focus()

	emit_signal("back_button_pressed")


func _resolve_focus_restore_target() -> Control:
	var focus_emulator: FocusEmulator = Utils.get_focus_emulator(0)
	if focus_emulator != null and focus_emulator.focused_control != null:
		var focused = focus_emulator.focused_control
		if is_instance_valid(focused):
			return focused

	var owner: Control = get_focus_owner()
	if owner != null and is_instance_valid(owner):
		return owner

	return null
