extends SceneTree
# Scripted scenarios; real loaded game, input events and UI signals.
const OUT = "/home/administrator/Friendslop-Template-airport-baggage/artifacts/trailer-v2/inspection/"
var game
var catalog
var checks: Array = []
var shots: Array = []
var fixtures: Array = []
var start_frame = 0
var current: Dictionary = {}
var rendered = false
var failed = false
var serial = 10000

func _initialize():
	_run.call_deferred()
func wait_s(seconds: float):
	for i in range(roundi(seconds * 24)): await process_frame
func refresh():
	game._process(0.0)
func key(code: int):
	var e = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame
	refresh()
func check(ok: bool, text: String, data = {}):
	checks.append({"passed":ok,"assertion":text,"data":data,"frame":Engine.get_process_frames()-start_frame})
	print("INSPECTION_CHECK ",ok," ",text," ",data)
	if not ok: failed = true
func shot(id: String, result: String, crop: String = "Full native frame; real central UI and right manifest"):
	if not current.is_empty():
		current.end_frame = Engine.get_process_frames()-start_frame
		current.end = float(current.end_frame)/24.0
		shots.append(current)
	current = {"id":id,"start_frame":Engine.get_process_frames()-start_frame,"start":float(Engine.get_process_frames()-start_frame)/24.0,"visible_result":result,"crop_suggestion":crop}
	checkpoint()
func checkpoint():
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"assertion_count":checks.size(),"checks":checks,"automated":true,"scripted_scenarios":true},"\t"))
	FileAccess.open(OUT+"timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":24,"native_size":[1280,720],"shots":shots,"active_shot":current},"\t"))
	FileAccess.open(OUT+"fixtures.json",FileAccess.WRITE).store_string(JSON.stringify(fixtures,"\t"))
func snap(name: String):
	if rendered:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+name+".png")
func move(at: Vector3, look: Vector3):
	game.chef.position = at
	game.chef.velocity = Vector3.ZERO
	game.chef.face(look)
	game.poses[1] = {"position":at,"yaw":game.chef.rotation.y}
	game.sim.set_player_position(1,at+Vector3(0,0.3,0))
	refresh()
func select_bag(id: int):
	var b: Dictionary = game.sim.bags[id]
	move(Vector3(b.position.x,0.03,b.position.z+1.35),b.position+Vector3(0,0.2,0))
	game.selected_id = id
	refresh()
func fixture(id: int, kinds: Array, at: Vector3, lock_type: String = "none", legal_lookalike: bool = false) -> Dictionary:
	var b: Dictionary = game.sim._random_bag(id)
	b.items.clear()
	for kind in kinds:
		serial += 1
		var item: Dictionary = catalog.instantiate(catalog.entry(kind),game.sim.rng,serial,not legal_lookalike)
		if legal_lookalike and kind != "clothes":
			while item.category != "legal": item = catalog.instantiate(catalog.entry(kind),game.sim.rng,serial,false)
		b.items.append(item)
	b.location = "table"
	b.position = at
	b.t = 0.6
	b.scanned = true
	b.lock = lock_type
	b.unlocked = lock_type == "none"
	b.opened = false
	b.inspected = false
	b.carrier = false
	b.pet = {}
	b.shell_mass_kg = 3.0
	b.size = 1
	b.kind = id % 3
	game.sim.ensure_bag_physics(b)
	game.sim.bags[id] = b
	fixtures.append({"type":"catalogue_case","id":id,"kinds":kinds,"at":str(at),"lock":lock_type,"scanned":true,"shell_mass_kg":3.0,"size":1,"kind":id%3,"legal_lookalike_rejection_sampling":legal_lookalike,"items":b.items.duplicate(true),"note":"New _random_bag fixture; replaced contents with actual catalogue instantiate(certain=true), except legal lookalike sampled normally until cleared; staged table/scanned; outcomes via real gateway."})
	refresh()
	return b
func browser():
	await key(KEY_I)
	check(game.hud.browser.visible,"Real item browser opened by I")
func choose(index: int):
	game.hud.browser_rows.get_child(index).pressed.emit()
	refresh()
	await process_frame
func station_action(action: String):
	for child in game.hud.station_rows.get_children():
		if child is Button and child.pressed.get_connections().size() > 0:
			var a: Array = child.pressed.get_connections()[0].callable.get_bound_arguments()
			if a.size() == 3 and a[0] == action:
				child.pressed.emit()
				refresh()
				await process_frame
				return
	check(false,"Station button found: "+action)
func solve():
	var p: Dictionary = game.sim.players[1]
	check(not p.lock_game.is_empty(),"Timed challenge exists before normal numeric inputs")
	if p.lock_game.is_empty(): return
	var seq: Array = p.lock_game.sequence.duplicate()
	for value in seq:
		await key(KEY_1+int(value))
		await wait_s(0.35)
func archive(id: int):
	game.sim.bags[id].location = "sorted"
	fixtures.append({"type":"staging_cleanup","id":id,"location":"sorted","note":"NOT routed; excluded from earnings and handled count"})
	refresh()
func _run():
	await process_frame
	rendered = DisplayServer.get_name() != "headless"
	root.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	catalog = load("res://scripts/airport/airport_catalog.gd")
	game = load("res://scenes/level/airport/AirportBaggage.tscn").instantiate()
	root.add_child(game)
	await wait_s(0.25)
	game.chef.automated = true
	game.chef.set_physics_process(false)
	game.sim = load("res://scripts/airport/airport_simulation.gd").new()
	game.sim.set_seed(20261019)
	game.sim.add_player(1)
	game.sim.collision_query = game._bag_collision
	game.sim.dog.mode = "stay"
	game.sim.dog.position = Vector3(-8,0.3,0.5)
	game.sim.dog_goal = game.sim.dog.position
	game.hud.chapter.text = ""
	game.hud.chapter.hide()
	game.hud.dog_label.get_parent().hide()
	# Remove only static branding signs; retain functional station text/HUD.
	for node in game.room.get_children():
		if node is Label3D and ("CHECKED CHAOS" in node.text or "AIRPORT BAGGAGE /" in node.text): node.hide()
	fixtures.append({"type":"capture_setup","seed":20261019,"fixture_mode":false,"camera":"scripted position/aim cuts; controller physics disabled to hold compositions","money_seeded":false,"hidden":"static branding, chapter label, irrelevant dog HUD only","dog":"staged stay away from inspection desk"})
	start_frame = Engine.get_process_frames()
	shot("random_arrivals","Ordinary seeded random arrivals enter the actual moving intake; distinct bag manifests and true computed masses.","Full width; belt action center and manifest upper-right")
	move(Vector3(-5.5,0.03,0),Vector3(-7,1.4,-2))
	await wait_s(3)
	game.selected_id = 1
	await wait_s(3)
	await snap("01-random-intake")
	await wait_s(5)
	game.selected_id = 2
	refresh()
	await wait_s(2)
	check(game.sim.bags.size() >= 2 and not game.sim.fixture_mode,"Real random intake generated multiple arrivals",{"masses":game.sim.bags.values().map(func(b): return b.mass_kg)})
	for id in game.sim.bags.keys(): archive(id)
	game.sim.belt_running = false
	var p: Dictionary = game.sim.players[1]
	var b = fixture(101,["clothes","narcotics"],Vector3(2,1.1,0),"approved",true)
	shot("neutral_xray_legal_lookalike","Unopened scan shows identical neutral unknown shapes, not categorical truth; approved-key timed challenge reveals cleared legal lookalike.")
	select_bag(101)
	await key(KEY_F)
	await wait_s(2)
	check(not game.hud.xray_canvas.identified and game.hud.xray_canvas.scanned,"Unopened X-ray is neutral and unidentified")
	await snap("02-neutral-xray")
	await key(KEY_F)
	await key(KEY_2)
	await key(KEY_E)
	await wait_s(2)
	await snap("03-key-lock")
	await solve()
	check(b.unlocked,"Approved key sequence unlocks actual bag",{"key_durability":p.key_durability})
	await key(KEY_O)
	await browser()
	await wait_s(3)
	await snap("04-cleared-lookalike")
	check(b.items[1].category == "legal" and "Cleared legal lookalike" in game.hud.browser_rows.get_child(1).text,"Probabilistic legal lookalike explicitly shown in real browser",b.items[1].truth)
	await key(KEY_I)
	shot("wrong_sequence_worn_key","Wrong input consumes tool durability; repeated genuine wrong attempts wear the key to zero; exhausted key refuses a challenge.")
	await key(KEY_C)
	await key(KEY_R)
	check(not b.opened and not b.unlocked and p.seals == 2,"C closes and R relocks using one real seal")
	await wait_s(2)
	while p.key_durability > 0:
		await key(KEY_E)
		if p.lock_game.is_empty(): break
		var wrong: int = (int(p.lock_game.sequence[0])+1)%3
		await key(KEY_1+wrong)
		await wait_s(0.3)
	await wait_s(2)
	await key(KEY_E)
	check(p.key_durability == 0 and p.lock_game.is_empty() and not b.unlocked,"Genuine failed sequences wear out key and reject unlock at zero")
	await snap("05-worn-key")
	await wait_s(2)
	shot("pliers_and_close_relock","Four-input timed pliers challenge cuts lock; bag opens, then closes and relocks with a seal.")
	await key(KEY_3)
	await key(KEY_E)
	await wait_s(2)
	await snap("06-pliers-lock")
	await solve()
	await key(KEY_O)
	check(b.opened and b.lock == "cut" and p.pliers_durability == 4,"Pliers sequence cuts lock, consumes durability, O opens")
	await wait_s(2)
	await key(KEY_C)
	await key(KEY_R)
	await wait_s(2)
	check(not b.opened and not b.unlocked and b.lock == "approved","Explicit close/relock after pliers")
	archive(101)
	# Inventory and real additive mass accounting.
	b = fixture(102,["clothes","electronics","books"],Vector3(2,1.1,0))
	var other = fixture(103,["socks"],Vector3(2.9,1.1,0))
	other.unlocked = true
	other.opened = true
	other.inspected = true
	fixtures.append({"type":"initial_open_bag","id":103,"unlocked":true,"opened":true,"inspected":true})
	shot("nonfirst_item_crossbag_repack","Real item browser picks second item (electronics), dropdown chooses another open bag, repack adds exact item mass to destination and subtracts from source.")
	select_bag(102)
	await key(KEY_O)
	await browser()
	await wait_s(2)
	var source_mass: float = b.mass_kg
	var dest_mass: float = other.mass_kg
	var chosen: Dictionary = b.items[1]
	var item_mass: float = chosen.mass_kg
	await choose(1)
	await wait_s(2)
	check(p.held_kind == "item" and p.held_id == chosen.id,"Second item button selects exact electronics, not first")
	for i in range(game.hud.browser_picker.item_count):
		if game.hud.browser_picker.get_item_id(i) == 103:
			game.hud.browser_picker.select(i)
			game.hud.browser_picker.item_selected.emit(i)
	refresh()
	await wait_s(2)
	game.hud.repack_button.pressed.emit()
	refresh()
	await wait_s(2)
	check(absf(other.mass_kg-dest_mass-item_mass)<0.001 and absf(source_mass-b.mass_kg-item_mass)<0.001,"Cross-bag repack conserves exact additive mass",{"source_before":source_mass,"source_after":b.mass_kg,"target_before":dest_mass,"target_after":other.mass_kg,"item_kg":item_mass})
	await snap("07-repacked-different-bag")
	await key(KEY_I)
	shot("individual_item_throw","Select a specific item in real browser, close it, G launches individual item through actual host physics to floor.","Center action plus inventory left; no HUD-only crop")
	select_bag(102)
	await browser()
	await choose(0)
	await key(KEY_I)
	move(Vector3(2,0.03,2),Vector3(1,1,4.5))
	await wait_s(2)
	var thrown_id: int = p.held_id
	await key(KEY_G)
	check(game.sim.get_item(thrown_id).location == "airborne","G sends individual item into authoritative flight")
	await wait_s(0.3)
	await snap("08-individual-item-airborne")
	await wait_s(3)
	check(game.sim.get_item(thrown_id).location == "floor","Thrown individual item physically lands")
	archive(102)
	archive(103)
	# Each specialist category has separate visible real pickup and disposal.
	var categories = [["weapon_prop","weapons"],["explosive_prop","explosives"],["hazard_canister","dangerous"]]
	var case_id = 110
	for spec in categories:
		b = fixture(case_id,["clothes",spec[0]],Vector3(2,1.1,0))
		shot("taxonomy_dispose_"+spec[1],"Real browser identifies "+spec[1]+" training prop; second item picked up, carried to secure disposal station; real button disposes object and earns $10.")
		select_bag(case_id)
		await key(KEY_1)
		await key(KEY_O)
		await browser()
		await wait_s(2)
		await snap("taxonomy-"+spec[1])
		var obj: Dictionary = b.items[1]
		await choose(1)
		await key(KEY_I)
		await wait_s(1)
		move(Vector3(6,0.03,1.3),Vector3(6,1,0))
		await wait_s(2)
		await key(KEY_E)
		check(game.hud.station_panel.visible,"Actual secure disposal station opens: "+spec[1])
		var old_money: int = game.sim.money
		await station_action("dispose_item")
		await wait_s(2)
		check(obj.location == "disposed" and p.held_kind == "" and game.sim.money == old_money+10,"Specialist disposal removes "+spec[1]+" and earns real $10")
		await snap("disposal-"+spec[1])
		await key(KEY_ESCAPE)
		archive(case_id)
		case_id += 1
	b = fixture(120,["narcotics","fruit","customs_relic"],Vector3(2,1.1,0))
	shot("taxonomy_narcotics_organics_customs","Actual scrollable browser lists narcotics, organic moon fruit, and customs relic with masses and categories in one open inspected case.")
	select_bag(120)
	await key(KEY_O)
	await browser()
	await wait_s(3)
	check(game.hud.browser_rows.get_child_count()==3 and b.items.map(func(i): return i.category)==["narcotics","organic","customs"],"Visible real browser covers narcotics / organic / customs")
	await snap("taxonomy-narcotics-organic-customs")
	await key(KEY_I)
	archive(120)
	b = fixture(121,["wildlife_crate","documents"],Vector3(2,1.1,0))
	shot("taxonomy_wildlife","Protected fictional cloud-lizard wildlife item is visible in real browser; attempting removal is safely refused, remains in its carrier.")
	select_bag(121)
	await key(KEY_O)
	await browser()
	await wait_s(2)
	await choose(0)
	check(p.held_kind=="" and b.items[0].location=="bag","Wildlife stays safe in bag after prohibited removal attempt")
	await wait_s(2)
	await snap("taxonomy-wildlife")
	await key(KEY_I)
	archive(121)
	shot("earned_funds_restock","$30 earned only by three actual specialist disposals funds a real $12 station restock; worn key restored to eight, pliers to five, seals to three.")
	move(Vector3(-3,0.03,1.6),Vector3(-3,1,0.5))
	await wait_s(2)
	await key(KEY_E)
	await wait_s(2)
	var before: int = game.sim.money
	await station_action("restock_tools")
	await wait_s(2)
	check(before==30 and game.sim.money==18 and p.key_durability==8 and p.pliers_durability==5 and p.seals==3,"Earned disposal money funds authoritative tool station restock without seeded funds",{"before":before,"after":game.sim.money})
	await snap("09-earned-restock")
	await key(KEY_ESCAPE)
	# Physical stack, real gravity, and actual support removal.
	var base = fixture(130,["clothes"],Vector3(-0.5,0.04,2))
	var middle = fixture(131,["books"],Vector3(-0.5,0.8,2))
	var top = fixture(132,["electronics"],Vector3(-0.5,2.3,2))
	base.location="floor"
	middle.location="floor"
	top.location="airborne"
	top.velocity=Vector3.ZERO
	top.last_thrower=0
	fixtures.append({"type":"pile_gravity_setup","ids":[130,131,132],"base":"floor y0.04","middle":"floor y0.8 initially unsupported","top":"airborne y2.3 velocity0; actual gravity landing and damage"})
	shot("physical_stack_impact_damage","Three actual bag bodies settle under gravity into a supported stack; top impact increases damage. Removing bottom with E makes remaining stack visibly fall.","Keep center stack and right damage manifest")
	move(Vector3(-0.5,0.03,4.0),Vector3(-0.5,0.95,2))
	game.selected_id=132
	await wait_s(3)
	check(top.position.y>0.8 and middle.position.y>0.4,"Physical bags settle into genuine supported stack",{"base":str(base.position),"middle":str(middle.position),"top":str(top.position)})
	check(top.damage>0,"Gravity impact damages top bag",{"damage":top.damage})
	await snap("10-physical-stack")
	await wait_s(2)
	move(Vector3(-0.5,0.03,3.3),base.position+Vector3(0,0.1,0))
	var height: float = top.position.y
	await key(KEY_1)
	await key(KEY_E)
	check(p.held_kind=="bag" and p.held_id==130,"E physically removes supporting bottom bag")
	await wait_s(2)
	check(top.position.y<height-0.3,"Unsupported stack physically falls after support removed",{"before":height,"after":top.position.y,"middle":str(middle.position),"top_location":top.location})
	await snap("11-support-removed")
	await key(KEY_Q)
	for id in [130,131,132]: archive(id)
	# A staged falling bag injures the real local operator through normal physics.
	shot("nongraphic_impact_and_firstaid","Staged airborne luggage falls into operator; real collision reduces health without gore; nearby first-aid station button restores it to 100.","Full frame for incoming luggage and health; first-aid menu centered")
	move(Vector3(7.2,0.03,2),Vector3(7.2,2.5,1.8))
	b = fixture(140,["books","electronics"],Vector3(7.2,3.2,2))
	b.location="airborne"
	b.velocity=Vector3.ZERO
	b.last_thrower=0
	b.flight_age=1.0
	fixtures.append({"type":"injury_drop_setup","id":140,"position":"(7.2,3.2,2)","velocity":"zero","last_thrower":0,"flight_age":1,"health_seeded":false,"note":"Actual gravity and host collision cause non-graphic injury"})
	await wait_s(0.3)
	await snap("12-incoming-impact")
	await wait_s(2)
	check(p.health<100.0 and p.health>0.0,"Actual falling-bag physics injures player non-graphically",{"health_after_impact":p.health})
	move(Vector3(7.7,0.03,1.3),Vector3(7.7,1,0))
	await wait_s(2)
	await key(KEY_E)
	await wait_s(2)
	await station_action("first_aid")
	await wait_s(2)
	check(p.health==100.0,"Actual first-aid station button restores authoritative health to 100")
	await snap("13-first-aid-recovered")
	if not current.is_empty():
		current.end_frame=Engine.get_process_frames()-start_frame
		current.end=float(current.end_frame)/24.0
		shots.append(current)
	current={}
	checkpoint()
	print("INSPECTION_FINISHED passed=",not failed," assertions=",checks.size()," frames=",Engine.get_process_frames()-start_frame)
	quit(1 if failed else 0)
