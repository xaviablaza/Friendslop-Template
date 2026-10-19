extends SceneTree
## Real two-process regression for host loss during the scene-transition fade.
var role = "host"
var checks: Array[String] = []
var done = false
var game
var disconnected = false

func _initialize() -> void:
	role = "client" if OS.get_cmdline_user_args().has("--host-loss-client") else "host"
	_run.call_deferred()

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func check(condition: bool, message: String) -> void:
	if not condition:
		finish(false, message)
	else:
		checks.append(message)
		print("HOST_LOSS_PASS ", role, " ", message)

func _run() -> void:
	create_timer(25).timeout.connect(func(): finish(false, "Host-loss check timed out"))
	change_scene_to_file("res://scenes/menu/MainMenu.tscn")
	await wait(0.3)
	var peers = root.get_node("PeerManager")
	# Load after the project autoloads exist (this file is a --script entrypoint).
	var provider = load("res://scripts/multiplayer/network/providers/enet_network_provider.gd").new("127.0.0.1", 17108)
	peers.set_provider(provider)
	if role == "host":
		peers.host_game()
	else:
		peers.join_game()
	while not current_scene.scene_file_path.ends_with("Lobby.tscn"):
		await wait(0.1)
	check(true, "Template lobby connected")
	if role == "host":
		while root.get_node("LobbyManager").get_all_players().size() < 2:
			await wait(0.1)
		await wait(0.6)
		current_scene.get_node("Lobby")._on_start_btn_pressed()
	while not current_scene.scene_file_path.ends_with("RevolvingSushi.tscn"):
		await wait(0.1)
	await wait(0.8)
	game = current_scene
	check(game.sim.players.size() == 2, "Both chefs synchronized into gameplay")
	if role == "host":
		await wait(5)
		game.hud.menu_requested.emit()
		await wait(1.5)
		check(current_scene.scene_file_path.ends_with("MainMenu.tscn"), "Host returned to main menu")
	else:
		root.multiplayer.server_disconnected.connect(_host_disconnected)
		game.chef.automated = true
		game.chef.navigate(Vector3(-0.98, 0, -1.4), SushiRoom.STATIONS[0])
		await wait(2)
		game.request_action("prepare", 0)
		await wait(2)
		check(game.sim.players[game.local_id].tray.size() == 1, "Client prepared a real synchronized dish before host loss")
		while not disconnected:
			await wait(0.02)
		await wait(1)
		check(current_scene.scene_file_path.ends_with("MainMenu.tscn"), "Host loss returned client to main menu")
		check(root.multiplayer.multiplayer_peer == null, "Main menu cleaned up the disconnected peer")
	finish(true, "Graceful host-loss transition")

func _host_disconnected() -> void:
	disconnected = true
	check(not game._session_active(), "Disconnected ENet peer is not a gameplay authority")
	# Reproduce a key/action arriving during the fade, before the old scene dies.
	game.request_action("prepare", 0)
	game._process(0.016)
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	game._unhandled_input(event)
	check(not game.chef.input_enabled, "Gameplay input and networking stopped during the disconnect fade")

func finish(passed: bool, message: String) -> void:
	if done:
		return
	done = true
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var report = {"passed": passed, "role": role, "checks": checks, "message": message}
	var file = FileAccess.open("res://artifacts/host-loss-" + role + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("HOST_LOSS_RESULT ", JSON.stringify(report))
	quit(0 if passed else 1)
