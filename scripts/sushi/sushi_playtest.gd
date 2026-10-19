extends Node
## Opt-in automated playtest. It walks the real controller and sends real key
## events through the same interaction boundary as a human player. No seeded cash.
var game
var elapsed = 0.0
var checks: Array[String] = []
var overview: Camera3D
var failed = false

func _ready() -> void:
	game.chef.automated = true
	_run.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 165 and not failed:
		fail("Tour exceeded its 165-second safety limit")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(condition: bool, description: String) -> void:
	if not condition:
		fail(description)
		return
	checks.append(description)
	print("PLAYTEST_PASS ", description)

func fail(description: String) -> void:
	failed = true
	push_error("PLAYTEST_FAIL " + description)
	_write_report(false)
	get_tree().quit(1)

func walk(at: Vector3, face: Vector3) -> void:
	game.chef.navigate(at, face)
	var started = elapsed
	while game.chef.walking and elapsed - started < 7:
		await get_tree().physics_frame
	check(game.chef.position.distance_to(at) < 0.22, "Controller reached station at " + str(at))
	await wait(0.45)

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
	await wait(0.18)

func chapter(text: String) -> void:
	game.hud.chapter.text = "AUTOMATED PLAYTEST  /  " + text

func _run() -> void:
	chapter("01  THE RESTAURANT")
	overview = Camera3D.new()
	overview.position = Vector3(9, 8.2, 11)
	overview.fov = 65
	game.add_child(overview)
	overview.look_at(Vector3(0, 0.7, 0))
	overview.current = true
	await wait(3)
	await screenshot("overview")
	game.chef.camera.current = true
	chapter("02  PREPARE → CARRY → LOAD")
	for i in range(5):
		var customer: Dictionary = game.sim.customers[3]
		var recipe = int(customer.recipe)
		# Forecast the next seat's request if patience expires during this trip.
		if float(customer.patience) < 9:
			recipe = (recipe + 1) % 3
		await prepare(recipe)
		await load_tray()
		game.chef.aim_target = SushiRoom.belt_position(0.875) + Vector3(0, 0.6, 0)
		await wait(5)
	check(game.sim.served >= 3, "Matching customers took at least three real belt plates")
	check(game.sim.money >= 24, "Customer purchases funded the serving-tray upgrade")
	chapter("03  BUY A HANDLING UPGRADE")
	await walk(Vector3(0.95, 0, 1.5), SushiRoom.SHOP_POINT)
	await key(KEY_E)
	check(game.hud.shop.visible, "Upgrade terminal opened through the E interaction")
	await key(KEY_1)
	check(game.sim.upgrades.tray == 1, "Purchased the tray upgrade using earned money")
	check(game.sim.players[game.local_id].capacity == 3, "Upgrade increased carrying capacity from one to three")
	await screenshot("upgrade")
	await key(KEY_TAB)
	chapter("04  BATCH THREE DISHES")
	for recipe in range(3):
		await prepare(recipe)
	check(game.sim.players[game.local_id].tray.size() == 3, "Chef physically carried a three-dish batch")
	await screenshot("tray")
	await load_tray()
	chapter("05  RETURN → WASH → REUSE")
	await wait(5)
	await walk(Vector3(0.9, 0, -0.3), SushiRoom.WASH_POINT)
	var clean_before = int(game.sim.clean_plates)
	await key(KEY_E)
	check(game.sim.clean_plates > clean_before, "Washing returned dirty plates to usable clean stock")
	await screenshot("washing")
	chapter("06  WATCH THE SHARED SUPPLY LOOP")
	overview.current = true
	await wait(6)
	game.chef.camera.current = true
	await walk(Vector3(0, 0, -2.5), SushiRoom.LOAD_POINT)
	chapter("07  SHIFT RESULT")
	while not game.sim.shift_finished:
		await wait(0.25)
	check(game.sim.shift_finished, "The real 120-second shift reached its end")
	await wait(2)
	await screenshot("shift")
	await key(KEY_N)
	check(game.sim.day == 2 and not game.sim.shift_finished, "N advanced to the next shift without resetting the restaurant")
	chapter("PLAYTEST PASSED  /  READY FOR HANDS-ON TESTING")
	await wait(3)
	_write_report(true)
	get_tree().quit(0)

func prepare(recipe: int) -> void:
	await walk(Vector3(-0.98, 0, SushiRoom.STATIONS[recipe].z), SushiRoom.STATIONS[recipe])
	check(game.interaction_target().get("recipe", -1) == recipe, "Look targeting selected recipe " + str(recipe))
	var before = int(game.sim.players[game.local_id].tray.size())
	await key(KEY_E)
	await wait(1.65)
	check(game.sim.players[game.local_id].tray.size() == before + 1, "Prepared " + game.sim.RECIPES[recipe] + " through real interaction")

func load_tray() -> void:
	await walk(Vector3(0, 0, -2.5), SushiRoom.LOAD_POINT)
	check(game.interaction_target().get("action", "") == "load", "Look targeting selected the loading point")
	var count = int(game.sim.players[game.local_id].tray.size())
	for i in range(count):
		await key(KEY_E)
	check(game.sim.players[game.local_id].tray.is_empty(), "Loaded carried dishes onto the moving belt")

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	get_viewport().get_texture().get_image().save_png("res://artifacts/sushi-" + name + ".png")

func _write_report(passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var report = {"passed": passed, "automated_inputs": true, "elapsed_seconds": elapsed, "checks": checks, "served": game.sim.served, "money": game.sim.money, "day": game.sim.day, "upgrades": game.sim.upgrades}
	var file = FileAccess.open("res://artifacts/playtest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PLAYTEST_RESULT ", JSON.stringify(report))
