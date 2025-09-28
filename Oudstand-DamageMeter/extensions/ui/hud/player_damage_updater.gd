extends "res://ui/hud/ui_wave_timer.gd"

onready var _hud = get_tree().get_current_scene().get_node("UI/HUD")
var update_timer = null
var active_displays = []
var wave_start_item_damages = {}

const MOD_DIR_NAME := "Oudstand-DamageMeter"

class DamageSourceSorter:
	static func sort_by_damage(a, b):
		return a.damage > b.damage

func _ready():
	var tscn_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME).plus_file("ui/hud/player_dmg_bar.tscn")
	var player_dmg_bar_scene = load(tscn_path)
	var player_count = RunData.get_player_count()

	if player_dmg_bar_scene:
		for i in range(player_count):
			var player_index_str = str(i + 1)
			var dmg_container_name = "PlayerDamageContainerP%s" % player_index_str
			var life_container_node = _hud.get_node_or_null("LifeContainerP%s" % player_index_str)

			if is_instance_valid(life_container_node):
				var display_node = null
				if not life_container_node.has_node(dmg_container_name):
					var dmg_bar_instance = player_dmg_bar_scene.instance()
					dmg_bar_instance.name = dmg_container_name
					life_container_node.add_child(dmg_bar_instance)
				
				display_node = life_container_node.get_node(dmg_container_name)
				if is_instance_valid(display_node):
					active_displays.append(display_node)

	for i in range(player_count):
		wave_start_item_damages[i] = {}
		if RunData.tracked_item_effects.size() > i:
			for item in RunData.get_player_items(i):
				if is_instance_valid(item) and item.tracking_text == "DAMAGE_DEALT":
					wave_start_item_damages[i][item.my_id] = RunData.tracked_item_effects[i].get(item.my_id, 0)

	update_timer = Timer.new()
	update_timer.connect("timeout", self, "update_damage_bars")
	update_timer.wait_time = 0.25
	add_child(update_timer)
	update_timer.start()

func get_damage_for_source(source, player_index):
	if not is_instance_valid(source): return 0
	if source.get_category() == Category.WEAPON:
		return source.dmg_dealt_last_wave
	elif source.tracking_text == "DAMAGE_DEALT":
		var start_damage = wave_start_item_damages.get(player_index, {}).get(source.my_id, 0)
		var current_damage = 0
		if RunData.tracked_item_effects.size() > player_index and RunData.tracked_item_effects[player_index].has(source.my_id):
			current_damage = RunData.tracked_item_effects[player_index][source.my_id]
		return current_damage - start_damage
	return 0

func update_damage_bars():
	if wave_timer == null or not is_instance_valid(wave_timer) or wave_timer.time_left <= 0:
		for display in active_displays:
			if is_instance_valid(display):
				display.visible = false
		return

	var player_count = RunData.get_player_count()
	var player_damages = []
	var max_total_damage = 0
	
	for i in range(player_count):
		var total_damage = 0
		var all_sources = RunData.get_player_weapons(i) + RunData.get_player_items(i)
		for source in all_sources:
			total_damage += get_damage_for_source(source, i)
		player_damages.append(total_damage)
		if total_damage > max_total_damage:
			max_total_damage = total_damage
	
	for i in range(player_count):
		if active_displays.size() <= i or not is_instance_valid(active_displays[i]):
			continue

		var total_damage = player_damages[i]
		var sources_with_damage = []
		var all_sources = RunData.get_player_weapons(i) + RunData.get_player_items(i)
		for source in all_sources:
			var damage_this_wave = get_damage_for_source(source, i)
			if damage_this_wave > 0:
				sources_with_damage.append({"source": source, "damage": damage_this_wave})

		sources_with_damage.sort_custom(DamageSourceSorter, "sort_by_damage")

		var display = active_displays[i]
		var is_top_player = (player_count > 1 and total_damage == max_total_damage and total_damage > 0)
		var character_obj = RunData.get_player_character(i)
		if is_instance_valid(character_obj):
			display.update_total_damage(total_damage, max_total_damage, is_top_player, player_count == 1, character_obj.icon)
			display.update_source_list(sources_with_damage)
			display.visible = true
