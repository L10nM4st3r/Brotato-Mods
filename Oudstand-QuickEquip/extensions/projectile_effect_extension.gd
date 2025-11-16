extends "res://effects/items/projectile_effect.gd"

# Extension to fix division by zero crash when removing the last projectile item
# This is a vanilla bug that occurs when unapplying projectile effects
#
# Strategy: Only intervene in the critical case (removing last projectile),
# otherwise use vanilla logic to remain compatible with future game updates


func unapply(player_index: int) -> void:
	# Check if effect exists before trying to access it
	var effects = RunData.get_player_effects(player_index)
	if not effects.has(key):
		# Effect doesn't exist, nothing to unapply
		return

	var effect: Array = effects[key]
	if effect.empty():
		# Empty effect, set to safe state
		effect.append_array([0, weapon_stats.duplicate(), auto_target_enemy, cooldown])
		return

	var existing_proj_count = effect[0]
	var new_proj_count = existing_proj_count - value

	# CRITICAL FIX: If we're removing the last projectile(s), set count to 0 instead of deleting
	# This prevents division by zero in _merge_scaling_stats AND allows timers to keep running safely
	# (e.g., alien_eyes_timer calls get_player_effect() on timeout - crashes if key doesn't exist)
	if new_proj_count <= 0:
		# Set projectile count to 0 but keep the effect structure intact
		# Structure: [count, weapon_stats, auto_target, cooldown]
		effect[0] = 0
		return

	# Otherwise, use vanilla logic
	.unapply(player_index)
