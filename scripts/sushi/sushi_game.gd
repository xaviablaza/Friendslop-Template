extends Node3D
## Presentation and server-authoritative interaction boundary.
## The template retains ownership of ENet, lobby and scene readiness.

const Simulation = preload("res://scripts/sushi/sushi_simulation.gd")
var sim = Simulation.new()
var room: SushiRoom
var chef: SushiChef
var hud: SushiHUD
var local_id: int = 1
var poses: Dictionary = {}
var avatars: Dictionary = {}
var belt_nodes: Dictionary = {}
var belt_stale: Dictionary = {}
var tray_signature = ""
var dirty_count = -1
var clock = 0.0
var net_clock = 0.0
var feedback = ""
var feedback_left = 0.0
var target: Dictionary = {}
var tour: Node

func _ready() -> void:
	local_id = multiplayer.get_unique_id()
	room = SushiRoom.new()
	add_child(room)
	room.build()
	chef = SushiChef.new()
	chef.position = Vector3(0.0 if local_id == 1 else 0.8, 0.03, -0.3)
	add_child(chef)
	hud = SushiHUD.new()
	add_child(hud)
	hud.upgrade_requested.connect(func(kind): request_action("upgrade_" + kind))
	hud.menu_requested.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; SceneManager.go_to_main_menu())
	$NetworkReady.player_ready_for_gameplay.connect(_register_chef)
	multiplayer.peer_disconnected.connect(_remove_chef)
	if multiplayer.is_server():
		_register_chef(local_id)
	SceneManager.mark_scene_as_loaded(self)
	if OS.get_cmdline_user_args().has("--sushi-tour"):
		tour = load("res://scripts/sushi/sushi_playtest.gd").new()
		tour.game = self
		add_child(tour)
	elif OS.get_cmdline_user_args().has("--sushi-net-host") or OS.get_cmdline_user_args().has("--sushi-net-client"):
		tour = load("res://scripts/sushi/sushi_network_smoke.gd").new()
		tour.game = self
		add_child(tour)

func _register_chef(peer_id: int) -> void:
	if not _session_active() or not multiplayer.is_server() or sim.players.has(peer_id):
		return
	sim.add_player(peer_id)
	poses[peer_id] = {"position": Vector3(0.0 if peer_id == 1 else 0.8, 0.03, -0.3), "yaw": 0.0}
	print("SUSHI_READY peer=", peer_id)

func _remove_chef(peer_id: int) -> void:
	if _session_active() and multiplayer.is_server():
		sim.remove_player(peer_id)
		poses.erase(peer_id)

func _session_active() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _process(delta: float) -> void:
	# A disconnected ENet object can survive the menu fade. Do not query its
	# authority or send RPCs while LobbyManager completes that transition.
	if not _session_active():
		chef.input_enabled = false
		return
	clock += delta
	feedback_left = maxf(0, feedback_left - delta)
	if multiplayer.is_server():
		sim.update(delta)
		poses[local_id] = {"position": chef.position, "yaw": chef.rotation.y}
	net_clock += delta
	if net_clock >= 0.08 and multiplayer.multiplayer_peer:
		net_clock = 0
		if multiplayer.is_server():
			for id in sim.players:
				if id != local_id and multiplayer.get_peers().has(id):
					_receive_snapshot.rpc_id(id, sim.snapshot(), poses)
		elif sim.players.has(local_id):
			_move_chef.rpc_id(1, chef.position, chef.rotation.y)
	room.animate_belt(clock, sim.belt_speed)
	_update_belt()
	_update_customers()
	_update_hands()
	_update_avatars()
	target = interaction_target()
	hud.refresh(sim, local_id, target.get("prompt", "Look at a station, then press E.\nMatch the orders on the right."), feedback if feedback_left > 0 else "")

func interaction_target() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for i in range(3):
		var prep_seconds = "0.65" if sim.upgrades.prep else "1.5"
		candidates.append({"point": SushiRoom.STATIONS[i], "action": "prepare", "recipe": i, "prompt": "[E] Prepare %s\nOne clean plate / %s sec" % [sim.RECIPES[i], prep_seconds]})
	candidates.append({"point": SushiRoom.LOAD_POINT, "action": "load", "prompt": "[E] Load first tray plate\n[F] Clear oldest stale plate"})
	candidates.append({"point": SushiRoom.WASH_POINT, "action": "wash", "prompt": "[E] Wash returned plates\nReturn them to clean stock"})
	candidates.append({"point": SushiRoom.SHOP_POINT, "action": "shop", "prompt": "[E / TAB] Buy an upgrade\nBigger trays change how you work"})
	var best: Dictionary = {}
	var best_score = 0.55
	for candidate in candidates:
		var direction: Vector3 = candidate.point - chef.camera.global_position
		if direction.length() > 2.5:
			continue
		var score = (-chef.camera.global_basis.z).dot(direction.normalized())
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _unhandled_input(event: InputEvent) -> void:
	if not _session_active():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
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
			if chef.position.distance_to(SushiRoom.SHOP_POINT) < 2.5:
				_toggle_shop(not hud.shop.visible)
			else:
				_show_feedback("Walk to the upgrade terminal on the right.")
		KEY_E:
			if not hud.shop.visible and chef.input_enabled and not target.is_empty():
				if target.action == "shop":
					_toggle_shop(true)
				else:
					request_action(target.action, int(target.get("recipe", -1)))
		KEY_F:
			if not hud.shop.visible and chef.input_enabled:
				request_action("clear")
		KEY_1, KEY_2, KEY_3:
			if hud.shop.visible:
				request_action("upgrade_" + ["tray", "prep", "washer"][event.physical_keycode - KEY_1])
		KEY_N:
			if multiplayer.is_server() and sim.shift_finished:
				sim.next_shift()

func _toggle_shop(open: bool) -> void:
	hud.shop.visible = open
	hud.pointer_panel.visible = false
	chef.input_enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func request_action(action: String, recipe: int = -1) -> void:
	if not _session_active():
		return
	if multiplayer.is_server():
		_perform_action(local_id, action, recipe)
	else:
		_request_action.rpc_id(1, action, recipe)

@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: String, recipe: int) -> void:
	if _session_active() and multiplayer.is_server():
		_perform_action(multiplayer.get_remote_sender_id(), action, recipe)

func _perform_action(peer_id: int, action: String, recipe: int) -> void:
	if not _session_active():
		return
	if not sim.players.has(peer_id) or not poses.has(peer_id):
		return
	var station = Vector3.ZERO
	match action:
		"prepare":
			if recipe < 0 or recipe >= 3:
				return
			station = SushiRoom.STATIONS[recipe]
		"load", "clear": station = SushiRoom.LOAD_POINT
		"wash": station = SushiRoom.WASH_POINT
		"upgrade_tray", "upgrade_prep", "upgrade_washer": station = SushiRoom.SHOP_POINT
		_: return
	var at: Vector3 = poses[peer_id].position + Vector3(0, 1.0, 0)
	var response: String
	if at.distance_to(station) > 2.5:
		response = "Move closer to that station."
	else:
		response = sim.act(peer_id, action, recipe)
	if peer_id == local_id:
		_show_feedback(response)
	elif multiplayer.get_peers().has(peer_id):
		_action_feedback.rpc_id(peer_id, response)
	print("SUSHI_ACTION peer=%d action=%s result=%s" % [peer_id, action, response])

func _show_feedback(text: String) -> void:
	feedback = text
	feedback_left = 3.0

@rpc("authority", "call_remote", "reliable")
func _action_feedback(text: String) -> void:
	_show_feedback(text)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _move_chef(at: Vector3, yaw: float) -> void:
	if not _session_active() or not multiplayer.is_server() or not at.is_finite() or not is_finite(yaw):
		return
	var sender = multiplayer.get_remote_sender_id()
	if not sim.players.has(sender):
		return
	# Prototype room boundary. Production movement reconciliation is out of scope.
	if absf(at.x) > 5 or absf(at.z) > 4 or at.y < -0.5 or at.y > 0.5:
		return
	poses[sender] = {"position": at, "yaw": yaw}

@rpc("authority", "call_remote", "reliable", 2)
func _receive_snapshot(data: Dictionary, player_poses: Dictionary) -> void:
	sim.apply_snapshot(data)
	poses = player_poses

func _update_belt() -> void:
	var active: Dictionary = {}
	for item in sim.belt:
		var id = int(item.id)
		active[id] = true
		if belt_nodes.has(id) and belt_stale[id] != item.stale:
			belt_nodes[id].queue_free()
			belt_nodes.erase(id)
		if not belt_nodes.has(id):
			var node = SushiRoom.plate(int(item.recipe), bool(item.stale))
			add_child(node)
			belt_nodes[id] = node
			belt_stale[id] = item.stale
		belt_nodes[id].position = SushiRoom.belt_position(item.t) + Vector3(0, 0.04, 0)
		belt_nodes[id].rotation.y = float(item.t) * TAU
	for id in belt_nodes.keys():
		if not active.has(id):
			belt_nodes[id].queue_free()
			belt_nodes.erase(id)
			belt_stale.erase(id)

func _update_customers() -> void:
	for i in range(sim.customers.size()):
		var customer: Dictionary = sim.customers[i]
		var recipe = int(customer.recipe)
		room.customer_labels[i].text = "SEAT %02d\n%s\n%ds" % [i + 1, sim.RECIPES[recipe], int(ceil(customer.patience))]
		room.customer_labels[i].modulate = SushiRoom.FOOD_COLORS[recipe].lightened(0.15)
		room.customer_lights[i].material_override = SushiRoom.material(SushiRoom.FOOD_COLORS[recipe])
	if dirty_count != sim.dirty_plates:
		dirty_count = sim.dirty_plates
		for child in room.wash_stack.get_children():
			child.queue_free()
		for i in range(mini(dirty_count, 12)):
			var mesh = MeshInstance3D.new()
			var plate_mesh = CylinderMesh.new()
			plate_mesh.top_radius = 0.27
			plate_mesh.bottom_radius = 0.25
			plate_mesh.height = 0.045
			mesh.mesh = plate_mesh
			mesh.material_override = SushiRoom.material(Color("b7aa92"))
			mesh.position.y = i * 0.05
			room.wash_stack.add_child(mesh)

func _update_hands() -> void:
	var state: Dictionary = sim.players.get(local_id, {"tray": []})
	var signature = str(state.tray)
	if signature == tray_signature:
		return
	tray_signature = signature
	for child in chef.hand.get_children():
		child.queue_free()
	for i in range(state.tray.size()):
		var dish = SushiRoom.plate(state.tray[i])
		dish.position = Vector3((i % 2) * 0.53 - 0.14, (i / 2) * 0.07, -(i / 2) * 0.48)
		dish.scale = Vector3.ONE * 0.8
		chef.hand.add_child(dish)

func _update_avatars() -> void:
	for id in poses:
		if id == local_id:
			continue
		if not avatars.has(id):
			var avatar = Node3D.new()
			var body = MeshInstance3D.new()
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.23
			capsule.height = 1.2
			body.mesh = capsule
			body.material_override = SushiRoom.material(Color("e2c878"))
			body.position.y = 0.7
			avatar.add_child(body)
			var head = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			head.mesh = sphere
			head.material_override = SushiRoom.material(Color("b7bab2"))
			head.position.y = 1.52
			avatar.add_child(head)
			add_child(avatar)
			avatars[id] = avatar
		avatars[id].position = poses[id].position
		avatars[id].rotation.y = poses[id].yaw
	for id in avatars.keys():
		if not poses.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
