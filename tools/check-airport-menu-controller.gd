extends SceneTree
## Run: godot --headless --path . --script tools/check-airport-menu-controller.gd
## Exercises real scene changes, normal input and physics without visual capture.
var failures: Array[String] = []
var checks = 0
var manager
var peers
var lobby
const CONFIG_PATH = "user://airport_menu_controller_check.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("MENU_CONTROLLER_CHECK: " + description)

func _frames(count: int = 3) -> void:
	for _frame in count: await physics_frame
	await process_frame

func _key(key: Key, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _wait_scene(path: String) -> bool:
	for _attempt in 200:
		if current_scene != null and current_scene.scene_file_path == path:
			await _frames()
			return true
		await create_timer(0.025).timeout
	_check(false, "Scene transition reached " + path)
	return false

func _run() -> void:
	manager = root.get_node("SceneManager")
	peers = root.get_node("PeerManager")
	lobby = root.get_node("LobbyManager")
	create_timer(40.0).timeout.connect(func(): push_error("MENU_CONTROLLER_CHECK timeout"); quit(2))
	if root.has_meta("airport_splash_seen"): root.remove_meta("airport_splash_seen")
	var menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	menu.settings.config_path = CONFIG_PATH
	root.add_child(menu)
	current_scene = menu
	await _frames()
	var args = OS.get_cmdline_user_args()
	if args.has("--airport-menu-controller-host") or args.has("--airport-menu-controller-client"):
		_check(menu.page_name == "main" and not menu.splash.visible, "Airport automation prefix bypasses splash")
		await _network_check(menu, args.has("--airport-menu-controller-host"))
		return
	_check(menu.page_name == "splash" and menu.splash.visible, "First entry displays splash")
	_key(KEY_ENTER, true)
	await _frames()
	_key(KEY_ENTER, false)
	_check(menu.page_name == "main" and not menu.splash.visible, "Keyboard dismisses splash into menu")
	_check(menu.pages.main.get_node("Solo").is_visible_in_tree(), "Solo is reachable after splash")
	menu.pages.main.get_node("Controls").pressed.emit()
	_check(menu.page_name == "controls", "Controls page opens via button")
	_key(KEY_ESCAPE, true)
	await _frames()
	_key(KEY_ESCAPE, false)
	_check(menu.page_name == "main", "Escape returns from controls")
	menu.pages.main.get_node("Settings").pressed.emit()
	menu.pages.settings.get_node("MasterVolume").value = 0.0
	menu.pages.settings.get_node("MouseSensitivity").value = 1.75
	menu.pages.settings.get_node("Fullscreen").button_pressed = true
	_check(AudioServer.is_bus_mute(0), "Master zero really mutes audio")
	_check(is_equal_approx(float(Engine.get_meta("airport_mouse_sensitivity")), 1.75), "Sensitivity applies live")
	var restored = load("res://scenes/menu/airport_settings.gd").new()
	restored.config_path = CONFIG_PATH
	restored.load_settings()
	_check(restored.fullscreen and is_equal_approx(restored.mouse_sensitivity, 1.75) and restored.master_volume == 0.0, "Settings persist and reload")
	menu.pages.settings.get_node("MasterVolume").value = 0.5
	_check(not AudioServer.is_bus_mute(0) and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.5) < 0.01, "Nonzero volume changes real audio bus gain")
	menu.pages.settings.get_node("Back").pressed.emit()
	_check(menu.page_name == "main", "Settings Back returns to menu")
	menu.hide()
	await _controller_checks()
	menu.show()
	# Real template ENet creation and its real lobby scene transition.
	menu.pages.main.get_node("StartGame").pressed.emit()
	_check(root.multiplayer.multiplayer_peer is ENetMultiplayerPeer, "Host button creates ENet peer")
	if not await _wait_scene("res://scenes/menu/lobby/Lobby.tscn"): return _finish()
	_check(lobby.current_lobby.state == Lobby.State.LOBBY, "Host reaches usable template lobby")
	lobby.disconnection_reason = "Menu/controller check disconnect"
	manager.go_to_main_menu()
	if not await _wait_scene("res://scenes/menu/MainMenu.tscn"): return _finish()
	menu = current_scene
	_check(menu.page_name == "main", "Return bypasses splash")
	_check(lobby.disconnection_reason == "", "Disconnect reason is consumed")
	var dialogs = menu.find_children("*", "AcceptDialog", true, false)
	_check(dialogs.size() == 1 and dialogs[0].dialog_text == "Menu/controller check disconnect", "Disconnect dialog survives menu redesign")
	if not dialogs.is_empty(): dialogs[0].hide()
	menu.pages.main.get_node("Solo").pressed.emit()
	_check(root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Solo initializes explicit offline peer")
	if not await _wait_scene("res://scenes/level/airport/AirportBaggage.tscn"): return _finish()
	_check(current_scene.chef is AirportChef, "Solo airport uses AirportChef")
	_check(current_scene.sim.players.has(1), "Solo airport registers authoritative player")
	var game = current_scene
	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	await _frames(20)
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	_check(game.sim.players[1].stamina < 99.0, "Normal sprint intent spends authoritative model stamina")
	_check(absf(game.chef.stamina - game.sim.players[1].stamina) < 1.0, "Game copies authoritative stamina to controller")
	await _frames(4)
	_key(KEY_SPACE, true)
	await _frames(10)
	_key(KEY_SPACE, false)
	_check(game.sim.players[1].jump_left > 0.0 and game.chef.position.y > 0.1, "Normal Space reaches model jump action and physical controller")
	manager.go_to_main_menu()
	if not await _wait_scene("res://scenes/menu/MainMenu.tscn"): return _finish()
	current_scene.pages.main.get_node("Sushi").pressed.emit()
	if not await _wait_scene("res://scenes/level/sushi/RevolvingSushi.tscn"): return _finish()
	_check(current_scene.chef is SushiChef and not current_scene.chef is AirportChef, "Previous sushi scene retains original controller")
	_finish()

func _network_check(menu, host: bool) -> void:
	if host:
		menu.pages.main.get_node("StartGame").pressed.emit()
	else:
		menu.join_ip_input.text = "127.0.0.1"
		menu.pages.main.get_node("JoinHBox/JoinGame").pressed.emit()
	if not await _wait_scene("res://scenes/menu/lobby/Lobby.tscn"): return _finish()
	var ready = false
	for _attempt in 300:
		var players = lobby.get_all_players()
		if players.size() == 2 and players.all(func(player): return lobby.is_player_ready_for_gameplay(player.peer_id)):
			ready = true
			break
		await create_timer(0.025).timeout
	_check(ready, "Host and Join buttons reach a synchronized two-player lobby")
	print("MENU_NETWORK_CHECK role=", "host" if host else "client", " ready=", ready)
	await create_timer(1.0 if host else 0.5).timeout
	_finish()

func _controller_checks() -> void:
	var world = Node3D.new()
	root.add_child(world)
	var floor_body = StaticBody3D.new()
	var floor_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	floor_shape.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var chef = load("res://scripts/airport/airport_chef.gd").new()
	chef.automated = true # No mouse capture in the headless check.
	chef.position.y = 0.03
	world.add_child(chef)
	chef.automated = false
	await _frames(8)
	_check(chef.is_on_floor(), "Controller settles on physical floor")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(25, 0)
	var yaw = chef.rotation.y
	chef._unhandled_input(motion)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_check(absf(chef.rotation.y - yaw + 25.0 * 0.0025 * 1.75) < 0.0001, "Mouse movement uses saved airport sensitivity")
	else:
		print("MENU_CONTROLLER_CHECK skipped captured mouse delta: display backend does not capture")
	chef.rotation.y = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_key(KEY_W, true)
	await _frames(4)
	var walk_speed = Vector2(chef.velocity.x, chef.velocity.z).length()
	_check(walk_speed > 3.3, "Ordinary W key moves at walk pace")
	_key(KEY_SHIFT, true)
	await _frames(4)
	_check(chef.sprinting and chef.velocity.length() > walk_speed * 1.4, "Ordinary Shift sprints")
	_check(chef.stamina == 100.0, "Controller does not spend/regenerate model stamina")
	chef.stamina = 0.0
	await _frames()
	_check(not chef.sprinting and chef.velocity.length() < walk_speed * 1.1, "Exhaustion blocks sprint")
	chef.stamina = 10.0
	await _frames()
	_check(not chef.sprinting, "Sprint exhaustion recovery threshold is respected")
	chef.stamina = 100.0
	_key(KEY_SHIFT, false)
	chef.health = 25.0
	await _frames()
	_check(chef.velocity.length() < walk_speed * 0.7, "Injury slows movement")
	chef.health = 100.0
	_key(KEY_W, false)
	_key(KEY_CTRL, true)
	await _frames()
	_check(chef.crouching and is_equal_approx(chef._body_shape.shape.height, 1.0) and chef.camera.position.y < 1.0, "Ctrl lowers actual capsule and camera")
	var ceiling = StaticBody3D.new()
	var ceiling_shape = CollisionShape3D.new()
	var ceiling_box = BoxShape3D.new()
	ceiling_box.size = Vector3(3, 0.2, 3)
	ceiling_shape.shape = ceiling_box
	ceiling.add_child(ceiling_shape)
	ceiling.position = chef.position + Vector3(0, 1.35, 0)
	world.add_child(ceiling)
	await _frames()
	_key(KEY_CTRL, false)
	await _frames()
	_check(chef.crouching, "Ceiling obstructs standing after Ctrl release")
	ceiling.queue_free()
	await _frames()
	_check(not chef.crouching and is_equal_approx(chef._body_shape.shape.height, 1.7) and is_equal_approx(chef.camera.position.y, 1.62), "Clearance restores capsule/camera automatically")
	chef.stamina = 0.0
	await _frames()
	_key(KEY_SPACE, true)
	await _frames()
	_key(KEY_SPACE, false)
	_check(not chef.requested_jump and chef.is_on_floor(), "Exhaustion blocks normal Space jump")
	chef.stamina = 100.0
	await _frames()
	_key(KEY_SPACE, true)
	await _frames(4)
	_key(KEY_SPACE, false)
	_check(chef.requested_jump and chef.position.y > 0.1, "Space jumps physically and latches model intent")
	chef.requested_jump = false
	await _frames(55)
	_check(chef.is_on_floor() and not chef.requested_jump, "Jump lands; report latch stays cleared")
	chef.automated = true
	var target = chef.position + Vector3(0.5, 0, 0)
	chef.navigate(target, target + Vector3.FORWARD)
	await _frames(15)
	_check(not chef.walking and chef.position.distance_to(target) < 0.1, "Inherited navigate/face automation remains compatible")
	world.queue_free()
	await _frames()

func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG_PATH))
	print("MENU_CONTROLLER_CHECK checks=", checks, " failures=", failures.size(), " details=", failures)
	quit(0 if failures.is_empty() else 1)
