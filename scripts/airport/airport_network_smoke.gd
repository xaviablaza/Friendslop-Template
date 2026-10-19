extends Node
## Two actual peers exercise authoritative baggage ownership and shared rewards.
var game
var elapsed = 0.0
var done = false
var checks: Array[String] = []

func _ready() -> void:
	game.chef.automated = true
	if game.multiplayer.is_server(): _host.call_deferred()
	else: _client.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 65 and not done: finish(false,"Airport network check timed out")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(ok: bool, text: String) -> void:
	if not ok: finish(false,text)
	else:
		checks.append(text)
		print("AIRPORT_NETWORK_PASS ",text)

func walk(at: Vector3, look: Vector3) -> void:
	game.chef.navigate(at,look)
	var start = elapsed
	while game.chef.walking and elapsed-start < 10: await get_tree().physics_frame
	check(game.chef.position.distance_to(at)<0.25,"Network chef reached "+str(at))
	await wait(0.3)

func _host() -> void:
	while game.sim.players.size()<2: await wait(0.1)
	check(game.sim.players.size()==2,"Template synchronized two airport operators")
	while game.sim.handled<1: await wait(0.1)
	check(game.sim.money>=18,"Client routing generated server-owned airport funds")
	while game.sim.players.size()>1: await wait(0.1)
	check(game.sim.dog.held_by==0 and game.sim.dog.location=="floor","Client departure safely released the carried dog")
	finish(true,"Airport ENet host completed")

func _client() -> void:
	while not game.sim.players.has(game.local_id) or not game.sim.bags.has(1): await wait(0.1)
	check(game.sim.players.size()==2,"Client received both operators and arrivals")
	game.request_action("pickup_bag",1)
	await wait(0.3)
	check(game.feedback=="Move closer to that station or object.","Server rejected a client bag pickup outside range")
	while not game.sim.bags[1].scanned or game.sim.bags[1].t < 0.719: await wait(0.1)
	var point: Vector3 = game.sim.bag_position(game.sim.bags[1])
	await walk(Vector3(3.5,0,1.7),point)
	await walk(Vector3(3.5,0,-0.35),point)
	game.request_action("tool",-1,1)
	game.request_action("unlock",1)
	game.request_action("open",1)
	game.request_action("tool",-1,0)
	game.request_action("pickup_bag",1)
	await wait(0.4)
	check(game.sim.bags[1].opened and game.sim.players[game.local_id].held_kind=="bag","Client key/open/pickup RPCs synchronized bag ownership")
	await walk(Vector3(point.x,0,2),AirportRoom.ROUTES.gate_a)
	await walk(Vector3(-7,0,2),AirportRoom.ROUTES.gate_a)
	await walk(Vector3(-7,0,3.15),AirportRoom.ROUTES.gate_a)
	game.request_action("route",1,"gate_a")
	while game.sim.handled<1: await wait(0.1)
	check(game.sim.money>=18,"Client received shared money and sorted-bag state")
	await walk(Vector3(0,0,1.5),Vector3(0,0.3,1.5))
	game.request_action("call_dog",-1,game.chef.position+Vector3(0,0.3,0))
	await wait(1.5)
	game.request_action("pickup_dog")
	await wait(0.4)
	check(game.sim.players[game.local_id].held_kind=="dog","Dog pickup ownership synchronized before disconnect")
	finish(true,"Airport ENet client completed")

func finish(passed: bool,message: String) -> void:
	if done:return
	done=true
	var role="host" if game.multiplayer.is_server() else "client"
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var result={"passed":passed,"role":role,"checks":checks,"message":message,"money":game.sim.money,"handled":game.sim.handled}
	var file=FileAccess.open("res://artifacts/airport-network-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("AIRPORT_NETWORK_RESULT ",JSON.stringify(result))
	get_tree().quit(0 if passed else 1)
