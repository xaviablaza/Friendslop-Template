extends Node
## Two actual ENet processes exercise the template lobby, scene readiness,
## client RPC interactions, shared economy/snapshots and disconnect cleanup.
var game
var elapsed = 0.0
var done = false
var checks: Array[String] = []

func _ready() -> void:
	game.chef.automated = true
	if game.multiplayer.is_server():
		_host.call_deferred()
	else:
		_client.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 45 and not done:
		finish(false, "Network smoke exceeded 45 seconds")

func verify(condition: bool, message: String) -> void:
	if not condition:
		finish(false, message)
	else:
		checks.append(message)
		print("NETWORK_PASS ", message)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _host() -> void:
	while game.sim.players.size() < 2:
		await wait(0.1)
	verify(game.sim.players.size() == 2, "Two peers entered the sushi scene through template readiness")
	while game.sim.served < 1:
		await wait(0.1)
	verify(game.sim.money >= 8, "Client-loaded sushi produced server-owned shared earnings")
	while game.sim.players.size() > 1:
		await wait(0.1)
	verify(game.sim.players.size() == 1, "Disconnect removed the remote chef from shared simulation")
	finish(true, "ENet host completed")

func _client() -> void:
	while not game.sim.players.has(game.local_id):
		await wait(0.1)
	verify(game.sim.players.size() == 2, "Client received both chefs in authoritative snapshot")
	game.request_action("load")
	await wait(0.4)
	verify(game.feedback == "Move closer to that station.", "Server rejected a remote interaction outside station range")
	await walk(Vector3(-0.98, 0, -1.4), SushiRoom.STATIONS[0])
	game.request_action("prepare", 0)
	await wait(2)
	verify(game.sim.players[game.local_id].tray.size() == 1, "Client preparation RPC returned a synchronized carried plate")
	await walk(Vector3(0, 0, -2.5), SushiRoom.LOAD_POINT)
	game.request_action("load")
	while game.sim.served < 1:
		await wait(0.1)
	verify(game.sim.money >= 8 and game.sim.dirty_plates == 1, "Client received shared earnings and dirty-plate return")
	finish(true, "ENet client completed")

func walk(at: Vector3, look_at_point: Vector3) -> void:
	game.chef.navigate(at, look_at_point)
	var start = elapsed
	while game.chef.walking and elapsed - start < 6:
		await get_tree().physics_frame
	verify(game.chef.position.distance_to(at) < 0.22, "Remote controller reached " + str(at))
	await wait(0.35)

func finish(passed: bool, message: String) -> void:
	if done:
		return
	done = true
	var role = "host" if game.multiplayer.is_server() else "client"
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var result = {"passed": passed, "role": role, "checks": checks, "message": message, "elapsed": elapsed, "money": game.sim.money, "served": game.sim.served}
	var file = FileAccess.open("res://artifacts/network-" + role + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("NETWORK_RESULT ", JSON.stringify(result))
	get_tree().quit(0 if passed else 1)
