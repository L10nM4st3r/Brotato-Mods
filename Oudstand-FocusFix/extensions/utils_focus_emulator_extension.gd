extends "res://singletons/utils.gd"

var _focus_fix_cache := {}


func get_focus_emulator(player_index: int, root = get_scene_node()) -> FocusEmulator:
	var focus_emulator: FocusEmulator = .get_focus_emulator(player_index, root)
	if focus_emulator != null:
		return focus_emulator

	if root == null:
		return null

	var cache_key = "%s_%s" % [root.get_instance_id(), player_index]
	if _focus_fix_cache.has(cache_key):
		var cached: FocusEmulator = _focus_fix_cache[cache_key]
		if is_instance_valid(cached):
			return cached
		_focus_fix_cache.erase(cache_key)

	var fallback: FocusEmulator = _find_focus_emulator_deep(root, player_index)
	if fallback != null:
		_focus_fix_cache[cache_key] = fallback
	return fallback


func _find_focus_emulator_deep(root: Node, player_index: int) -> FocusEmulator:
	var candidate_names = [
		"FocusEmulator%s" % (player_index + 1),
		"FocusEmulator_%s" % (player_index + 1),
		"FocusEmulator%d" % player_index,
		"FocusEmulator"
	]

	for name in candidate_names:
		var node := root.find_node(name, true, false)
		if node != null and node is FocusEmulator:
			return node as FocusEmulator

	return null
