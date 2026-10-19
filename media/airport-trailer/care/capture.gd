extends SceneTree
## Standalone automated fixture staging; normal keys/UI and live authoritative rules.
const OUT = "res://artifacts/trailer-v2/care/"
var game
var cam: Camera3D
var checks: Array = []
var scenes: Array = []
var active: Dictionary = {}
var start_frame = 0
var failed = false
var money_ledger: Array = []
var scent_results: Array = []
var disclosures = ["Automated single-player inputs, HEAD 663cb3a; scene staging teleports operator/camera and positions catalogue fixture bags between takes.", "Cat/rabbit and two organic + one legal reward fixtures use known catalogue objects and unlocked locks. Each fixture is staged before the real scanner and scanned through normal intake controls before inspection. Rewards, contracts and purchases are live, not pre-awarded.", "Initial food/water explicitly empty to exercise shortage. Currency, rewards, reputation, training XP and purchases are never seeded.", "Dog starts at the actual care station with default live needs; follow/patrol/throw/scanner and care all run the real simulation and interaction gateway.", "Scent scene uses known legal/restricted fixtures; actual live RNG is not replaced, selected or rerolled to manufacture an outcome.", "MovieMaker real OpenGL rendering, 1280x720 at 24fps; silent source footage; no chapter/title overlays."]

func _initialize():
	_run.call_deferred()

func frames(n: int):
	for i in range(n): await process_frame

func hold(seconds: float):
	await frames(int(ceil(seconds*24)))

func now() -> float:
	return float(Engine.get_process_frames())/24.0

func check(ok: bool, text: String):
	checks.append({"ok":ok,"text":text,"time":now()})
	print("CARE_CHECK ",ok," ",text)
	if not ok:
		failed = true

func key(code: int):
	var e = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await frames(1)
	e = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	await frames(3)

func move(at: Vector3, look: Vector3):
	game._close_modals()
	game.chef.position = at
	game.chef.velocity = Vector3.ZERO
	game.chef.walking = false
	game.chef.aiming = false
	game.chef.face(look)
	game.poses[1] = {"position":at,"yaw":game.chef.rotation.y}
	game.sim.set_player_position(1,at+Vector3(0,0.3,0))
	game.chef.camera.current = true
	await frames(3)

func view(at: Vector3, look: Vector3, fov: float = 55):
	cam.position = at
	cam.fov = fov
	cam.look_at(look)
	cam.current = true

func begin(name: String, disclosure: String = ""):
	finish_scene()
	active = {"name":name,"start":now(),"disclosure":disclosure,"crop_suggestion":"Full 1280x720 preserves live HUD; center action can be cropped editorially."}
	print("CARE_SCENE ",name," at ",now())

func finish_scene():
	if not active.is_empty():
		active.end = now()
		scenes.append(active)
		active = {}

func shot(name: String):
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func station(text: String):
	var found = false
	for b in game.hud.station_rows.get_children():
		if b is Button and b.text == text:
			b.pressed.emit()
			found = true
			break
	check(found,"Actual station button: "+text)
	await frames(3)

func fixture(id: int, kind: String, at: Vector3):
	var bag: Dictionary = game.sim._random_bag(id)
	var item = load("res://scripts/airport/airport_catalog.gd").instantiate(load("res://scripts/airport/airport_catalog.gd").entry(kind),game.sim.rng,1000+id,true)
	bag.items = [item]
	bag.location = "floor"
	bag.position = at
	bag.lock = "none"
	bag.unlocked = true
	bag.opened = false
	bag.inspected = false
	bag.scanned = false
	bag.kind = 0
	bag.size = 1
	bag.flight = 0
	bag.carrier = kind in ["pet_cat","pet_rabbit"]
	bag.pet = {"species":"cat" if kind == "pet_cat" else "rabbit","hunger":65.0,"thirst":60.0,"fed":false} if bag.carrier else {}
	game.sim.bags[id] = bag
	game.sim.ensure_bag_physics(bag)
	return bag

func on_table(id: int):
	var b: Dictionary = game.sim.bags[id]
	if not b.scanned:
		b.location = "belt"
		b.t = 0.43
		await move(Vector3(-1.2,0.03,1.5),game.room.SCAN_CONSOLE)
		await key(KEY_E)
		view(Vector3(3.8,3.8,3.8),Vector3(-0.5,1.1,-2),54)
		await hold(2.0)
		game.chef.camera.current = true
		await key(KEY_E)
		check(b.scanned and not game.sim.belt_running,"Real conveyor scanner processes staged bag #"+str(id))
	b.location = "table"
	b.position = Vector3(2,1.15,0)
	game.selected_id = id
	await move(Vector3(2,0.03,1.25),Vector3(2,1.48,0))
	await frames(2)
	check(game.interaction_target().get("id",-1)==id,"Target actual bag #"+str(id))

func feed_browser(id: int):
	await key(KEY_I)
	check(game.hud.browser.visible and game.hud.pet_button.visible,"Real carrier care browser visible #"+str(id))
	await hold(1)
	game.hud.pet_button.pressed.emit()
	await frames(3)
	await hold(1.5)
	await key(KEY_I)

func handoff(id: int, route: String):
	await key(KEY_1)
	await key(KEY_E)
	check(game.sim.players[1].held_kind=="bag" and game.sim.players[1].held_id==id,"E picked up bag #"+str(id))
	var bay: Vector3 = game.room.ROUTES[route]
	await move(Vector3(bay.x,0.03,3.0),bay)
	var prior = game.sim.money
	await hold(0.6)
	check(game.interaction_target().get("route","")==route,"Actual route target "+route)
	await key(KEY_E)
	check(game.sim.bags[id].location=="sorted","Real handoff #"+str(id)+" via "+route)
	money_ledger.append({"bag":id,"route":route,"before":prior,"after":game.sim.money,"delta":game.sim.money-prior,"time":now()})
	await hold(2.0)

func _run():
	await frames(1)
	root.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	game = load("res://scenes/level/airport/AirportBaggage.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.chef.automated = true
	game.sim.belt_running = false
	game.sim._arrival_left = 1000.0
	game.sim.bags.clear()
	game.sim.players[1].food = 0
	game.sim.players[1].water = 0
	game.sim.dog.position = Vector3(-7.5,0.3,1.0)
	game.sim.dog_goal = game.sim.dog.position
	game.sim.dog.mode = "stay"
	cam = Camera3D.new()
	game.add_child(cam)
	fixture(101,"pet_cat",Vector3(2,1.15,0))
	fixture(102,"pet_rabbit",Vector3(6,0.04,1))
	fixture(103,"fruit",Vector3(7,0.04,1))
	fixture(104,"seeds",Vector3(7,0.04,2))
	fixture(105,"clothes",Vector3(7,0.04,3))
	check(game.sim.money==0 and game.sim.reputation==0,"No currency or reputation seeded")
	begin("cat_closed_open_and_empty_supplies","Known catalogue cat carrier staged on real inspection desk; empty carried portions fixture.")
	await on_table(101)
	await hold(2.5)
	await shot("01-cat-closed")
	await key(KEY_O)
	check(game.sim.bags[101].opened,"O opened visible cat carrier")
	await hold(2.5)
	await shot("02-cat-open")
	await feed_browser(101)
	check(not game.sim.bags[101].pet.fed and "requires" in game.sim.last_event,"Empty supplies rejected pet care")
	await shot("03-shortage")
	begin("shared_care_station_finite_portions")
	await move(Vector3(-6.5,0.03,0.5),game.room.DOG_CARE_POINT)
	await key(KEY_E)
	check(game.hud.station_panel.visible,"E opened actual shared dog/pet care station")
	await hold(1)
	for i in range(3):
		await station("Collect food")
		await station("Collect water")
	await station("Collect food")
	check(game.sim.players[1].food==3 and game.sim.players[1].water==3,"Carried food/water capped at three portions")
	await hold(2.5)
	await shot("04-shared-care")
	await key(KEY_ESCAPE)
	begin("cat_food_water_and_animal_care_handoff")
	await on_table(101)
	await feed_browser(101)
	check(game.sim.bags[101].pet.fed and game.sim.players[1].food==2 and game.sim.players[1].water==2,"Cat care consumes one shared food and water portion")
	await hold(1)
	await handoff(101,"rescue")
	await shot("05-cat-handoff")
	begin("rabbit_closed_open_food_water_handoff","Known catalogue rabbit fixture; real care and reward.")
	await on_table(102)
	await hold(2)
	await shot("06-rabbit-closed")
	await key(KEY_O)
	await hold(2)
	await shot("07-rabbit-open")
	await feed_browser(102)
	check(game.sim.bags[102].pet.fed and game.sim.players[1].food==1 and game.sim.players[1].water==1,"Rabbit care consumes same finite supplies")
	await handoff(102,"rescue")
	begin("kennel_gated_before_training_scan")
	await move(Vector3(-3,0.03,1.8),game.room.AIRPORT_SHOP_POINT)
	await key(KEY_E)
	await hold(1)
	check(game.hud.shop_buttons[1].disabled and game.sim.money>=35,"Kennel disabled despite earned funds until a dog scan")
	await key(KEY_2)
	check(game.sim.upgrades.kennel==0 and "requires" in game.sim.last_event,"Real kennel action rejected before dog training scan")
	await hold(2.5)
	await shot("08-kennel-gated")
	await key(KEY_TAB)
	begin("dog_live_needs_feed_water_and_rest")
	await move(Vector3(-6.5,0.03,0.5),game.room.DOG_CARE_POINT)
	var hunger_before = game.sim.dog.hunger
	var thirst_before = game.sim.dog.thirst
	await hold(2)
	check(game.sim.dog.hunger>hunger_before and game.sim.dog.thirst>thirst_before,"Live dog hunger and thirst rise during gameplay")
	await key(KEY_E)
	await station("Feed detection dog")
	await hold(1.5)
	await station("Water detection dog")
	await hold(1.5)
	await station("Rest detection dog")
	check(game.sim.players[1].food==0 and game.sim.players[1].water==0 and game.sim.dog.hunger<2 and game.sim.dog.thirst<2 and game.sim.dog.rest_left>0,"Dog consumed final portions, lowered real needs and started actual rest")
	await hold(2.5)
	await shot("09-dog-rest")
	await key(KEY_ESCAPE)
	begin("dog_autonomous_follow_and_patrol","Operator restaged into open lane; dog walks autonomously from care station with live collision sweep.")
	await hold(2)
	await key(KEY_P)
	check(game.sim.dog.mode=="follow","P selects autonomous follow")
	var dog_from: Vector3 = game.sim.dog.position
	await move(Vector3(-3.5,0.03,2.2),Vector3(-7.5,0.5,1))
	view(Vector3(-2,4.5,5.5),Vector3(-5.3,0.3,1.8),57)
	await hold(5)
	check(game.sim.dog.position.distance_to(dog_from)>2,"Dog autonomously followed through world")
	await shot("10-dog-follow")
	await move(Vector3(game.sim.dog.position.x,0.03,game.sim.dog.position.z+1.2),game.sim.dog.position)
	await key(KEY_P)
	check(game.sim.dog.mode=="patrol","P selects autonomous patrol")
	var patrol_from: Vector3 = game.sim.dog.position
	view(Vector3(0,5.5,7),Vector3(-1.8,0.3,1.8),62)
	await hold(5)
	check(game.sim.dog.position.distance_to(patrol_from)>1,"Dog autonomously patrols actual lane")
	await shot("11-dog-patrol")
	begin("dog_carry_and_harmless_capped_G_throw")
	await move(Vector3(game.sim.dog.position.x,0.03,game.sim.dog.position.z+1.0),game.sim.dog.position+Vector3(0,0.2,0))
	await key(KEY_P)
	await key(KEY_E)
	check(game.sim.players[1].held_kind=="dog","Actual E picks up detection dog")
	await hold(2)
	await move(Vector3(-2,0.03,2.0),Vector3(2,1.5,2.0))
	view(Vector3(0,3.5,6),Vector3(0,0.9,2),55)
	await key(KEY_G)
	check(game.sim.dog.location=="airborne","G produced actual dog flight")
	check((game.sim.dog.velocity as Vector3).length()<6,"Dog throw uses gentle capped velocity")
	await shot("12-dog-airborne")
	await hold(2.5)
	check(game.sim.dog.location=="floor","Gentle dog flight lands safely")
	begin("real_dog_scanner_crossing_LIVE_animal_Xray_XP")
	await move(Vector3(game.sim.dog.position.x,0.03,game.sim.dog.position.z+0.9),game.sim.dog.position+Vector3(0,0.2,0))
	await key(KEY_E)
	check(game.sim.players[1].held_kind=="dog","Picked up dog for actual training belt")
	await move(Vector3(-1.2,0.03,1.5),game.room.SCAN_CONSOLE)
	await key(KEY_E)
	check(game.sim.dog.location=="belt","E puts actual dog onto conveyor")
	await key(KEY_E)
	check(game.sim.belt_running,"E resumes actual conveyor")
	var xp_before = game.sim.dog.xp
	view(Vector3(3.8,3.8,3.8),Vector3(-0.4,1.1,-2),54)
	await hold(2)
	check(game.sim.dog_scan_count==1 and game.sim.dog.xp==xp_before+10,"Actual scanner crossing awards +10 dog XP")
	check(game.hud.xray_canvas.animal and game.hud.xray_canvas.scanned,"LIVE X-ray displays real scanned animal")
	await shot("13-dog-live-scan")
	await hold(2.5)
	await move(Vector3(-1.2,0.03,1.5),game.room.SCAN_CONSOLE)
	await key(KEY_E)
	check(not game.sim.belt_running,"Paused conveyor with trained dog still on it")
	view(Vector3(3.8,3.8,3.8),Vector3(0,1.1,-2),54)
	await hold(2)
	begin("earn_remaining_funds_through_real_routes","Three known catalogue baggage fixtures staged in reach, ordinary O/E input and route gateway; no money injection.")
	for id in [103,104,105]:
		await on_table(id)
		await key(KEY_O)
		await hold(0.7)
		await handoff(id,"gate_a" if id==105 else "bio")
	check(game.sim.handled==5 and game.sim.reputation==5 and game.sim.money>=200,"Five real rewarded handoffs fund all three upgrades")
	begin("earned_scanner_kennel_terminal_purchases")
	await move(Vector3(-3,0.03,1.8),game.room.AIRPORT_SHOP_POINT)
	await key(KEY_E)
	await hold(2)
	var cash_before = game.sim.money
	await key(KEY_1)
	await hold(1)
	await key(KEY_2)
	await hold(1)
	await key(KEY_6)
	check(game.sim.upgrades.scanner==1 and game.sim.upgrades.kennel==1 and game.sim.upgrades.terminal==1 and game.sim.money==cash_before-200,"Earned $200 purchases scanner, trained kennel and terminal")
	check(game.sim.airport_level==2,"Terminal unlocks actual airport level 2")
	await hold(2.5)
	await shot("14-earned-upgrades")
	await key(KEY_TAB)
	begin("new_international_route_used","Next arrival scheduled immediately after upgrade to avoid dead time; normal catalogue arrival, scanner, open and route.")
	game.sim.set_fixture_mode(true)
	game.sim._arrival_left = 0.0
	await move(Vector3(-1.2,0.03,1.5),game.room.SCAN_CONSOLE)
	await key(KEY_E)
	await hold(9.6)
	await key(KEY_E)
	var new_id = -1
	for b in game.sim.bags.values():
		if b.id<100 and b.flight==2: new_id = b.id
	check(new_id>0,"Terminal generates actual flight C arrival")
	if new_id>0:
		var b: Dictionary = game.sim.bags[new_id]
		check(b.scanned,"New arrival crosses real upgraded scanner")
		# Operator staged beside actual belt arrival; no bag relocation.
		var p: Vector3 = game.sim.bag_position(b)
		await move(Vector3(p.x,0.03,-0.35),p+Vector3(0,0.2,0))
		game.selected_id = new_id
		await key(KEY_2)
		await key(KEY_E)
		var challenge: Dictionary = game.sim.players[1].lock_game.duplicate(true)
		for v in challenge.get("sequence",[]): await key(KEY_1+int(v))
		await key(KEY_O)
		await hold(1)
		await handoff(new_id,"gate_c")
	view(Vector3(7,6,8),Vector3(1.5,0.8,1),65)
	await hold(2.5)
	await shot("15-new-route")
	begin("probabilistic_scent_clues_not_verdicts","Eight known catalogue scent fixtures (four legal, four organic) and dog staged in clear lane. One ordinary live RNG scent pulse is observed; no alert flags or RNG rolls are assigned.")
	game.sim.dog.location = "floor"
	game.sim.dog.position = Vector3(0,0.3,1.5)
	game.sim.dog_goal = game.sim.dog.position
	game.sim.dog.mode = "stay"
	var scent_ids: Array = []
	for i in range(8):
		var id = 201+i
		fixture(id,"clothes" if i<4 else "fruit",Vector3((float(i%4)-1.5)*0.8,0.04,0.65 if i<4 else 2.4))
		scent_ids.append(id)
	await move(Vector3(2.4,0.03,1.6),Vector3(0,0.5,1.5))
	view(Vector3(2.5,4.5,5.5),Vector3(0,0.3,1.5),55)
	await hold(float(game.sim.dog.scent_left)+0.15)
	var correct_alerts = 0
	var missed = 0
	var false_positives = 0
	var false_id = -1
	for id in scent_ids:
		var b: Dictionary = game.sim.bags[id]
		var truth: bool = b.category!="legal"
		var result: String = "correct_alert" if truth and b.dog_alert else ("missed" if truth else ("false_positive" if b.dog_alert else "correct_silence"))
		scent_results.append({"bag":id,"truth":b.category,"alert":b.dog_alert,"result":result})
		if result=="correct_alert": correct_alerts+=1
		if result=="missed": missed+=1
		if result=="false_positive":
			false_positives+=1
			false_id=id
	print("CARE_SCENT ",JSON.stringify(scent_results))
	check(scent_results.size()==8,"Observed eight actual probabilistic scent decisions; alerts are clues not verdicts")
	await shot("16-real-scent-outcomes")
	await hold(2.5)
	if false_id>0:
		var b: Dictionary = game.sim.bags[false_id]
		var p: Vector3 = b.position
		await move(Vector3(p.x,0.03,p.z+0.8),p+Vector3(0,0.2,0))
		game.selected_id = false_id
		await key(KEY_O)
		check(b.opened and b.category=="legal" and b.dog_alert,"Real false-positive alert resolves to legal contents on inspection")
		await hold(2.5)
		await shot("17-legal-false-positive")
	finish_scene()
	_write()
	quit(1 if failed else 0)

func _write():
	var report = {"passed":not failed,"checks":checks,"money_ledger":money_ledger,"money":game.sim.money,"handled":game.sim.handled,"rescues":game.sim.rescues,"dog_scans":game.sim.dog_scan_count,"dog_xp":game.sim.dog.xp,"upgrades":game.sim.upgrades,"disclosures":disclosures,"scent_results":scent_results,"duration_seconds":now()}
	var f = FileAccess.open(OUT+"assertions.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	var t = FileAccess.open(OUT+"timeline.json",FileAccess.WRITE)
	t.store_string(JSON.stringify({"fps":24,"scenes":scenes,"disclosures":disclosures},"\t"))
	print("CARE_RESULT ",not failed," duration ",now()," checks ",checks.size())
