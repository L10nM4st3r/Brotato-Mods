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
	# Das Format ist: ["waffen_id", is_cursed (true/false)]
	var weapons_to_give = [
		# ["weapon_revolver_1", true],
		# ["weapon_revolver_1", false],
	]
	
	# --- HIER KANNST DU DEINE START-ITEMS ANPASSEN ---
	# Das Format ist: ["item_id", is_cursed (true/false)]
	# Wenn nur die ID angegeben wird (String), wird das Item NICHT verflucht sein.
	var items_to_give = [
		# "item_pocket_factory",
		"item_baby_elephant",
		"item_baby_elephant",
		"item_baby_elephant",
		"item_baby_elephant",
		"item_baby_elephant",
		["item_baby_elephant", true],
		# "item_hunting_trophy",
		# "item_hunting_trophy",
		# "item_hunting_trophy",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		# "item_tree",
		"item_evil_hat",
		# "item_ricochet",
		# "item_ricochet",
		# "item_ricochet",
		# "item_seashell",
		# "item_lumberjack_shirt",
		# "item_blindfold",
		# "item_cyberball",
		# "item_cyberball",
		# ["item_cyberball", true],
	]

	# --- Waffen-Logik ---
	var all_weapons_list = ItemService.get("weapons")
	if is_instance_valid(ItemService) and all_weapons_list != null:
		for weapon_data in weapons_to_give:
			var base_weapon = null
			for w in all_weapons_list:
				var current_weapon_id = w.get("my_id")
				if current_weapon_id != null and current_weapon_id == weapon_data[0]:
					base_weapon = w
					break
			
			if is_instance_valid(base_weapon):
				var weapon = base_weapon.duplicate()
				weapon.is_cursed = weapon_data[1]
				RunData.add_weapon(weapon, player_index)
				ModLoaderLog.info("Added weapon: %s" % weapon_data[0], "TestItems")
			else:
				ModLoaderLog.error("Weapon not found in ItemService.weapons: %s" % weapon_data[0], "TestItems")
	else:
		ModLoaderLog.error("ItemService or ItemService.weapons not found!", "TestItems")

	# --- Item-Logik ---
	for item_data in items_to_give:
		var item_id = ""
		var is_cursed = false

		# Unterstützt beide Formate: "item_id" oder ["item_id", true/false]
		if typeof(item_data) == TYPE_ARRAY:
			item_id = item_data[0]
			is_cursed = item_data[1] if item_data.size() > 1 else false
		else:
			item_id = item_data

		var item = ItemService.get_element(ItemService.items, item_id)
		if is_instance_valid(item):
			item = item.duplicate()
			item.is_cursed = is_cursed
			RunData.add_item(item, player_index)
			ModLoaderLog.info("Added item: %s (cursed: %s)" % [item_id, is_cursed], "TestItems")
		else:
			ModLoaderLog.error("Failed to create item: %s" % item_id, "TestItems")
	
	ModLoaderLog.info("=== ITEMS GIVEN SUCCESSFULLY ===", "TestItems")
	
	# UI Refresh: Sendet Signale, damit das Spiel die Anzeige aktualisiert.
	yield(get_tree(), "idle_frame")
	if RunData.has_signal("items_changed"): RunData.emit_signal("items_changed")
	if RunData.has_signal("weapons_changed"): RunData.emit_signal("weapons_changed")
