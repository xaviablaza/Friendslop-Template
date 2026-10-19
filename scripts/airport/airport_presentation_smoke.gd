extends SceneTree
## Focused real scene/input/UI smoke. Explicit fixtures, no gameplay recording.
## godot --headless --path . --script res://scripts/airport/airport_presentation_smoke.gd
var game
var checks: Array[String] = []
var failed = false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> void:
	if ok:
		checks.append(text)
		print("AIRPORT_PRESENTATION_PASS ", text)
	else:
		failed = true
		push_error("AIRPORT_PRESENTATION_FAIL " + text)

func frames(count: int = 2) -> void:
	for index in range(count): await process_frame

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func move(at: Vector3, look: Vector3) -> void:
	game.chef.position = at
	game.chef.velocity = Vector3.ZERO
	game.chef.face(look)
	game.poses[1] = {"position": at, "yaw":game.chef.rotation.y}
	game.sim.set_player_position(1,at+Vector3(0,0.3,0))
	game._process(0.0)

func refresh() -> void:
	game._process(0.0)

func click_station(action: String) -> void:
	for child in game.hud.station_rows.get_children():
		if child is Button and child.pressed.get_connections().size() > 0:
			var bindings = child.pressed.get_connections()[0].callable.get_bound_arguments()
			if bindings.size() == 3 and bindings[0] == action:
				child.pressed.emit()
				return
	check(false,"Station button exists: " + action)

func _run() -> void:
	await process_frame
	root.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	game = load("res://scenes/level/airport/AirportBaggage.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.set_process(false)
	game.set_physics_process(false)
	check(game.chef is AirportChef,"Airport uses dedicated sprint/crouch/jump controller")
	check(not game.hud.shop.visible and not game.hud.browser.visible and not game.hud.station_panel.visible,"All gameplay modals initially hidden")
	check(game.hud.chapter.text == "","Pre-existing clean HUD chapter/title preserved")
	game.sim = load("res://scripts/airport/airport_simulation.gd").new()
	game.sim.set_fixture_mode(true)
	game.sim.add_player(1)
	game.sim.belt_running = false
	game.sim._try_arrive()
	var bag: Dictionary = game.sim.bags[1]
	bag.location = "table"
	bag.position = Vector3(2,1.1,0)
	bag.lock = "approved"
	bag.unlocked = false
	bag.opened = false
	game.sim._try_arrive()
	var second: Dictionary = game.sim.bags[2]
	second.location = "table"
	second.position = Vector3(2.7,1.1,0)
	second.unlocked = true
	second.opened = true
	second.inspected = true
	move(Vector3(2,0.03,1.2),bag.position+Vector3(0,0.2,0))
	game.selected_id = 1
	await key(KEY_2)
	await key(KEY_E)
	refresh()
	var player: Dictionary = game.sim.players[1]
	check(not player.lock_game.is_empty() and game.hud.lock_panel.visible,"E with equipped key starts visible timed lock sequence")
	if not player.lock_game.is_empty():
		# Explicit sequence fixture covers all three independent input paths.
		player.lock_game.sequence = [1,0,2]
		refresh()
		var sequence: Array = player.lock_game.sequence.duplicate()
		await key(KEY_1+int(sequence[0]))
		await key(KEY_SPACE)
		refresh()
		check(not game.chef.requested_jump,"SPACE lock input does not leak into jump")
		if not player.lock_game.is_empty():
			var value = int(sequence[2])
			game.hud.lock_panel.get_child(0).get_child(1).get_child(value).pressed.emit()
	refresh()
	check(bag.unlocked and player.lock_game.is_empty(),"Numeric physical keys, SPACE and button inputs unlock authoritatively")
	await key(KEY_O)
	refresh()
	check(bag.opened,"O opens selected bag")
	await key(KEY_I)
	refresh()
	check(game.hud.browser.visible and not game.chef.input_enabled,"I opens scrollable contents and isolates gameplay movement")
	check(game.hud.browser_rows.get_child_count() == bag.items.size(),"Browser enumerates every item, not just first content")
	var chosen_index = mini(1,bag.items.size()-1)
	var chosen_id = int(bag.items[chosen_index].id)
	game.hud.browser_rows.get_child(chosen_index).pressed.emit()
	refresh()
	check(player.held_kind == "item" and int(player.held_id) == chosen_id,"Non-first item browser button selects exact item")
	game.hud.browser_bag_id = 2
	game.hud.browser_signature = ""
	refresh()
	game.hud.repack_button.pressed.emit()
	refresh()
	check(player.held_kind == "" and second.items.any(func(item): return int(item.id)==chosen_id),"Browser returns selected item into a different open bag")
	await key(KEY_I)
	refresh()
	check(not game.hud.browser.visible and game.chef.input_enabled,"I closes browser and restores gameplay input")
	game.chef.face(bag.position)
	refresh()
	game.selected_id = 1
	await key(KEY_C)
	await key(KEY_R)
	check(not bag.opened and not bag.unlocked,"C closes and R consumes seal to relock")
	# Old/exploit requests must not work when a station is far away.
	player.health = 40.0
	move(Vector3(-5,0.03,2),Vector3.ZERO)
	game.request_action("first_aid")
	check(player.health == 40.0,"Gateway rejects out-of-range first aid")
	move(Vector3(7.7,0.03,1.2),AirportRoom.FIRST_AID_POINT)
	await key(KEY_E)
	check(game.hud.station_panel.visible,"E opens reachable first-aid station menu")
	click_station("first_aid")
	check(player.health == 100.0,"First-aid button restores authoritative health")
	await key(KEY_ESCAPE)
	move(Vector3(-3,0.03,1.6),AirportRoom.TOOL_POINT)
	await key(KEY_E)
	game.sim.money = 20
	player.key_durability = 0
	click_station("restock_tools")
	check(player.key_durability == 8 and game.sim.money == 8,"Tools station button restocks and spends authoritative funds")
	await key(KEY_ESCAPE)
	move(Vector3(-7.5,0.03,1.5),AirportRoom.DOG_CARE_POINT)
	game.sim.dog.position = Vector3(-7.5,0.3,0.9)
	game.sim.dog.location = "floor"
	game._open_station("dog_care")
	player.food = 0
	player.water = 0
	click_station("take_food")
	click_station("take_water")
	game.sim.dog.hunger = 70.0
	game.sim.dog.thirst = 70.0
	click_station("feed_dog")
	click_station("water_dog")
	click_station("rest_dog")
	check(player.food == 0 and player.water == 0 and game.sim.dog.hunger < 70 and game.sim.dog.thirst < 70 and game.sim.dog.rest_left > 0,"Animal-care buttons collect/consume portions and start rest")
	await key(KEY_ESCAPE)
	var old_mode = str(game.sim.dog.mode)
	await key(KEY_P)
	check(game.sim.dog.mode != old_mode,"P cycles authoritative dog mode")
	game.request_action("pickup_dog")
	await key(KEY_G)
	refresh()
	check(game.sim.dog.location == "airborne" and game.dog_node.position == game.sim.dog.position,"G gently throws dog and renders authoritative airborne position")
	# Exact carried kind dispatch: item throw is not a disguised gentle drop.
	bag.opened = true
	bag.unlocked = true
	move(Vector3(2,0.03,1.2),bag.position)
	game.request_action("take_item",1,0)
	var airborne_id = int(player.held_id)
	await key(KEY_G)
	refresh()
	check(game.sim.get_item(airborne_id).location == "airborne" and game.item_nodes.has(airborne_id),"G throws individual item and builds its airborne visual")
	# Explicit dangerous-object fixture tests disposal button and range boundary.
	var hazardous = AirportCatalog.instantiate(AirportCatalog.entry("hazard_canister"),game.sim.rng,9001,true)
	bag.items.append(hazardous)
	game.sim.ensure_bag_physics(bag)
	game.request_action("take_item",1,bag.items.size()-1)
	game.request_action("dispose_item")
	check(player.held_kind == "item" and hazardous.location == "held","Gateway rejects out-of-range dangerous-object disposal")
	move(Vector3(6,0.03,1.2),AirportRoom.DISPOSAL_POINT)
	await key(KEY_E)
	click_station("dispose_item")
	check(hazardous.location == "disposed" and player.held_kind == "","Secure-disposal station button consumes carried dangerous prop")
	await key(KEY_ESCAPE)
	# Carrier feeding is available through the same arbitrary-bag browser.
	second.carrier = true
	second.pet = {"species":"rabbit","hunger":75.0,"thirst":70.0,"fed":false}
	player.food = 1
	player.water = 1
	move(Vector3(2.7,0.03,1.2),second.position)
	game.selected_id = 2
	await key(KEY_I)
	game.hud.browser_bag_id = 2
	game.hud.browser_signature = ""
	refresh()
	game.hud.pet_button.pressed.emit()
	check(second.pet.fed and second.pet.hunger == 0 and second.pet.thirst == 0 and player.food == 0 and player.water == 0,"Browser pet-care button consumes food and water for selected carrier")
	await key(KEY_ESCAPE)
	# Two model operators exercise the real host boundary plus ordinary H/Q.
	game.sim.add_player(2)
	game.poses[2] = {"position":Vector3(2.8,0.03,1.2),"yaw":0.0}
	game.sim.set_player_position(2,Vector3(2.8,0.33,1.2))
	bag.shell_mass_kg = 32.0
	game.sim.ensure_bag_physics(bag)
	move(Vector3(2,0.03,1.2),bag.position)
	game.request_action("pickup_bag",1)
	refresh()
	var anchor: Vector3 = game.chef.position
	Input.action_press("move_right")
	for index in range(6): await physics_frame
	Input.action_release("move_right")
	check(game.chef.position.distance_to(anchor) < 0.08 and game.chef.movement_multiplier == 0.0,"Primary heavy carrier is physically movement-locked awaiting helper")
	game._perform_action(2,"join_carry",1,null)
	refresh()
	check(game.sim.carry_speed(1) > 0.0 and game.sim.players[2].carry_partner == 1,"Host boundary accepts nearby second operator as heavy-carry helper")
	check(game.bag_nodes[1].position == game.sim.bag_position(bag),"Heavy held bag remains visible at authoritative physical model position")
	await key(KEY_H)
	refresh()
	check(bag.location == "floor" and player.held_kind == "" and game.sim.players[2].carry_partner == 0,"H releases primary and helper together")
	game._perform_action(2,"pickup_bag",1,null)
	game.chef.face(game.sim.bag_position(bag))
	refresh()
	await key(KEY_H)
	check(int(player.carry_bag) == 1,"H joins another operator's heavy bag through ordinary input")
	await key(KEY_Q)
	check(int(player.carry_bag) == -1 and bag.location == "floor","Q gently releases shared bag even when helper hands are empty")
	game.sim.remove_player(2)
	game.poses.erase(2)
	# Shop/ESC isolation and authoritative controller budget integration.
	move(Vector3(-3,0.03,1.9),AirportRoom.AIRPORT_SHOP_POINT)
	await key(KEY_TAB)
	check(game.hud.shop.visible and not game.chef.input_enabled,"TAB opens shop modal with gameplay isolated")
	var held_before = str(player.held_kind)
	await key(KEY_G)
	await key(KEY_C)
	check(str(player.held_kind) == held_before and game.hud.shop.visible,"Shop consumes gameplay throw/close controls")
	await key(KEY_ESCAPE)
	check(not game.hud.shop.visible and game.chef.input_enabled,"ESC closes shop and restores gameplay")
	player.stamina = 65.0
	player.health = 83.0
	refresh()
	check(game.chef.stamina == 65.0 and game.chef.health == 83.0,"Controller receives authoritative stamina and health")
	move(Vector3(0,0.03,2),Vector3(0,1,-1))
	for index in range(5): await physics_frame
	await key(KEY_SPACE)
	for index in range(3): await physics_frame
	check(game.chef.requested_jump and game.chef.velocity.y > 0,"SPACE performs real ordinary jump outside lock modal")
	game._physics_process(0.1)
	check(not game.chef.requested_jump and player.stamina < 65.0,"Bounded movement reporting consumes jump intent and model stamina")
	# Neutral X-ray on the host must not exploit full host truth.
	bag.scanned = true
	bag.opened = false
	bag.inspected = false
	game.selected_id = 1
	game.hud.refresh_airport(game.sim,1,1,"","")
	check(game.hud.xray_canvas.scanned and not game.hud.xray_canvas.identified,"Unopened host X-ray never identifies hidden categorical truth")
	var redacted = game.sim.snapshot_for(2)
	check(not redacted.has("_rng_state") and not redacted.bags[1].has("truth") and redacted.bags[1].category == "unknown","Recipient snapshot contains no uninspected host truth")
	var visual = AirportRoom.bag_mesh({"carrier":true,"color":0,"flight":0,"opened":false,"pet":{"species":"rabbit"}})
	check(visual.get_node_or_null("PetAnimalVisual") != null,"Closed ventilated carrier contains actual visible pet animal")
	visual.free()
	# Sample physics through the actual operator aisle at standing capsule height.
	await physics_frame
	var clear = true
	for x in range(-8,9):
		var shape = CapsuleShape3D.new()
		shape.radius = 0.29
		shape.height = 1.68
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,Vector3(x,0.88,2))
		query.exclude = [game.chef.get_rid()]
		clear = clear and game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	check(clear,"Care/disposal station colliders preserve continuous reachable operator aisle")
	# Review regressions: frozen lock modal at shift boundary, then a real desk.
	game.chef.set_physics_process(false)
	game.sim = load("res://scripts/airport/airport_simulation.gd").new()
	game.sim.set_fixture_mode()
	game.sim.add_player(1)
	game.sim._try_arrive()
	game.sim.belt_running = false
	var boundary_bag: Dictionary = game.sim.bags[1]
	boundary_bag.location = "table"
	move(Vector3(2,0.03,1.4),Vector3(2,1.3,0))
	game.request_action("tool",-1,1)
	game.request_action("unlock",1)
	check(not game.sim.players[1].lock_game.is_empty(),"Boundary regression starts a real gateway lock")
	game.sim.time_left = 0.05
	game.sim.update(0.1)
	refresh()
	check(game.sim.shift_finished and game.sim.players[1].lock_game.is_empty() and game.chef.input_enabled,"Shift end cancels lock modal and restores host input")
	await key(KEY_N)
	check(not game.sim.shift_finished and game.sim.day == 2,"Ordinary N continues after shift ends mid-lock")
	game.sim.collision_query = game._bag_collision
	boundary_bag.location = "floor"
	boundary_bag.off_belt = true
	boundary_bag.position = Vector3(2,0.04,1.4)
	boundary_bag.shell_mass_kg = 21.0
	game.sim.ensure_bag_physics(boundary_bag)
	game.request_action("tool",-1,0)
	game.request_action("pickup_bag",1)
	move(Vector3(2,0.9,0.75),Vector3(2,0,0.5))
	game.request_action("throw_bag",1,{"direction":Vector3(0,-0.995,-0.0998749).normalized()})
	var settled_height: float = -1.0
	for index in range(180):
		game.sim.update(1.0/60.0)
		if boundary_bag.location == "floor" and settled_height < 0:
			settled_height = boundary_bag.position.y
	check(settled_height > 0.8,"Actual downward throw settles on workstation surface")
	check(absf(boundary_bag.position.y-settled_height) < 0.02,"Pile support never pulls settled bag through real desk")
	print("AIRPORT_PRESENTATION_RESULT ",JSON.stringify({"passed":not failed,"checks":checks.size(),"details":checks}))
	game.queue_free()
	await frames(2)
	quit(1 if failed else 0)
