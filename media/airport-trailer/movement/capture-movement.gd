extends SceneTree
## Fresh actual-engine trailer source. External harness only; no app edits.
## Buttons/signals and InputEventKey drive the ordinary UI/controller/model.
const OUT = "/home/administrator/Friendslop-Template-airport-baggage/artifacts/trailer-v2/movement/"
const FPS = 24.0
var checks: Array = []
var timeline: Array = []
var phase: Dictionary = {}
var manager
var game
var menu
var walk_speed = 0.0
var initial_stamina = 100.0
var peak_jump = 0.0
var config_path = OUT + "capture-settings.cfg"
var airport_scene_cache

func _initialize() -> void:
	_run.call_deferred()

func _hold(seconds: float) -> void:
	for i in roundi(seconds * FPS):
		await process_frame

func _key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(ok: bool, claim: String, observed: Dictionary = {}) -> void:
	checks.append({"passed": ok, "claim": claim, "frame": Engine.get_process_frames(), "time": Engine.get_process_frames() / FPS, "observed": observed})
	print("CAPTURE_CHECK ", JSON.stringify(checks.back()))

func _phase(id: String, description: String, crop: Array = []) -> void:
	if not phase.is_empty():
		phase.end_frame = Engine.get_process_frames()
		phase.end = phase.end_frame / FPS
		timeline.append(phase)
	phase = {"id": id, "description": description, "start_frame": Engine.get_process_frames(), "start": Engine.get_process_frames() / FPS, "crop_xywh": crop}

func _snap(id: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + id + ".png")

func _wait_scene(path: String) -> bool:
	for i in 160:
		if current_scene != null and current_scene.scene_file_path == path and not manager.is_loading:
			await _hold(0.35)
			return true
		await process_frame
	_check(false, "Actual scene transition: " + path)
	return false

func _finish() -> void:
	_phase("end", "End")
	var passed = checks.all(func(c): return c.passed)
	var report = {"passed": passed, "checks": checks, "automation": "Actual menu Button signals, real HSlider value_changed, normal InputEventKey held input; AirportChef.automated=false during movement.", "staging": "Safe aisle starting position/yaw and a desk-facing crouch/jump starting position only. No model health/stamina/cash counters set; random ordinary arrivals remain enabled.", "revision": "663cb3a2fc8f61a664f3b1075cfd86485ad9cf37", "fps": FPS, "config": config_path, "user_preferences_untouched": true}
	var f = FileAccess.open(OUT + "checks.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	f = FileAccess.open(OUT + "timeline.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": FPS, "time_origin": "Movie Maker frame 0; frame indices from Engine.get_process_frames()", "scenes": timeline}, "\t"))
	f.close()
	DirAccess.remove_absolute(config_path)
	quit(0 if passed else 1)

func _run() -> void:
	manager = root.get_node("SceneManager")
	airport_scene_cache = load("res://scenes/level/airport/AirportBaggage.tscn")
	# Prevent a native grab before ready, not controller input handling.
	node_added.connect(func(n):
		if n is CharacterBody3D and "automated" in n: n.automated = true)
	create_timer(65.0).timeout.connect(func(): _check(false,"Capture watchdog"); _finish())
	if root.has_meta("airport_splash_seen"): root.remove_meta("airport_splash_seen")
	DirAccess.remove_absolute(config_path)
	menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	menu.settings.config_path = config_path
	root.add_child(menu)
	current_scene = menu
	_phase("splash", "Fresh first-entry airport splash")
	_check(menu.page_name == "splash", "Real first-entry splash displayed")
	await _hold(1.7)
	await _snap("01-splash")
	await _hold(0.65)
	_phase("main_menu", "Play solo / Host co-op / Join / Settings / Controls are actual menu options")
	_check(menu.page_name == "main" and menu.pages.main.visible, "Splash timer opens real main menu")
	for path in ["Solo", "StartGame", "JoinHBox/JoinGame", "Settings", "Controls"]:
		_check(menu.pages.main.get_node(path).is_visible_in_tree(), "Visible actual button: " + path)
	menu.pages.main.get_node("StartGame").grab_focus()
	await _hold(0.9)
	menu.pages.main.get_node("JoinHBox/JoinGame").grab_focus()
	await _hold(0.9)
	await _snap("02-menu")
	menu.pages.main.get_node("Settings").pressed.emit()
	_phase("settings_before", "Actual saved settings panel, before slider adjustments")
	await _hold(1.0)
	await _snap("03-settings-before")
	menu.pages.settings.get_node("MouseSensitivity").value = 1.45
	menu.pages.settings.get_node("MasterVolume").value = 0.55
	_phase("settings_adjusted", "Actual sensitivity 1.45x and master volume 55%, applied and saved to isolated capture config")
	await _hold(1.8)
	var saved = load("res://scenes/menu/airport_settings.gd").new()
	saved.config_path = config_path
	saved.load_settings()
	_check(is_equal_approx(saved.mouse_sensitivity, 1.45) and is_equal_approx(saved.master_volume, 0.55), "Actual settings saved and reloaded", {"sensitivity": saved.mouse_sensitivity, "volume": saved.master_volume})
	_check(is_equal_approx(float(Engine.get_meta("airport_mouse_sensitivity")), 1.45) and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.55) < 0.01, "Settings change real engine input metadata and audio bus gain")
	await _snap("04-settings-adjusted")
	menu.pages.settings.get_node("Back").pressed.emit()
	menu.pages.main.get_node("Controls").pressed.emit()
	_phase("controls", "Actual controls page: sprint, crouch, jump and full game bindings")
	_check(menu.page_name == "controls", "Controls button opens real controls page")
	await _hold(2.4)
	await _snap("05-controls")
	_key(KEY_ESCAPE, true)
	await _hold(0.08)
	_key(KEY_ESCAPE, false)
	await _hold(0.8)
	menu.pages.main.get_node("Solo").pressed.emit()
	_phase("solo_transition", "Actual Play solo button and normal airport scene loading")
	_check(root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Actual Solo initializes OfflineMultiplayerPeer")
	if not await _wait_scene("res://scenes/level/airport/AirportBaggage.tscn"):
		_finish()
		return
	game = current_scene
	game.chef.automated = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.chef.position = Vector3(-7.4, 0.03, 2.1)
	game.chef.rotation.y = -PI / 2.0
	game.chef.camera.rotation.x = -0.08
	_phase("airport_establish", "Live airport first-person view, real unmodified HUD and normal random arrivals")
	await _hold(1.8)
	_check(game.chef.input_enabled and not game.chef.automated and game.chef.is_on_floor(), "Normal local controller enabled and physically grounded")
	await _snap("06-airport")
	_phase("walk", "W held: ordinary walking along clear operator aisle", [18,490,350,110])
	var walk_start = game.chef.position
	_key(KEY_W, true)
	await _hold(1.4)
	walk_speed = Vector2(game.chef.velocity.x, game.chef.velocity.z).length()
	_check(walk_speed > 3.3 and not game.chef.sprinting and game.chef.position.distance_to(walk_start) > 4.0, "W moves real collision-aware actor at ordinary walk pace", {"speed": walk_speed, "distance": game.chef.position.distance_to(walk_start)})
	initial_stamina = float(game.sim.players[1].stamina)
	_phase("sprint_out", "W + Shift held: faster motion with actual authoritative stamina dropping", [18,490,350,110])
	_key(KEY_SHIFT, true)
	await _hold(1.9)
	_check(game.chef.sprinting and game.chef.velocity.length() > walk_speed * 1.4 and game.sim.players[1].stamina < initial_stamina - 20.0, "Shift increases real pace and drains authoritative stamina", {"walk_speed": walk_speed, "sprint_speed": game.chef.velocity.length(), "stamina_before": initial_stamina, "stamina_now": game.sim.players[1].stamina})
	await _snap("07-sprint")
	_key(KEY_W, false)
	game.chef.rotation.y = PI / 2.0
	_key(KEY_W, true)
	_phase("sprint_back", "Continued actual Shift sprint in opposite direction; no stamina overrides", [18,490,350,110])
	await _hold(2.5)
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	var drained = float(game.sim.players[1].stamina)
	_check(drained < 30.0, "Sustained actual sprint visibly reduces stamina below 30", {"stamina": drained})
	await _snap("08-stamina-low")
	_phase("recover", "Standing rest: real stamina regeneration on existing HUD", [18,490,350,110])
	await _hold(2.0)
	_check(game.sim.players[1].stamina > drained + 18.0, "Rest regenerates real model stamina", {"before": drained, "after": game.sim.players[1].stamina})
	await _snap("09-recover")
	# New safe staged shot; subsequent camera/capsule changes are controller-owned.
	game.chef.position = Vector3(2.1, 0.03, 2.6)
	game.chef.rotation.y = 0
	game.chef.camera.rotation.x = -0.12
	await _hold(0.4)
	_phase("stand_before_crouch", "Standing reference at inspection desk; camera 1.62m")
	await _hold(1.1)
	await _snap("10-stand")
	_phase("crouch", "Ctrl held: real physical capsule and first-person camera lower")
	_key(KEY_CTRL, true)
	await _hold(1.8)
	_check(game.chef.crouching and is_equal_approx(game.chef._body_shape.shape.height, 1.0) and is_equal_approx(game.chef.camera.position.y, 0.92), "Ctrl changes real capsule to 1.0m and camera to 0.92m", {"capsule_height": game.chef._body_shape.shape.height, "camera_height": game.chef.camera.position.y})
	await _snap("11-crouch")
	_phase("stand_after_crouch", "Ctrl released: capsule and camera return to standing")
	_key(KEY_CTRL, false)
	await _hold(1.1)
	_check(not game.chef.crouching and is_equal_approx(game.chef._body_shape.shape.height, 1.7) and is_equal_approx(game.chef.camera.position.y, 1.62), "Ctrl release restores physical standing height")
	await _snap("12-stand-restored")
	_phase("jump", "Ordinary Space key: physical jump, model stamina cost, then actual landing", [18,490,350,110])
	var pre_jump_stamina = float(game.sim.players[1].stamina)
	_key(KEY_SPACE, true)
	for i in 7:
		await process_frame
		peak_jump = maxf(peak_jump, game.chef.position.y)
	_key(KEY_SPACE, false)
	_check(peak_jump > 0.6 and game.sim.players[1].jump_left > 0.0 and game.sim.players[1].stamina < pre_jump_stamina - 5.0, "Normal Space creates actual airborne controller jump and model cost", {"height": peak_jump, "stamina_before": pre_jump_stamina, "stamina_after": game.sim.players[1].stamina, "model_jump_left": game.sim.players[1].jump_left})
	await _snap("13-jump-apex")
	await _hold(1.2)
	_check(game.chef.is_on_floor() and game.chef.position.y < 0.05, "Physical jump lands back on actual airport floor", {"y": game.chef.position.y, "grounded": game.chef.is_on_floor()})
	await _snap("14-landing")
	await _hold(0.8)
	_phase("jump_second", "Second ordinary Space jump and complete landing for editorial choice")
	_key(KEY_SPACE, true)
	await _hold(0.25)
	_key(KEY_SPACE, false)
	await _hold(1.7)
	_check(game.chef.is_on_floor(), "Second normal jump completes landing")
	await _snap("15-final")
	await _hold(0.8)
	_finish()
