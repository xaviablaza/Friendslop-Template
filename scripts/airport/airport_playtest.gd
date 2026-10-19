extends Node
## Opt-in fixture-loot walkthrough through normal controls and actual UI buttons.
## Money and upgrades are earned; timed locks and care requirements remain live.
var game
var elapsed = 0.0
var checks: Array[String] = []
var failed = false
var overview: Camera3D
var follow_dog = false

func _ready() -> void:
	game.chef.automated = true
	_run.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if follow_dog:
		game.chef.aim_target = game.sim.dog.position + Vector3(0,0.2,0)
	if elapsed > 300 and not failed: fail("Playtest exceeded safety timeout")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(condition: bool, message: String) -> void:
	if failed: return
	if not condition:
		fail(message)
		return
	checks.append(message)
	print("AIRPORT_PASS ", message)

func fail(message: String) -> void:
	if failed: return
	failed = true
	push_error("AIRPORT_FAIL " + message)
	_write_report(false, message)
	get_tree().quit(1)

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await wait(0.15)

func walk(at: Vector3, face: Vector3) -> void:
	game.chef.navigate(at, face)
	var start = elapsed
	while game.chef.walking and elapsed - start < 9:
		await get_tree().physics_frame
	check(game.chef.position.distance_to(at) < 0.25, "Walked to " + str(at))
	await wait(0.35)

func aim(at: Vector3) -> void:
	game.chef.aim_target = at
	game.chef.aiming = true
	await wait(0.5)

func chapter(text: String) -> void:
	game.hud.chapter.text = "AUTOMATED PLAYTEST / " + text

func acquire_scanned(id: int) -> void:
	await walk(Vector3(-1.2,0,1.5), AirportRoom.SCAN_CONSOLE)
	check(game.interaction_target().get("kind", "") == "console", "Operator targeted the intake controls")
	if not game.sim.belt_running: await key(KEY_E)
	var start = elapsed
	while (not game.sim.bags.has(id) or not game.sim.bags[id].scanned or game.sim.bags[id].t < 0.70) and elapsed - start < 35:
		await wait(0.15)
	check(game.sim.bags.has(id) and game.sim.bags[id].scanned, "Automatically arriving bag #%d passed the real scanner" % id)
	if game.sim.belt_running: await key(KEY_E)
	var bag: Dictionary = game.sim.bags[id]
	var point: Vector3 = game.sim.bag_position(bag)
	await walk(Vector3(3.5,0,1.5), point+Vector3(0,0.2,0))
	await walk(Vector3(3.5,0,-0.35), point+Vector3(0,0.2,0))
	check(game.interaction_target().get("id",-1) == id, "Look targeting selected bag #%d" % id)

func unlock_open(id: int, tool: Key) -> void:
	await key(tool)
	if not game.sim.bags[id].unlocked:
		await key(KEY_E)
		var challenge: Dictionary = game.sim.players[game.local_id].lock_game.duplicate(true)
		check(not challenge.is_empty() and not game.sim.bags[id].unlocked,"Started timed lock challenge #%d"%id)
		if challenge.is_empty(): return
		for value in challenge.sequence:
			await key(KEY_1+int(value))
	check(game.sim.bags[id].unlocked, "Normal sequence keys unlocked bag #%d" % id)
	await key(KEY_O)
	check(game.sim.bags[id].opened, "Opened bag #%d to reveal actual contents" % id)
	await key(KEY_1)

func take_contents(index: int) -> void:
	await key(KEY_I)
	check(game.hud.browser.visible,"I opened the real contents browser")
	var rows = game.hud.browser_rows.get_children()
	check(index>=0 and index<rows.size(),"Contents browser exposes the selected item index")
	if index<0 or index>=rows.size(): return
	rows[index].pressed.emit()
	await wait(0.15)
	await key(KEY_I)

func return_contents() -> void:
	await key(KEY_I)
	check(not game.hud.repack_button.disabled,"Browser offers return into the selected open bag")
	game.hud.repack_button.pressed.emit()
	await wait(0.15)
	await key(KEY_I)

func pick_bag(id: int) -> void:
	var at: Vector3 = game.sim.bag_position(game.sim.bags[id])
	await aim(at+Vector3(0,0.2,0))
	await key(KEY_1)
	await key(KEY_E)
	check(game.sim.players[game.local_id].held_kind == "bag" and game.sim.players[game.local_id].held_id == id, "Carried bag #%d" % id)

func put_table(id: int) -> void:
	await walk(Vector3(3.5,0,1.5), AirportRoom.TABLE_POINT)
	await walk(Vector3(2,0,1.5), AirportRoom.TABLE_POINT)
	check(game.interaction_target().get("kind", "") == "table", "Targeted inspection desk while carrying baggage")
	await key(KEY_E)
	check(game.sim.bags[id].location == "table", "Placed bag #%d on inspection desk" % id)

func route_bag(id: int, route: String) -> void:
	var bay: Vector3 = AirportRoom.ROUTES[route]
	await walk(Vector3(game.chef.position.x,0,2.0), bay)
	await walk(Vector3(bay.x,0,2.0), bay)
	await walk(Vector3(bay.x,0,3.15), bay)
	check(game.interaction_target().get("route", "") == route, "Targeted " + route)
	var before = int(game.sim.handled)
	await key(KEY_E)
	check(game.sim.handled == before + 1 and game.sim.bags[id].location == "sorted", "Correctly resolved bag #%d through %s" % [id,route])

func _run() -> void:
	chapter("01 / STRAIGHT INTAKE → X-RAY → INSPECTION")
	overview = Camera3D.new()
	overview.position = Vector3(11,10,12)
	overview.fov = 67
	game.add_child(overview)
	overview.look_at(Vector3(0,0.8,0.5))
	overview.current = true
	await wait(3)
	await screenshot("overview")
	game.chef.camera.current = true
	await acquire_scanned(1)
	await key(KEY_F)
	await wait(1)
	await screenshot("xray")
	await key(KEY_F)
	chapter("02 / APPROVED KEY + LEGAL PERSONAL ITEMS")
	await unlock_open(1,KEY_2)
	check(game.sim.bags[1].category == "legal", "Dildo prop is legal, not contraband")
	await pick_bag(1)
	await put_table(1)
	await take_contents(0)
	check(game.sim.players[game.local_id].held_kind == "item", "Picked up an individual item from an opened bag")
	await key(KEY_Q)
	check(game.sim.players[game.local_id].held_kind == "", "Dropped an individual item onto the floor")
	await aim(AirportRoom.TABLE_POINT+Vector3(0,0.2,0))
	await take_contents(1)
	check(game.sim.players[game.local_id].held_kind == "item", "Carried the second legal personal item")
	await screenshot("legal-item")
	await return_contents()
	check(game.sim.players[game.local_id].held_kind == "", "Returned carried contents to the bag")
	await pick_bag(1)
	await route_bag(1,"gate_a")
	chapter("03 / FOREIGN LOCK → PLIERS → NARCOTICS SEIZURE")
	await acquire_scanned(2)
	await key(KEY_2)
	await key(KEY_E)
	check(not game.sim.bags[2].unlocked, "Approved-lock key could not open a non-approved lock")
	await unlock_open(2,KEY_3)
	check(game.sim.bags[2].lock == "cut", "Large pliers cut the non-approved lock")
	check(game.sim.dog.hunger>15.0 and game.sim.dog.thirst>15.0, "Detection dog has real accumulating care needs")
	await screenshot("contraband")
	await pick_bag(2)
	await put_table(2)
	await take_contents(0)
	check(game.sim.players[game.local_id].held_kind == "item", "Removed the narcotics evidence item")
	await walk(Vector3(4.6,0,1.45), AirportRoom.EVIDENCE_POINT)
	await key(KEY_E)
	check(game.sim.items_seized == 1, "Deposited narcotics into secure evidence for a real bonus")
	await walk(Vector3(2,0,1.5), AirportRoom.TABLE_POINT+Vector3(0,0.2,0))
	await pick_bag(2)
	check(game.sim.bags[2].category=="legal", "Seizing the restricted item reclassified remaining belongings")
	await route_bag(2,"gate_b")
	chapter("04 / CARRY THE DOG THROUGH A HARMLESS TRAINING SCAN")
	await walk(Vector3(0,0,1.4),Vector3(0,0.3,1.4))
	await key(KEY_K)
	await wait(1)
	await aim(game.sim.dog.position+Vector3(0,0.2,0))
	check(game.interaction_target().get("kind", "") == "dog", "Targeted the dog after calling it over")
	await key(KEY_E)
	check(game.sim.players[game.local_id].held_kind == "dog", "Picked up the detection dog")
	await walk(Vector3(-1.2,0,1.5),AirportRoom.SCAN_CONSOLE)
	await key(KEY_E)
	check(game.sim.dog.location == "belt", "Put dog onto the scanner conveyor")
	if not game.sim.belt_running: await key(KEY_E)
	await walk(Vector3(0.5,0,1.5),game.sim.dog.position)
	await walk(Vector3(0.5,0,-0.35),game.sim.dog.position)
	follow_dog = true
	var start = elapsed
	while game.sim.dog_scan_count < 1 and elapsed-start < 8: await wait(0.1)
	check(game.sim.dog_scan_count == 1, "Training scanner identified VERY GOOD BOY without harm")
	await wait(1.0)
	check(game.hud.xray_canvas.animal and game.hud.xray_canvas.scanned, "Live scanner showed the dog's actual training silhouette")
	await screenshot("dog-scanner")
	await wait(1.0)
	follow_dog = false
	chapter("05 / BIOSECURITY: FRUIT, VEGETABLES, SEEDS")
	await acquire_scanned(3)
	await unlock_open(3,KEY_1)
	var kinds = game.sim.bags[3].items.map(func(item): return item.kind)
	check(kinds.has("fruit") and kinds.has("vegetable") and kinds.has("seeds"), "Organic case contains fruit, vegetables and seeds")
	await screenshot("organics")
	await pick_bag(3)
	await route_bag(3,"bio")
	check(game.sim.organics == 1, "Caught illegal organics and earned biosecurity bonus")
	chapter("06 / PET CARRIER: FOOD, WATER, ANIMAL CARE")
	await acquire_scanned(4)
	await unlock_open(4,KEY_3)
	check(game.sim.bags[4].category == "pet" and game.sim.bags[4].carrier, "Opened a ventilated carrier containing a real pet")
	await screenshot("pet-carrier")
	await walk(Vector3(3.5,0,1.5),AirportRoom.DOG_CARE_POINT)
	await walk(Vector3(-7.5,0,1.5),AirportRoom.DOG_CARE_POINT)
	await key(KEY_E)
	check(game.hud.station_panel.visible,"Opened real dog-care supply menu")
	var food_before: int = game.sim.players[game.local_id].food
	var water_before: int = game.sim.players[game.local_id].water
	for row in game.hud.station_rows.get_children():
		if row is Button and row.text in ["Collect food", "Collect water"]:
			row.pressed.emit()
	await key(KEY_ESCAPE)
	check(game.sim.players[game.local_id].food==food_before+1 and game.sim.players[game.local_id].water==water_before+1,"Collected finite food and water supplies")
	await walk(Vector3(3.5,0,1.5),game.sim.bag_position(game.sim.bags[4]))
	await walk(Vector3(3.5,0,-0.35),game.sim.bag_position(game.sim.bags[4]))
	await key(KEY_I)
	check(game.hud.pet_button.visible,"Contents browser exposes carrier care")
	game.hud.pet_button.pressed.emit()
	await wait(0.15)
	await key(KEY_I)
	check(game.sim.bags[4].pet.fed and game.sim.players[game.local_id].food==food_before and game.sim.players[game.local_id].water==water_before,"Pet care consumed carried supplies")
	await pick_bag(4)
	await route_bag(4,"rescue")
	check(game.sim.rescues == 1, "Fed and watered pet reached animal care")
	chapter("07 / LEGAL VIBRATOR ≠ PROHIBITED ITEM")
	await acquire_scanned(5)
	await unlock_open(5,KEY_2)
	check(game.sim.bags[5].category == "legal", "Vibrator/electronics case remained legal")
	await screenshot("vibrator")
	await pick_bag(5)
	await route_bag(5,"gate_b")
	check(game.sim.handled == 5 and game.sim.money >= 200, "Five resolved cases and contract grants funded airport development")
	chapter("08 / EARNED AIRPORT EXPANSION + SCANNER + DOG TRAINING")
	await walk(Vector3(-3,0,1.8),AirportRoom.AIRPORT_SHOP_POINT)
	await key(KEY_E)
	check(game.hud.shop.visible, "Opened airport development terminal")
	await key(KEY_6)
	await key(KEY_1)
	await key(KEY_2)
	check(game.sim.airport_level == 2 and game.sim.upgrades.terminal == 1, "Purchased terminal expansion with earned funds and reputation")
	check(game.sim.upgrades.scanner == 1 and game.sim.upgrades.kennel == 1, "Installed faster readable X-ray and dog training")
	await screenshot("upgrades")
	await key(KEY_TAB)
	chapter("09 / NEW INTERNATIONAL CONTRACT / THIRD ROUTE")
	# Intake was paused for inspection, so expansion changes the next arrival.
	await walk(Vector3(-1.2,0,1.5),AirportRoom.SCAN_CONSOLE)
	if not game.sim.belt_running: await key(KEY_E)
	var international = -1
	start = elapsed
	while international < 0 and elapsed-start < 35:
		for bag in game.sim.bags.values():
			if bag.flight == 2 and bag.scanned and bag.t >= 0.60 and bag.location == "belt": international = int(bag.id)
		await wait(0.1)
	check(international > 0, "Terminal expansion generated an actual new flight-C arrival")
	if game.sim.belt_running: await key(KEY_E)
	if international > 0:
		var bag: Dictionary = game.sim.bags[international]
		var at: Vector3 = game.sim.bag_position(bag)
		await walk(Vector3(3.5,0,1.5),at+Vector3(0,0.2,0))
		await walk(Vector3(3.5,0,-0.35),at+Vector3(0,0.2,0))
		await unlock_open(international,KEY_2 if bag.lock == "approved" else KEY_1)
		await pick_bag(international)
		await route_bag(international,"gate_c")
	check(game.sim.handled >= 6, "Used the unlocked international bay, not only an upgrade label")
	chapter("ALL REQUESTED MECHANICS / PLAYTEST PASSED")
	overview.current = true
	await wait(2)
	await screenshot("expanded-airport")
	_write_report(true,"Full airport gameplay tour")
	get_tree().quit(0)

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	get_viewport().get_texture().get_image().save_png("res://artifacts/airport-"+name+".png")

func _write_report(passed: bool, message: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file = FileAccess.open("res://artifacts/airport-playtest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"message":message,"automated_inputs":true,"elapsed_seconds":elapsed,"checks":checks,"money":game.sim.money,"handled":game.sim.handled,"rescues":game.sim.rescues,"organics":game.sim.organics,"narcotics":game.sim.narcotics,"dog_scans":game.sim.dog_scan_count,"upgrades":game.sim.upgrades,"airport_level":game.sim.airport_level},"\t"))
	print("AIRPORT_RESULT passed=",passed," checks=",checks.size()," handled=",game.sim.handled)
