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
			var color = Color("70e1d3") if item.category == "legal" else Color("e4ae57")
			match item.kind:
				"fruit": draw_circle(point, 16, color)
				"vegetable": draw_colored_polygon(PackedVector2Array([point + Vector2(-10,-20), point+Vector2(12,-16), point+Vector2(0,22)]), color)
				"seeds":
					for n in range(4): draw_circle(point+Vector2((n%2)*13-6,(n/2)*13-6), 4, color)
				"dildo", "vibrator":
					draw_rect(Rect2(point+Vector2(-8,-17),Vector2(16,34)),color)
					draw_circle(point+Vector2(0,-17),8,color)
					if item.kind == "vibrator": draw_circle(point+Vector2(0,8),3,Color("082c36"))
				"person_at_risk", "adult_silhouette":
					draw_circle(point+Vector2(0,-17),8,color)
					draw_line(point+Vector2(0,-8),point+Vector2(0,16),color,6)
					draw_line(point+Vector2(-13,0),point+Vector2(13,0),color,5)
					draw_line(point+Vector2(0,14),point+Vector2(-10,27),color,5)
					draw_line(point+Vector2(0,14),point+Vector2(10,27),color,5)
				_:
					draw_rect(Rect2(point-Vector2(22,14),Vector2(44,28)),color,false,3)
					draw_line(point+Vector2(-18,0),point+Vector2(18,0),color,2)
			if identified:
				var short_label = str(item.label).left(15)
				draw_string(ThemeDB.fallback_font, point+Vector2(-35,40),short_label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("bff4e9"))

func _ready() -> void:
	var header = panel(Vector2(18,16),Vector2(350,76))
	var title = VBoxContainer.new()
	header.add_child(title)
	title.add_child(label("CHECKED CHAOS",25))
	title.add_child(label("AIRPORT BAGGAGE  /  GREYBOX 02",12,Color("e2c77d")))
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
	route_guide = label("READ TAG → MATCHING BAY\nTAG A  →  NW101\nTAG B  →  SE202\nNARCOTICS → SECURITY\nFRUIT / VEG / SEEDS → BIO\nPERSON AT RISK → SAFEGUARDING",14)
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
	var controls = panel(Vector2(18,675),Vector2(1244,31))
	controls.add_child(label("WASD / MOUSE  MOVE / LOOK    E  USE    1/2/3  HANDS/KEY/PLIERS    O  OPEN    I  CONTENTS    G  THROW    Q  DROP    K  DOG    TAB  UPGRADES    ESC  CURSOR",12))
	_build_airport_shop()
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
	chapter.position = Vector2(170,105)
	chapter.size = Vector2(950,65)
	chapter.add_theme_font_size_override("font_size",22)

func route_name(route: String) -> String:
	return {"gate_a":"FLIGHT A / NW101", "gate_b":"FLIGHT B / SE202", "gate_c":"FLIGHT C / INT303", "oversize":"OVERSIZE", "security":"SECURITY HOLD", "bio":"BIOSECURITY", "rescue":"SAFEGUARDING RESPONSE"}.get(route,route.to_upper())

func refresh_airport(sim, peer_id: int, bag_id: int, target_text: String, feedback_text: String) -> void:
	if sim.airport_level >= 2:
		route_guide.text = "EXPANDED AIRPORT ROUTING\nTAG A / B / C → MATCH FLIGHT\nLARGE LEGAL BAG → OVERSIZE\nNARCOTICS → SECURITY\nFRUIT / VEG / SEEDS → BIO\nPERSON AT RISK → SAFEGUARDING"
	var seconds = int(ceil(sim.time_left))
	stats.text = "$%d   REP %d   AIRPORT LV.%d\n%d HANDLED   %d:%02d   %s" % [sim.money,sim.reputation,sim.airport_level,sim.handled,seconds/60,seconds%60,"BELT RUNNING" if sim.belt_running else "INTAKE PAUSED"]
	var player: Dictionary = sim.players.get(peer_id,{"held_kind":"","held_id":-1,"tool":0})
	var held = str(player.held_kind).to_upper() if player.held_kind != "" else "EMPTY HANDS"
	inventory.text = "TOOL: %s\nCARRYING: %s\n%02d NARCOTICS / %02d BIO\n%02d RESCUES / %02d EVIDENCE" % [["HANDS","APPROVED KEY","LARGE PLIERS"][int(player.tool)],held,sim.narcotics,sim.organics,sim.rescues,sim.items_seized]
	if player.held_kind == "bag" and sim.bags.has(player.held_id):
		var mass = float(sim.bags[player.held_id].mass_kg)
		inventory.text += "\n%.0f kg / CARRY %d%%\n[G] THROW    [Q] GENTLE DROP" % [mass,int(sim.carry_speed(peer_id)*100)]
	if throw_demo_label != "":
		stats.text = throw_demo_label+" / REAL ENET PEER\n%d THROWS / %d MID-AIR CATCHES" % [sim.throws,sim.catches]
	prompt.text = target_text
	event_label.text = feedback_text if feedback_text != "" else sim.last_event
	dog_label.text = "DETECTION DOG\n%s\nAlerts %d  /  Training scans %d\n[K] Call  /  [E] Carry  /  [G] Put down" % ["WOOF! Inspect bag #%d" % sim.dog.alert_bag if sim.dog.bark_left > 0 else "An alert is a clue, not a conviction.",sim.dog.alerts,sim.dog_scan_count]
	case_label.text = "ARRIVAL MANIFEST\nLook at a bag to select it."
	contents_label.text = "BAG CONTENTS\nOpen an unlocked bag to inspect.\nLegal personal items are not contraband."
	xray_canvas.items = []
	xray_canvas.scanned = false
	xray_canvas.animal = false
	if sim.bags.has(bag_id):
		var bag: Dictionary = sim.bags[bag_id]
		case_label.text = "BAG #%02d  /  %s\n%s  /  %s\nFLIGHT %s\nLOCK: %s\n%s  /  %s" % [bag.id,["RED","BLUE","GREEN","YELLOW","PURPLE","TEAL"][bag.color],["CABIN","DUFFEL","BACKPACK","TRUNK"][bag.kind],["SMALL","MEDIUM","LARGE"][bag.size],["A / NW101","B / SE202","C / INT303"][bag.flight],str(bag.lock).to_upper(),"OPEN" if bag.opened else "CLOSED","X-RAY READY" if bag.scanned else "AWAITING SCANNER"]
		if bag.scanned:
			xray_canvas.items = bag.items
			xray_canvas.scanned = true
			xray_canvas.identified = bag.opened or bool(sim.upgrades.scanner)
		if bag.opened:
			var names: Array[String] = []
			for item in bag.items:
				names.append(str(item.label) + (" [REMOVED]" if item.location != "bag" else ""))
			contents_label.text = "INSPECTED CONTENTS\n" + "\n".join(names)
			if bag.category == "safeguarding":
				contents_label.text += "\nSUSPECTED TRAFFICKING\nCALL SAFEGUARDING RESPONSE."
	if sim.dog.location == "belt":
		case_label.text = "SCAN SUBJECT / DETECTION DOG\nFICTIONAL TRAINING SCANNER\nNON-IONIZING / NO ANIMAL HARM"
		xray_canvas.items = []
		xray_canvas.animal = true
		xray_canvas.scanned = bool(sim.dog.scanned)
		contents_label.text = "VERY GOOD BOY\nHarmless cartoon training scan.\nDog is safe and ready to return to work."
	xray_canvas.queue_redraw()
	xray_panel.visible = throw_demo_label == ""
	xray_panel.position = Vector2(330,215) if xray_large else Vector2(900,215)
	xray_panel.size = Vector2(550,290) if xray_large else Vector2(362,220)
	var titles = ["Scanner II: fast scan + item labels", "Dog training: wider / more reliable alerts", "Evidence bench: double seizure bonus", "Biosecurity lab: +$20 organic recovery", "Intake upgrade: larger / faster queue", "Terminal expansion: flight C + oversize"]
	for i in range(shop_buttons.size()):
		var installed = bool(sim.upgrades[UPGRADE_ORDER[i]])
		shop_buttons[i].text = "[%d] " % (i+1) + ("INSTALLED  /  " if installed else "$%d  /  " % COSTS[i]) + titles[i]
		shop_buttons[i].disabled = installed or sim.money < COSTS[i] or (UPGRADE_ORDER[i] == "terminal" and (sim.handled < 5 or sim.reputation < 5))
	shift_label.get_parent().visible = sim.shift_finished
	shift_label.text = "SHIFT COMPLETE\n%d HANDLED  /  %d RESCUED\nHOST: PRESS N FOR NEXT SHIFT" % [sim.handled,sim.rescues]
