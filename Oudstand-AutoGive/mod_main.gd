extends Node

# Diese Variable stellt sicher, dass die Items nur einmal pro Lauf gegeben werden.
var items_given := false

func _ready():
	ModLoaderLog.info("AutoGive Mod ready. Waiting for a run to start...", "TestItems")

func _process(_delta):
	# Wir prüfen in jedem Frame (Polling), ob ein Lauf gestartet wurde.
	# Ein Signal-basierter Ansatz war in Tests nicht zuverlässig, daher diese robuste Methode.
	if not items_given and is_instance_valid(RunData) and RunData.get_player_count() > 0 and RunData.current_wave >= 1:
		items_given = true
		ModLoaderLog.info("Run detected (Wave >= 1, Players > 0). Giving items now!", "TestItems")
		
		# Wir warten eine Sekunde, um sicherzustellen, dass die Spiel-UI vollständig geladen ist,
		# bevor wir versuchen, sie zu aktualisieren.
		yield(get_tree().create_timer(1.0), "timeout")
		_give_items()
	
	# Wenn der Spieler zum Menü zurückkehrt (Spieleranzahl ist 0), setzen wir den Mod zurück.
	if items_given and RunData.get_player_count() == 0:
		items_given = false
		ModLoaderLog.info("Back in menu. AutoGive Mod is reset for the next run.", "TestItems")

func _give_items():
	ModLoaderLog.info("=== GIVING TEST ITEMS ===", "TestItems")
	var player_index = 0
	
	# --- HIER KANNST DU DEINE START-WAFFEN ANPASSEN ---
	# Format-Optionen:
	#   "weapon_id"                    -> 1x normal (nicht verflucht)
	#   ["weapon_id", is_cursed]       -> 1x mit cursed status
	#   ["weapon_id", is_cursed, 3]    -> 3x mit cursed status
	var weapons_to_give = [
		# "weapon_revolver_1",
		# ["weapon_revolver_1", true],
		# ["weapon_revolver_1", false, 2],  # 2x normal
	]

	# --- HIER KANNST DU DEINE START-ITEMS ANPASSEN ---
	# Format-Optionen:
	#   "item_id"                      -> 1x normal (nicht verflucht)
	#   ["item_id", is_cursed]         -> 1x mit cursed status
	#   ["item_id", is_cursed, 5]      -> 5x mit cursed status
	var items_to_give = [
		# ["item_baby_elephant", false, 5],  # 5x normal
		# ["item_hunting_trophy", false, 3],
		# ["item_tree", false, 14],
		# "item_cyberball",
		# ["item_cyberball", true],
		# "item_greek_fire",
		# "item_giant_belt",
		# ["item_blindfold",false, 20],
		# ["item_alien_baby", false, 500]
	]

	# --- Waffen-Logik ---
	var all_weapons_list = ItemService.get("weapons")
	if is_instance_valid(ItemService) and all_weapons_list != null:
		for weapon_data in weapons_to_give:
			var weapon_id = ""
			var is_cursed = false
			var count = 1

			# Parse format: "weapon_id" oder ["weapon_id", is_cursed] oder ["weapon_id", is_cursed, count]
			if typeof(weapon_data) == TYPE_ARRAY:
				weapon_id = weapon_data[0]
				is_cursed = weapon_data[1] if weapon_data.size() > 1 else false
				count = weapon_data[2] if weapon_data.size() > 2 else 1
			else:
				weapon_id = weapon_data

			var base_weapon = null
			for w in all_weapons_list:
				var current_weapon_id = w.get("my_id")
				if current_weapon_id != null and current_weapon_id == weapon_id:
					base_weapon = w
					break

			if is_instance_valid(base_weapon):
				for _i in range(count):
					var weapon = base_weapon.duplicate()
					weapon.is_cursed = is_cursed
					RunData.add_weapon(weapon, player_index)
				ModLoaderLog.info("Added weapon: %s (cursed: %s, count: %d)" % [weapon_id, is_cursed, count], "TestItems")
			else:
				ModLoaderLog.error("Weapon not found in ItemService.weapons: %s" % weapon_id, "TestItems")
	else:
		ModLoaderLog.error("ItemService or ItemService.weapons not found!", "TestItems")

	# --- Item-Logik ---
	for item_data in items_to_give:
		var item_id = ""
		var is_cursed = false
		var count = 1

		# Parse format: "item_id" oder ["item_id", is_cursed] oder ["item_id", is_cursed, count]
		if typeof(item_data) == TYPE_ARRAY:
			item_id = item_data[0]
			is_cursed = item_data[1] if item_data.size() > 1 else false
			count = item_data[2] if item_data.size() > 2 else 1
		else:
			item_id = item_data

		var item = ItemService.get_element(ItemService.items, item_id)
		if is_instance_valid(item):
			for _i in range(count):
				var item_copy = item.duplicate()
				item_copy.is_cursed = is_cursed
				RunData.add_item(item_copy, player_index)
			ModLoaderLog.info("Added item: %s (cursed: %s, count: %d)" % [item_id, is_cursed, count], "TestItems")
		else:
			ModLoaderLog.error("Failed to create item: %s" % item_id, "TestItems")
	
	ModLoaderLog.info("=== ITEMS GIVEN SUCCESSFULLY ===", "TestItems")
	
	# UI Refresh: Sendet Signale, damit das Spiel die Anzeige aktualisiert.
	yield(get_tree(), "idle_frame")
	if RunData.has_signal("items_changed"): RunData.emit_signal("items_changed")
	if RunData.has_signal("weapons_changed"): RunData.emit_signal("weapons_changed")
