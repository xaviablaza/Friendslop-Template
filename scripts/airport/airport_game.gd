extends Node3D
## Airport presentation and server-owned interaction boundary.
const Model = preload("res://scripts/airport/airport_simulation.gd")
var sim = Model.new()
var chef: SushiChef
var room: AirportRoom
var hud: AirportHUD
var local_id = 1
var poses: Dictionary = {}
var bag_nodes: Dictionary = {}
var bag_signatures: Dictionary = {}
var item_nodes: Dictionary = {}
var avatars: Dictionary = {}
var dog_node: Node3D
var target: Dictionary = {}
var selected_id = -1
var feedback = ""
var feedback_left = 0.0
var clock = 0.0
var belt_clock = 0.0
var net_clock = 0.0
var last_bark = 0
var last_dog_scan = 0
var xray_signature = ""
var bark_player: AudioStreamPlayer
var test_driver: Node
var tool_node: Node3D
var shown_tool = -1
var carry_rig: Node3D

func _ready() -> void:
	local_id = multiplayer.get_unique_id()
	room = AirportRoom.new()
	add_child(room)
	room.build()
	chef = SushiChef.new()
	# Two automated windows must not compete for the desktop mouse grab.
	chef.automated = OS.get_cmdline_user_args().has("--airport-throw-host") or OS.get_cmdline_user_args().has("--airport-throw-client")
	chef.position = Vector3(0 if local_id == 1 else 0.8, 0.03, 1.7)
	add_child(chef)
	carry_rig = AirportBagPresentation.make_hands()
	chef.camera.add_child(carry_rig)
	sim.collision_query = _bag_collision
	hud = AirportHUD.new()
	add_child(hud)
	hud.upgrade_requested.connect(func(kind): request_action("upgrade_" + kind))
	hud.menu_requested.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; SceneManager.go_to_main_menu())
	dog_node = AirportRoom.dog_mesh()
	add_child(dog_node)
	bark_player = AudioStreamPlayer.new()
	bark_player.stream = _bark_sound()
	bark_player.volume_db = -12
	add_child(bark_player)
	$NetworkReady.player_ready_for_gameplay.connect(_register_chef)
	multiplayer.peer_disconnected.connect(_remove_chef)
	if _session_active() and multiplayer.is_server():
		_register_chef(local_id)
	SceneManager.mark_scene_as_loaded(self)
	var args = OS.get_cmdline_user_args()
	if args.has("--airport-throw-host") or args.has("--airport-throw-client"):
		test_driver = load("res://scripts/airport/airport_throw_playtest.gd").new()
	elif args.has("--airport-tour"):
		test_driver = load("res://scripts/airport/airport_playtest.gd").new()
	elif args.has("--airport-net-host") or args.has("--airport-net-client"):
		test_driver = load("res://scripts/airport/airport_network_smoke.gd").new()
	if test_driver:
		test_driver.name = "PlaytestDriver"
		test_driver.game = self
		add_child(test_driver)

func _session_active() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _register_chef(peer_id: int) -> void:
	if not _session_active() or not multiplayer.is_server() or sim.players.has(peer_id):
		return
	sim.add_player(peer_id)
	poses[peer_id] = {"position": Vector3(0 if peer_id == 1 else 0.8, 0.03, 1.7), "yaw": 0.0}
	print("AIRPORT_READY peer=", peer_id)

func _remove_chef(peer_id: int) -> void:
	if _session_active() and multiplayer.is_server():
		sim.remove_player(peer_id)
		poses.erase(peer_id)

func _process(delta: float) -> void:
	if not _session_active():
		chef.input_enabled = false
		return
	clock += delta
	feedback_left = maxf(0, feedback_left - delta)
	if multiplayer.is_server():
		poses[local_id] = {"position": chef.position, "yaw": chef.rotation.y}

	net_clock += delta
	var sending_flight = sim.bags.values().any(func(bag): return bag.location == "airborne")
	if net_clock >= (0.033 if sending_flight else 0.08):
		net_clock = 0
		if multiplayer.is_server():
			for id in sim.players:
				if id != local_id and multiplayer.get_peers().has(id):
					_receive_snapshot.rpc_id(id, sim.snapshot(), poses)
		elif sim.players.has(local_id):
			_move_chef.rpc_id(1, chef.position, chef.rotation.y)
	target = interaction_target()
	if target.get("kind", "") == "bag":
		selected_id = int(target.id)
	var held: Dictionary = sim.players.get(local_id, {})
	if held.get("held_kind", "") == "bag":
		selected_id = int(held.held_id)
	if selected_id < 0:
		for bag in sim.bags.values():
			if bag.scanned and bag.location != "sorted":
				selected_id = int(bag.id)
				break
	if sim.belt_running: belt_clock += delta
	room.animate_belt(belt_clock, 0.065)
	room.set_expanded(sim.airport_level)
	chef.movement_multiplier = sim.carry_speed(local_id)
	var carrying: Dictionary = sim.players.get(local_id,{})
	var held_bag: Dictionary = sim.bags.get(carrying.get("held_id",-1),{}) if carrying.get("held_kind","")=="bag" else {}
	AirportBagPresentation.update_hands(carry_rig,held_bag,clock)
	_update_bags()
	_update_items()
	_update_dog()
	_update_tool()
	_update_avatars()
	_update_xray()
	hud.refresh_airport(sim, local_id, selected_id, target.get("prompt", "Inspect arrivals, then carry bags to their correct bay."), feedback if feedback_left > 0 else "")
	if sim.dog.alerts > last_bark:
		last_bark = int(sim.dog.alerts)
		bark_player.play()
	last_dog_scan = sim.dog_scan_count

func interaction_target() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for bag in sim.bags.values():
		if bag.location in ["belt", "table", "floor", "airborne"]:
			var tool = int(sim.players.get(local_id, {}).get("tool", 0))
			var prompt = "[E] Carry bag #%d  /  [O] Open  /  [I] Contents" % bag.id if tool == 0 else "[E] Use %s on bag #%d" % ["KEY" if tool == 1 else "LARGE PLIERS", bag.id]
			if bag.location == "airborne": prompt = "[E] CATCH BAG #%d / %.0f kg" % [bag.id,bag.mass_kg]
			candidates.append({"kind": "bag", "id": bag.id, "point": sim.bag_position(bag) + Vector3(0, 0.2, 0), "prompt": prompt})
		for item in bag.items:
			if item.location == "floor":
				candidates.append({"kind": "item", "id": item.id, "point": item.position, "prompt": "[E] Pick up " + str(item.label)})
	if sim.dog.location in ["floor", "belt"]:
		candidates.append({"kind": "dog", "point": sim.dog.position + Vector3(0, 0.2, 0), "prompt": "[E] Pick up dog  /  [K] Call dog\nHarmless training scanner; no animal harm"})
	candidates.append({"kind": "table", "point": AirportRoom.TABLE_POINT, "prompt": "[E] Put carried bag on inspection desk\n[O] Open  /  [I] Take or return an item"})
	candidates.append({"kind": "belt", "point": AirportRoom.SCAN_POINT, "prompt": "[E] Put bag/dog onto scanner belt\nTraining scanner / non-ionizing"})
	candidates.append({"kind": "console", "point": AirportRoom.SCAN_CONSOLE, "prompt": "[E] Pause / resume intake\n[F] Enlarge live X-ray"})
	candidates.append({"kind": "tools", "point": AirportRoom.TOOL_POINT, "prompt": "TOOLS  [1] Hands  [2] Approved-lock key  [3] Large pliers"})
	candidates.append({"kind": "evidence", "point": AirportRoom.EVIDENCE_POINT, "prompt": "[E] Deposit carried prohibited item\nLegal personal items are not contraband"})
	candidates.append({"kind": "shop", "point": AirportRoom.AIRPORT_SHOP_POINT, "prompt": "[E / TAB] Airport development\nEarn funds, satisfy contracts, expand routes"})
	for route in AirportRoom.ROUTES:
		if sim.airport_level < 2 and route in ["gate_c", "oversize"]:
			continue
		candidates.append({"kind": "route", "route": route, "point": AirportRoom.ROUTES[route], "prompt": "[E] Route carried bag: " + hud.route_name(route)})
	var best: Dictionary = {}
	var score = 0.76
	for candidate in candidates:
		var direction: Vector3 = candidate.point - chef.camera.global_position
		if direction.length() > 3.15:
			continue
		var alignment = (-chef.camera.global_basis.z).dot(direction.normalized())
		# Small bags/items should win ties against the large workstation below.
		if candidate.kind in ["bag", "item", "dog"]:
			alignment += 0.035
		if alignment > score:
			score = alignment
			best = candidate
	return best

func _unhandled_input(event: InputEvent) -> void:
	if not _session_active() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if hud.shop.visible:
				_toggle_shop(false)
			else:
				var released = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if released else Input.MOUSE_MODE_CAPTURED
				hud.pointer_panel.visible = released
				chef.input_enabled = not released
		KEY_TAB:
			if _near(AirportRoom.AIRPORT_SHOP_POINT):
				_toggle_shop(not hud.shop.visible)
			else:
				_show_feedback("Use the airport development terminal behind the tool rack.")
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			if hud.shop.visible:
				request_action("upgrade_" + AirportHUD.UPGRADE_ORDER[event.physical_keycode - KEY_1])
			elif event.physical_keycode <= KEY_3:
				request_action("tool", -1, event.physical_keycode - KEY_1)
		KEY_E:
			if chef.input_enabled and not hud.shop.visible:
				# Fast bags can move between display frames: use the current aim.
				target = interaction_target()
				interact()
		KEY_O:
			if chef.input_enabled and not hud.shop.visible:
				request_action("open", selected_bag())
		KEY_I:
			if chef.input_enabled and not hud.shop.visible:
				handle_contents()
		KEY_G:
			if chef.input_enabled and not hud.shop.visible:
				throw_held()
		KEY_Q:
			if chef.input_enabled and not hud.shop.visible:
				drop_held()
		KEY_K:
			if chef.input_enabled and not hud.shop.visible:
				request_action("call_dog", -1, chef.position + Vector3(0, 0.3, 0))
		KEY_F: hud.xray_large = not hud.xray_large
		KEY_N:
			if multiplayer.is_server() and sim.shift_finished:
				sim.next_shift()

func selected_bag() -> int:
	var player: Dictionary = sim.players.get(local_id, {})
	if player.get("held_kind", "") == "bag":
		return int(player.held_id)
	return int(target.id) if target.get("kind", "") == "bag" else selected_id

func interact() -> void:
	var player: Dictionary = sim.players.get(local_id, {})
	var held = str(player.get("held_kind", ""))
	match target.get("kind", ""):
		"bag":
			var action = "catch_bag" if sim.bags[int(target.id)].location == "airborne" else ("unlock" if int(player.get("tool",0)) != 0 else "pickup_bag")
			request_action(action,int(target.id))
		"item": request_action("pickup_item", int(target.id))
		"dog": request_action("pickup_dog")
		"table":
			if held == "bag":
				request_action("place_bag", -1, {"location": "table", "position": AirportRoom.TABLE_POINT})
		"belt":
			if held in ["dog", "bag"]:
				request_action("place_" + held, -1, {"location": "belt", "t": 0.35, "position": AirportRoom.SCAN_POINT})
		"console":
			if held in ["dog", "bag"]:
				request_action("place_" + held, -1, {"location": "belt", "t": 0.35, "position": AirportRoom.SCAN_POINT})
			else:
				request_action("toggle_belt")
		"evidence": request_action("seize_item")
		"shop": _toggle_shop(true)
		"tools": request_action("tool", -1, (int(player.get("tool", 0)) + 1) % 3)
		"route":
			if held == "bag":
				request_action("route", int(player.held_id), target.route)

func handle_contents() -> void:
	var bag_id = selected_bag()
	if not sim.bags.has(bag_id):
		return
	var player: Dictionary = sim.players.get(local_id, {})
	if player.get("held_kind", "") == "item":
		request_action("return_item", bag_id)
	elif player.get("held_kind", "") == "":
		var items: Array = sim.bags[bag_id].items
		for index in range(items.size()):
			if items[index].location == "bag" and items[index].category != "safeguarding":
				request_action("take_item", bag_id, index)
				return
	else:
		_show_feedback("Put the bag on the desk before handling individual contents.")

func throw_held() -> void:
	var player: Dictionary = sim.players.get(local_id,{})
	if player.get("held_kind","") == "bag":
		request_action("throw_bag",int(player.held_id),{"direction":(-chef.camera.global_basis.z).normalized()})
	else:
		drop_held() # Dogs and individual items are always placed gently.

func drop_held() -> void:
	var player: Dictionary = sim.players.get(local_id, {})
	var kind = str(player.get("held_kind", ""))
	var at = chef.position - chef.basis.z * 0.8 + Vector3(0, 0.3, 0)
	if kind == "bag": at.y = 0.04
	if kind in ["bag", "dog"]:
		request_action("place_" + kind, -1, {"location": "floor", "position": at})
	elif kind == "item":
		request_action("drop_item", -1, at)

func _near(point: Vector3, distance: float = 3.15) -> bool:
	return (chef.position + Vector3(0, 1, 0)).distance_to(point) < distance

func _toggle_shop(open: bool) -> void:
	hud.shop.visible = open
	hud.pointer_panel.visible = false
	chef.input_enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func request_action(action: String, id: int = -1, extra: Variant = null) -> void:
	if not _session_active():
		return
	if multiplayer.is_server():
		_perform_action(local_id, action, id, extra)
	else:
		_request_action.rpc_id(1, action, id, extra)

@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: String, id: int, extra: Variant) -> void:
	if _session_active() and multiplayer.is_server():
		_perform_action(multiplayer.get_remote_sender_id(), action, id, extra)

func _perform_action(peer: int, action: String, id: int, extra: Variant) -> void:
	if not _session_active() or not sim.players.has(peer) or not poses.has(peer):
		return
	var point: Vector3 = poses[peer].position + Vector3(0, 1, 0)
	var station = point
	var player: Dictionary = sim.players[peer]
	match action:
		"throw_bag":
			if not extra is Dictionary or not extra.get("direction") is Vector3: return
			var direction: Vector3 = extra.direction
			if not direction.is_finite() or absf(direction.length()-1.0)>0.05: return
			extra = {"direction":direction.normalized(),"origin":poses[peer].position+Vector3(0,1.25,0)+direction.normalized()*0.55}
		"catch_bag":
			if not sim.bags.has(id): return
			station = sim.bag_position(sim.bags[id])+Vector3(0,0.2,0)
			if point.distance_to(station)>1.7:
				print("AIRPORT_CATCH_MISS peer=",peer," reach=",point.distance_to(station)," bag=",station," player=",point)
				_send_feedback(peer,"Bag is outside catching reach.")
				return
		"tool":
			if not extra is int or extra < 0 or extra > 2:
				return
		"pickup_bag", "unlock", "open", "take_item", "return_item":
			if not sim.bags.has(id):
				return
			station = sim.bag_position(sim.bags[id])
		"pickup_item":
			var item: Dictionary = sim.get_item(id)
			if item.is_empty(): return
			station = item.position
		"place_bag", "place_dog":
			if not extra is Dictionary: return
			match extra.get("location", ""):
				"table":
					if action == "place_dog": return
					station = AirportRoom.TABLE_POINT
					extra = {"location": "table", "position": station}
				"belt":
					station = AirportRoom.SCAN_CONSOLE
					extra = {"location": "belt", "t": 0.35, "position": AirportRoom.SCAN_POINT}
				"floor":
					if not extra.get("position") is Vector3 or not extra.position.is_finite(): return
					if point.distance_to(extra.position) > 2.5: return
					station = extra.position
				_: return
		"drop_item", "call_dog":
			if not extra is Vector3 or not extra.is_finite() or point.distance_to(extra) > 2.5: return
		"pickup_dog": station = sim.dog.position
		"seize_item": station = AirportRoom.EVIDENCE_POINT
		"route":
			if not extra is String or not AirportRoom.ROUTES.has(extra): return
			station = AirportRoom.ROUTES[extra]
			if sim.airport_level < 2 and extra in ["gate_c", "oversize"]:
				_send_feedback(peer, "International / oversized routes require terminal expansion.")
				return
		"toggle_belt": station = AirportRoom.SCAN_CONSOLE
		"upgrade_scanner", "upgrade_kennel", "upgrade_evidence", "upgrade_bio_lab", "upgrade_belt", "upgrade_terminal": station = AirportRoom.AIRPORT_SHOP_POINT
		_: return
	if point.distance_to(station) > 3.2:
		_send_feedback(peer, "Move closer to that station or object.")
		return
	# Model methods enforce ownership/lock/economy rules. Never trust client positions.
	var response: String = sim.act(peer, action, id, extra)
	_send_feedback(peer, response)
	print("AIRPORT_ACTION peer=%d action=%s id=%d result=%s" % [peer, action, id, response])

func _send_feedback(peer: int, text: String) -> void:
	if peer == local_id:
		_show_feedback(text)
	elif multiplayer.get_peers().has(peer):
		_action_feedback.rpc_id(peer, text)

func _show_feedback(text: String) -> void:
	feedback = text
	feedback_left = 3

@rpc("authority", "call_remote", "reliable")
func _action_feedback(text: String) -> void:
	_show_feedback(text)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _move_chef(at: Vector3, yaw: float) -> void:
	if not _session_active() or not multiplayer.is_server() or not at.is_finite() or not is_finite(yaw): return
	var sender = multiplayer.get_remote_sender_id()
	if sim.players.has(sender) and absf(at.x) < 10 and at.z > -4 and at.z < 7 and absf(at.y) < 0.6:
		poses[sender] = {"position": at, "yaw": yaw}

@rpc("authority", "call_remote", "reliable", 2)
func _receive_snapshot(data: Dictionary, player_poses: Dictionary) -> void:
	sim.apply_snapshot(data)
	poses = player_poses

func _update_held_positions() -> void:
	for peer in sim.players:
		if not poses.has(peer): continue
		sim.set_player_position(peer, poses[peer].position + Vector3(0, 0.3, 0))

func _held_transform(node: Node3D, peer: int, scale_value: float, bag: Dictionary = {}) -> void:
	if peer == local_id:
		node.global_transform = chef.camera.global_transform
		node.position = chef.camera.to_global(AirportBagPresentation.carry_offset(bag) if not bag.is_empty() else Vector3(0.35,-0.42,-1.0))
	else:
		var yaw = float(poses.get(peer,{}).get("yaw",0))
		node.position = poses.get(peer,{}).get("position",Vector3.ZERO)+Vector3(0,1.0,0)-Basis(Vector3.UP,yaw).z*0.55
		node.rotation = Vector3(0,yaw,0)
	node.scale = Vector3.ONE * (AirportBagPresentation.carry_scale(bag) if not bag.is_empty() else scale_value)

func _update_bags() -> void:
	for id in sim.bags:
		var bag: Dictionary = sim.bags[id]
		var signature = str([bag.opened, bag.unlocked, bag.lock, bag.items.map(func(item): return item.location)])
		if not bag_nodes.has(id) or bag_signatures.get(id) != signature:
			if bag_nodes.has(id): bag_nodes[id].queue_free()
			var mesh = AirportRoom.bag_mesh(bag)
			add_child(mesh)
			bag_nodes[id] = mesh
			bag_signatures[id] = signature
		var node: Node3D = bag_nodes[id]
		node.visible = bag.location != "sorted"
		AirportBagPresentation.apply_outline(node,bool(bag.off_belt))
		if bag.location == "held":
			_held_transform(node,int(bag.held_by),0.9,bag)
		else:
			node.position = sim.bag_position(bag)
			node.rotation = bag.rotation
			node.scale = Vector3.ONE

func _update_items() -> void:
	for bag in sim.bags.values():
		for item in bag.items:
			if item.location not in ["held", "floor"]:
				if item_nodes.has(item.id):
					item_nodes[item.id].queue_free()
					item_nodes.erase(item.id)
				continue
			if not item_nodes.has(item.id):
				var node = AirportRoom.item_mesh(item)
				add_child(node)
				item_nodes[item.id] = node
			if item.location == "held":
				_held_transform(item_nodes[item.id], int(item.held_by), 1.1)
			else:
				item_nodes[item.id].position = item.position
				item_nodes[item.id].rotation = Vector3.ZERO
				item_nodes[item.id].scale = Vector3.ONE

func _update_dog() -> void:
	if sim.dog.location == "held":
		_held_transform(dog_node, int(sim.dog.held_by), 0.8)
	else:
		dog_node.position = sim.dog.position
		dog_node.scale = Vector3.ONE
		dog_node.rotation = Vector3.ZERO
	var tail = dog_node.get_node_or_null("TailPivot")
	if tail: tail.rotation.z = sin(clock * 8) * 0.35

func _update_tool() -> void:
	var state: Dictionary = sim.players.get(local_id, {"tool":0,"held_kind":""})
	var selected = int(state.tool) if state.held_kind == "" else 0
	if selected == shown_tool: return
	shown_tool = selected
	if is_instance_valid(tool_node): tool_node.queue_free()
	tool_node = Node3D.new()
	tool_node.position = Vector3(0.42,-0.36,-0.85)
	tool_node.rotation_degrees.x = 45
	chef.camera.add_child(tool_node)
	if selected == 1:
		var ring = TorusMesh.new()
		ring.inner_radius = 0.045
		ring.outer_radius = 0.075
		AirportRoom._mesh(tool_node,ring,Vector3(0,0.1,0),Color("d1bc79"))
		AirportRoom._box(tool_node,Vector3(0,0.03,-0.15),Vector3(0.035,0.035,0.3),Color("d1bc79"))
		for i in range(3):
			AirportRoom._box(tool_node,Vector3(0.03,0.03,-0.17-i*0.04),Vector3(0.065,0.04,0.025),Color("d1bc79"))
	elif selected == 2:
		for side in [-1,1]:
			var grip = AirportRoom._box(tool_node,Vector3(side*0.065,0,0.05),Vector3(0.055,0.055,0.38),Color("a65f59"))
			grip.rotation.y = side*0.15
			var jaw = AirportRoom._box(tool_node,Vector3(side*0.035,0,-0.2),Vector3(0.055,0.06,0.18),Color("b8c7c6"))
			jaw.rotation.y = -side*0.3

func _update_xray() -> void:
	if sim.dog.location == "belt":
		var dog_signature = "dog:" + str(sim.dog.scanned)
		if xray_signature == dog_signature: return
		xray_signature = dog_signature
		for node in room.scan_display.get_children(): node.queue_free()
		if sim.dog.scanned:
			var dog_view = AirportRoom.dog_mesh()
			dog_view.position = Vector3(0,0.04,0)
			dog_view.rotation.x = PI / 2
			dog_view.scale = Vector3.ONE * 0.65
			for child in dog_view.get_children():
				if child is MeshInstance3D: child.material_override = SushiRoom.material(Color("8fe3d4"))
			room.scan_display.add_child(dog_view)
		return
	if not sim.bags.has(selected_id): return
	var bag: Dictionary = sim.bags[selected_id]
	var signature = str([selected_id, bag.scanned, bag.opened, sim.upgrades.scanner])
	if xray_signature == signature: return
	xray_signature = signature
	for node in room.scan_display.get_children(): node.queue_free()
	if not bag.scanned: return
	for i in range(bag.items.size()):
		var item = AirportRoom.item_mesh(bag.items[i], true)
		item.position = Vector3((i % 3) * 0.24 - 0.25, 0.12 + (i / 3) * 0.2, 0)
		item.scale = Vector3.ONE * 0.45
		room.scan_display.add_child(item)

func _update_avatars() -> void:
	for peer in poses:
		if peer == local_id: continue
		if not avatars.has(peer):
			var avatar = AirportBagPresentation.make_crew("PLAYER 1" if peer==1 else "PLAYER 2",Color("d3b959") if peer==1 else Color("67a7bf"))
			add_child(avatar)
			avatars[peer] = avatar
		avatars[peer].position = poses[peer].position
		avatars[peer].rotation.y = float(poses[peer].yaw)
		var player: Dictionary = sim.players.get(peer,{})
		var holding = player.get("held_kind","")=="bag"
		var mass = float(sim.bags.get(player.get("held_id",-1),{}).get("mass_kg",0)) if holding else 0.0
		AirportBagPresentation.update_crew(avatars[peer],holding,mass)
	for peer in avatars.keys():
		if not poses.has(peer):
			avatars[peer].queue_free()
			avatars.erase(peer)

func _physics_process(delta: float) -> void:
	if _session_active() and multiplayer.is_server() and is_instance_valid(chef):
		poses[local_id] = {"position":chef.position,"yaw":chef.rotation.y}
		_update_held_positions()
		sim.update(delta)

func _bag_collision(from: Vector3,to: Vector3,bag: Dictionary) -> Dictionary:
	# Swept edge rays against the actual room; flight itself stays host-owned.
	var radius = [0.23,0.3,0.39][int(bag.size)]
	var offsets = [Vector3(0,0.04,0),Vector3(radius,0.18,0),Vector3(-radius,0.18,0),Vector3(0,0.18,radius),Vector3(0,0.18,-radius)]
	var nearest: Dictionary = {}
	var best = INF
	for offset in offsets:
		var query = PhysicsRayQueryParameters3D.create(from+offset,to+offset,1,[chef.get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var distance = (hit.position-(from+offset)).length_squared()
		if distance < best:
			best = distance
			nearest = {"position":hit.position-offset+hit.normal*0.025,"normal":hit.normal}
	return nearest

func _bark_sound() -> AudioStreamWAV:
	var wave = AudioStreamWAV.new()
	wave.mix_rate = 22050
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes = PackedByteArray()
	for i in range(6600):
		var t = float(i) / 22050.0
		var envelope = pow(maxf(0, 1.0 - t / 0.30), 2)
		var value = int(sin(t * 170 * TAU + sin(t * 50 * TAU)) * sin(t * 420 * TAU) * envelope * 18000)
		bytes.append(value & 255)
		bytes.append((value >> 8) & 255)
	wave.data = bytes
	return wave
