class_name AirportHUD
extends SushiHUD
## Reuses the foundation's UI primitives, signals and purchasing boundary.
var case_label: Label
var contents_label: Label
var dog_label: Label
var xray_panel: PanelContainer
var xray_canvas: XrayCanvas
var xray_large = false
var route_guide: Label
var throw_demo_label = ""
signal action_requested(action: String, id: int, extra: Variant)
signal modal_closed
var browser: PanelContainer
var browser_bag_id = -1
var browser_signature = ""
var browser_picker: OptionButton
var browser_rows: VBoxContainer
var browser_summary: Label
var repack_button: Button
var pet_button: Button
var station_panel: PanelContainer
var station_rows: VBoxContainer
var lock_panel: PanelContainer
var lock_label: Label
var lock_bag_id = -1
const UPGRADE_ORDER = ["scanner", "kennel", "evidence", "bio_lab", "belt", "terminal"]
const COSTS = [45, 35, 30, 70, 55, 120]

class XrayCanvas extends Control:
	var items: Array = []
	var scanned = false
	var identified = false
	var animal = false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("082c36"))
		for x in range(0, int(size.x), 20):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.15, 0.6, 0.65, 0.12))
		for y in range(0, int(size.y), 20):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.15, 0.6, 0.65, 0.12))
		if not scanned:
			return
		if animal:
			var bone = Color("a9f4e8")
			draw_line(Vector2(80,75),Vector2(220,75),bone,6)
			draw_circle(Vector2(245,55),20,bone,false,4)
			draw_line(Vector2(220,75),Vector2(235,62),bone,5)
			for x in [95,130,175,210]:
				draw_line(Vector2(x,75),Vector2(x-8,120),bone,5)
			for x in [145,160,175]:
				draw_line(Vector2(x,61),Vector2(x,90),bone,3)
			draw_line(Vector2(80,75),Vector2(53,48),bone,5)
			draw_string(ThemeDB.fallback_font,Vector2(60,150),"VERY GOOD BOY / TRAINING VIEW",HORIZONTAL_ALIGNMENT_LEFT,-1,13,bone)
			return
		for i in range(items.size()):
			var item: Dictionary = items[i]
			var point = Vector2(45 + (i % 3) * 90, 40 + (i / 3) * 70)
			var color = Color("70e1d3")
			match str(item.get("kind", "unknown")) if identified else "unknown":
				"fruit": draw_circle(point, 16, color)
				"vegetable": draw_colored_polygon(PackedVector2Array([point + Vector2(-10,-20), point+Vector2(12,-16), point+Vector2(0,22)]), color)
				"seeds":
					for n in range(4): draw_circle(point+Vector2((n%2)*13-6,(n/2)*13-6), 4, color)
				"dildo", "vibrator":
					draw_rect(Rect2(point+Vector2(-8,-17),Vector2(16,34)),color)
					draw_circle(point+Vector2(0,-17),8,color)
					if item.kind == "vibrator": draw_circle(point+Vector2(0,8),3,Color("082c36"))
				"cat", "rabbit", "pet_dog", "parrot", "tortoise", "pet_cat", "pet_rabbit":
					draw_ellipse_shape(point, color)
				_:
					draw_rect(Rect2(point-Vector2(22,14),Vector2(44,28)),color,false,3)
					draw_line(point+Vector2(-18,0),point+Vector2(18,0),color,2)
			if identified:
				var short_label = str(item.label).left(15)
				draw_string(ThemeDB.fallback_font, point+Vector2(-35,40),short_label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("bff4e9"))
	func draw_ellipse_shape(point: Vector2, color: Color) -> void:
		draw_circle(point, 13, color)
		draw_circle(point + Vector2(16, -9), 8, color)
		for x in [-8, 8]: draw_line(point + Vector2(x, 8), point + Vector2(x, 22), color, 4)

func _ready() -> void:
	var stats_panel = panel(Vector2(386,16),Vector2(490,76))
	stats = label("",19)
	stats_panel.add_child(stats)
	var case_panel = panel(Vector2(900,16),Vector2(362,185))
	case_label = label("",16)
	case_panel.add_child(case_label)
	xray_panel = panel(Vector2(900,215),Vector2(362,220))
	var scan_box = VBoxContainer.new()
	xray_panel.add_child(scan_box)
	scan_box.add_child(label("LIVE X-RAY / [F] ENLARGE",15,Color("80dccb")))
	xray_canvas = XrayCanvas.new()
	xray_canvas.custom_minimum_size = Vector2(320,160)
	xray_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scan_box.add_child(xray_canvas)
	var contents_panel = panel(Vector2(900,450),Vector2(362,150))
	contents_label = label("",14)
	contents_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents_panel.add_child(contents_label)
	var guide = panel(Vector2(18,150),Vector2(300,174))
	route_guide = label("",13)
	guide.add_child(route_guide)
	var dog_panel = panel(Vector2(18,350),Vector2(300,118))
	dog_label = label("",15,Color("e3ce91"))
	dog_panel.add_child(dog_label)
	var carry_panel = panel(Vector2(18,490),Vector2(350,165))
	inventory = label("",16)
	carry_panel.add_child(inventory)
	prompt = label("",19)
	prompt.position = Vector2(390,550)
	prompt.size = Vector2(490,100)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_shadow_color",Color("152a31"))
	prompt.add_theme_constant_override("shadow_offset_x",2)
	prompt.add_theme_constant_override("shadow_offset_y",2)
	add_child(prompt)
	event_label = label("",15,Color("e5cf8a"))
	event_label.position = Vector2(18,112)
	event_label.size.x = 1240
	add_child(event_label)
	chapter = label("",16,Color("e2c77d"))
	chapter.position = Vector2(345,145)
	chapter.size = Vector2(535,55)
	chapter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(chapter)
	var center = label("+",24)
	center.position = Vector2(630,345)
	add_child(center)
	var controls = panel(Vector2(18,665),Vector2(1244,49))
	controls.add_child(label("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   SPACE JUMP / LOCK   E USE   1/2/3 HANDS/KEY/PLIERS   O OPEN   C CLOSE   R RELOCK\nI CONTENTS / REPACK   G THROW BAG/ITEM/DOG   Q GENTLE DROP   H HELP CARRY   K CALL DOG   P DOG MODE   TAB UPGRADES   ESC CURSOR / CLOSE",12))
	_build_airport_shop()
	_build_expansion_panels()
	var shift_panel = panel(Vector2(390,285),Vector2(490,155))
	shift_label = label("",22)
	shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shift_panel.add_child(shift_label)
	shift_panel.visible = false
	pointer_panel = panel(Vector2(470,225),Vector2(340,140))
	var pointer_box = VBoxContainer.new()
	pointer_panel.add_child(pointer_box)
	pointer_box.add_child(label("CURSOR RELEASED",22))
	pointer_box.add_child(label("ESC resumes. Airport keeps running.",15))
	var back = Button.new()
	back.text = "Return to main menu"
	back.pressed.connect(func(): menu_requested.emit())
	pointer_box.add_child(back)
	pointer_panel.visible = false

func _build_airport_shop() -> void:
	shop = panel(Vector2(348,180),Vector2(540,450))
	shop.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	shop.add_child(rows)
	rows.add_child(label("AIRPORT DEVELOPMENT",24,Color("e2c77d")))
	rows.add_child(label("Earned funds. 1–6 buy. TAB closes.\nTerminal expansion: 5 handled / 5 reputation.",15))
	for kind in UPGRADE_ORDER:
		var button = Button.new()
		button.custom_minimum_size = Vector2(500,43)
		button.pressed.connect(func(): upgrade_requested.emit(kind))
		rows.add_child(button)
		shop_buttons.append(button)
	shop.visible = false

func set_throw_demo(label_text: String) -> void:
	throw_demo_label = label_text
	for node in [case_label.get_parent(),xray_panel,contents_label.get_parent(),route_guide.get_parent(),dog_label.get_parent()]:
		node.visible = false
	# Recording titles and player IDs belong outside the gameplay image.
	chapter.visible = false
	stats.get_parent().position = Vector2(1012,16)
	stats.get_parent().size = Vector2(250,76)

func route_name(route: String) -> String:
	return {"gate_a":"FLIGHT A / NW101", "gate_b":"FLIGHT B / SE202", "gate_c":"FLIGHT C / INT303", "oversize":"OVERSIZE", "security":"SECURITY / CUSTOMS", "bio":"BIOSECURITY", "rescue":"ANIMAL CARE"}.get(route,route.to_upper())

func refresh_airport(sim, peer_id: int, bag_id: int, target_text: String, feedback_text: String) -> void:
	route_guide.text = "READ TAG → MATCH FLIGHT A / B" + (" / C" if sim.airport_level >= 2 else "") + "\nLEGAL → FLIGHT / LARGE: OVERSIZE\nNARCOTICS / CUSTOMS → SECURITY\nORGANIC → BIOSECURITY\nWILDLIFE / FED PET → ANIMAL CARE\nWEAPONS / EXPLOSIVES / DANGEROUS:\nREMOVE → SECURE DISPOSAL\n[E] STATION MENUS / [I] ITEM BROWSER"
	var seconds = int(ceil(sim.time_left))
	stats.text = "$%d   REP %d   AIRPORT LV.%d\n%d HANDLED   %d:%02d   %s" % [sim.money,sim.reputation,sim.airport_level,sim.handled,seconds/60,seconds%60,"BELT RUNNING" if sim.belt_running else "INTAKE PAUSED"]
	var player: Dictionary = sim.players.get(peer_id,{"held_kind":"","held_id":-1,"tool":0})
	var held = str(player.held_kind).to_upper() if player.held_kind != "" else "EMPTY HANDS"
	inventory.text = "%s / %s\nHEALTH %.0f   STAMINA %.0f\nKEY %d/8 / PLIERS %d/5 USES\nFOOD %d / WATER %d / SEALS %d" % [["HANDS","APPROVED KEY","LARGE PLIERS"][int(player.tool)],held,float(player.get("health",100)),float(player.get("stamina",100)),int(player.get("key_durability",8)),int(player.get("pliers_durability",5)),int(player.get("food",0)),int(player.get("water",0)),int(player.get("seals",0))]
	if int(player.get("carry_partner",-1)) > 0: inventory.text += "\nTWO-PERSON CARRY / [H] RELEASE"
	if player.held_kind == "bag" and sim.bags.has(player.held_id):
		var mass = float(sim.bags[player.held_id].mass_kg)
		inventory.text += "\n%.0f kg / CARRY %d%%\n[G] THROW    [Q] GENTLE DROP" % [mass,int(sim.carry_speed(peer_id)*100)]
		if sim.carry_speed(peer_id) <= 0.001: inventory.text += "\nWAITING FOR HELPER / [H] JOIN"
	if throw_demo_label != "":
		stats.text = "THROWS %d\nMID-AIR CATCHES %d" % [sim.throws,sim.catches]
	prompt.text = target_text
	event_label.text = feedback_text if feedback_text != "" else sim.last_event
	dog_label.text = "DOG / %s / XP %d\nHUNGER %.0f / THIRST %.0f\nREST %.1fs / TRAINING SCANS %d\n%s\n[K] CALL / [P] MODE / [G] GENTLE TOSS\nFOOD / WATER / REST AT ANIMAL CARE" % [str(sim.dog.get("mode","follow")).to_upper(),int(sim.dog.get("xp",0)),float(sim.dog.get("hunger",0)),float(sim.dog.get("thirst",0)),float(sim.dog.get("rest_left",0)),sim.dog_scan_count,"WOOF! Inspect #%d (clue only)" % sim.dog.alert_bag if sim.dog.bark_left > 0 else "An alert is not a conviction."]
	case_label.text = "ARRIVAL MANIFEST\nLook at a bag to select it."
	contents_label.text = "BAG CONTENTS\nOpen an unlocked bag to inspect.\nLegal personal items are not contraband."
	xray_canvas.items = []
	xray_canvas.scanned = false
	xray_canvas.animal = false
	if sim.bags.has(bag_id):
		var bag: Dictionary = sim.bags[bag_id]
		case_label.text = "BAG #%02d  /  %.1f kg\n%s / %s / FLIGHT %s\nLOCK: %s / %s\n%s / DAMAGE %.0f%%\n[O] OPEN / [C] CLOSE / [R] RELOCK\n[I] CONTENTS / [H] HEAVY CARRY" % [bag.id,float(bag.mass_kg),["CABIN","DUFFEL","BACKPACK","TRUNK"][int(bag.kind) % 4],["SMALL","MEDIUM","LARGE"][int(bag.size) % 3],["A / NW101","B / SE202","C / INT303"][int(bag.flight) % 3],str(bag.lock).to_upper(),"UNLOCKED" if bag.unlocked else "LOCKED","OPEN" if bag.opened else "CLOSED",float(bag.get("damage",0))]
		if bag.scanned:
			xray_canvas.items = bag.items.filter(func(item): return item.get("location","bag") == "bag")
			xray_canvas.scanned = true
			xray_canvas.identified = bag.opened
		if bag.opened:
			contents_label.text = "INSPECTED / %s\n[I] Browse every item + mass\nChoose any item, return to ANY open bag.\nFood / water needed before pet routing." % str(bag.get("category","unknown")).to_upper()
			if not bag.get("pet",{}).is_empty():
				contents_label.text += "\nPET: %s / hunger %.0f / thirst %.0f" % [str(bag.pet.get("species","animal")),float(bag.pet.get("hunger",0)),float(bag.pet.get("thirst",0))]
	if sim.dog.location == "belt":
		case_label.text = "SCAN SUBJECT / DETECTION DOG\nFICTIONAL TRAINING SCANNER\nNON-IONIZING / NO ANIMAL HARM"
		xray_canvas.items = []
		xray_canvas.animal = true
		xray_canvas.scanned = bool(sim.dog.scanned)
		contents_label.text = "VERY GOOD BOY\nHarmless cartoon training scan.\nDog is safe and ready to return to work."
	xray_canvas.queue_redraw()
	refresh_lock(player)
	xray_panel.visible = throw_demo_label == ""
	xray_panel.position = Vector2(330,215) if xray_large else Vector2(900,215)
	xray_panel.size = Vector2(550,290) if xray_large else Vector2(362,220)
	var titles = ["Scanner II: faster inspection scans", "Dog training: alerts (needs 1 training scan)", "Evidence bench: double seizure bonus", "Biosecurity lab: +$20 organic recovery", "Intake upgrade: larger / faster queue", "Terminal expansion: flight C + oversize"]
	for i in range(shop_buttons.size()):
		var installed = bool(sim.upgrades[UPGRADE_ORDER[i]])
		shop_buttons[i].text = "[%d] " % (i+1) + ("INSTALLED  /  " if installed else "$%d  /  " % COSTS[i]) + titles[i]
		shop_buttons[i].disabled = installed or sim.money < COSTS[i] or (UPGRADE_ORDER[i] == "terminal" and (sim.handled < 5 or sim.reputation < 5)) or (UPGRADE_ORDER[i] == "kennel" and sim.dog_scan_count < 1)
	shift_label.get_parent().visible = sim.shift_finished
	shift_label.text = "SHIFT COMPLETE\n%d HANDLED  /  %d RESCUED\nHOST: PRESS N FOR NEXT SHIFT" % [sim.handled,sim.rescues]

func _action_button(text: String, action: String, id: int = -1, extra: Variant = null) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(_emit_action.bind(action, id, extra))
	return button

func _emit_action(action: String, id: int, extra: Variant) -> void:
	action_requested.emit(action, id, extra)

func _dismiss_button() -> Button:
	var button = Button.new()
	button.text = "Close / ESC"
	button.custom_minimum_size.y = 34
	button.pressed.connect(func(): modal_closed.emit())
	return button

func _clear_rows(rows: VBoxContainer) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

func _build_expansion_panels() -> void:
	browser = panel(Vector2(325,150), Vector2(630,480))
	browser.mouse_filter = Control.MOUSE_FILTER_STOP
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	browser.add_child(box)
	box.add_child(label("CONTENTS / ITEM-BY-ITEM REPACKING",22))
	browser_summary = label("",15)
	browser_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browser_summary.custom_minimum_size.x = 590
	box.add_child(browser_summary)
	browser_picker = OptionButton.new()
	browser_picker.item_selected.connect(func(index): browser_bag_id = browser_picker.get_item_id(index); browser_signature = "")
	box.add_child(browser_picker)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590,220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	browser_rows = VBoxContainer.new()
	browser_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(browser_rows)
	repack_button = Button.new()
	repack_button.text = "Return carried item to this open bag"
	repack_button.pressed.connect(func(): action_requested.emit("return_item",browser_bag_id,null))
	box.add_child(repack_button)
	pet_button = Button.new()
	pet_button.text = "Give pet carried food + water"
	pet_button.pressed.connect(func(): action_requested.emit("feed_pet",browser_bag_id,null))
	box.add_child(pet_button)
	box.add_child(_dismiss_button())
	browser.visible = false
	station_panel = panel(Vector2(350,140),Vector2(580,500))
	station_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	station_rows = VBoxContainer.new()
	station_rows.add_theme_constant_override("separation", 5)
	station_panel.add_child(station_rows)
	station_panel.visible = false
	lock_panel = panel(Vector2(390,225),Vector2(490,220))
	lock_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var lock_box = VBoxContainer.new()
	lock_panel.add_child(lock_box)
	lock_label = label("",20)
	lock_box.add_child(lock_label)
	var buttons = HBoxContainer.new()
	lock_box.add_child(buttons)
	for value in range(3):
		var button = Button.new()
		button.text = "INPUT %d" % (value + 1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		button.pressed.connect(func(): action_requested.emit("lock_input",lock_bag_id,value))
		buttons.add_child(button)
	lock_panel.visible = false

func show_station(title: String, actions: Array, bag_id: int) -> void:
	_clear_rows(station_rows)
	station_rows.add_child(label(title,24))
	station_rows.add_child(label("Must remain close to this station.\nBring the dog here for feeding, water or rest.",14))
	for entry in actions:
		station_rows.add_child(_action_button(str(entry[0]),str(entry[1]),bag_id if entry[1] == "feed_pet" else -1,entry[2]))
	station_rows.add_child(_dismiss_button())
	station_panel.visible = true

func refresh_lock(player: Dictionary) -> void:
	var challenge: Dictionary = player.get("lock_game",{})
	lock_panel.visible = not challenge.is_empty()
	if challenge.is_empty(): return
	lock_bag_id = int(challenge.get("bag_id",-1))
	var sequence: Array = challenge.get("sequence",[])
	var progress = int(challenge.get("progress",0))
	var text: Array[String] = []
	for index in range(sequence.size()):
		text.append("✓" if index < progress else (">%d<" if index == progress else "[%d]") % (int(sequence[index])+1))
	lock_label.text = "LOCK #%d / %.1f SECONDS\n%s\nPress physical 1 / 2 / 3 or click.\nSPACE = INPUT 1 (jump disabled here).\n%d / %d completed" % [lock_bag_id,float(challenge.get("remaining",0)),"  ".join(text),progress,sequence.size()]

func refresh_browser(sim, peer_id: int, nearby_ids: Array[int]) -> void:
	if not browser.visible: return
	var player: Dictionary = sim.players.get(peer_id,{})
	if not nearby_ids.has(browser_bag_id): browser_bag_id = nearby_ids[0] if not nearby_ids.is_empty() else -1
	var bag: Dictionary = sim.bags.get(browser_bag_id,{})
	var signature = str([nearby_ids,browser_bag_id,bag.get("items",[]),player.get("held_kind",""),player.get("held_id",-1),bag.get("pet",{})])
	if browser_signature == signature: return
	browser_signature = signature
	browser_picker.clear()
	for id in nearby_ids:
		browser_picker.add_item("Bag #%d / %.1f kg" % [id,float(sim.bags[id].mass_kg)],id)
		if id == browser_bag_id: browser_picker.select(browser_picker.item_count-1)
	_clear_rows(browser_rows)
	browser_summary.text = "Only open, nearby bags are listed. Pick ANY item; choose another bag to repack."
	if bag.is_empty():
		browser_summary.text = "No open bag within reach. Close this browser, approach a bag and press O."
	else:
		for index in range(bag.items.size()):
			var item: Dictionary = bag.items[index]
			var button = _action_button("%s / %.2f kg / %s%s" % [str(item.get("label","Item")),float(item.get("mass_kg",0)),str(item.get("category","unknown")).to_upper()," [REMOVED]" if item.location != "bag" else ""],"take_item",browser_bag_id,index)
			button.disabled = item.location != "bag" or player.get("held_kind","") != ""
			browser_rows.add_child(button)
	repack_button.disabled = bag.is_empty() or player.get("held_kind","") != "item"
	pet_button.visible = not bag.get("pet",{}).is_empty()
