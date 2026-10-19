extends Node
## Two actual peers, real normal-key locks, redacted state and shared ownership.
## Explicit tutorial loot is used; locks, care and the host boundary stay live.
var game
var elapsed = 0.0
var done = false
var checks: Array[String] = []
var shared_released = false

func _ready() -> void:
	game.chef.automated = true
	if game.multiplayer.is_server():
		game.sim.set_fixture_mode()
		_host.call_deferred()
	else: _client.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 65 and not done: finish(false,"Airport network check timed out")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func until(predicate: Callable, timeout: float = 4.0) -> void:
	var start = elapsed
	while not done and not predicate.call() and elapsed-start < timeout:
		await get_tree().process_frame

func check(ok: bool, text: String) -> void:
	if done: return
	if not ok: finish(false,text)
	else:
		checks.append(text)
		print("AIRPORT_NETWORK_PASS ",text)

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await wait(0.06)

func walk(at: Vector3, look: Vector3) -> void:
	game.chef.navigate(at,look)
	var start = elapsed
	while game.chef.walking and elapsed-start < 10: await get_tree().physics_frame
	check(game.chef.position.distance_to(at)<0.25,"Network chef reached "+str(at))
	await wait(0.15)

func solve_lock(id: int, tool: Key) -> void:
	await key(tool)
	await until(func(): return game.sim.players[game.local_id].tool==int(tool-KEY_1))
	check(game.sim.players[game.local_id].tool==int(tool-KEY_1),"Server acknowledged equipped lock tool")
	await key(KEY_E)
	await until(func(): return not game.sim.players[game.local_id].lock_game.is_empty())
	var challenge: Dictionary = game.sim.players[game.local_id].lock_game.duplicate(true)
	check(not challenge.is_empty() and not game.sim.bags[id].unlocked,"E starts a timed lock, not an instant unlock")
	if challenge.is_empty(): return
	check(challenge.remaining>0 and challenge.bag_id==id,"Recipient receives only its own live lock challenge")
	var initial_time: float = challenge.remaining
	await wait(0.2)
	check(game.sim.players[game.local_id].lock_game.remaining<initial_time,"Lock countdown advances on the host")
	for value in challenge.sequence:
		await key(KEY_1+int(value))
	await until(func(): return game.sim.bags[id].unlocked)
	check(game.sim.bags[id].unlocked,"Normal numeric keys completed timed lock #%d"%id)
	await key(KEY_O)
	await until(func(): return game.sim.bags[id].opened)
	check(game.sim.bags[id].opened,"Normal O revealed inspected contents #%d"%id)
	await key(KEY_1)

func no_truth() -> bool:
	for bag in game.sim.bags.values():
		if bag.has("truth"): return false
		for item in bag.items:
			if item.has("truth"): return false
	return true

func _host() -> void:
	await until(func(): return game.sim.players.size()==2,15)
	check(game.sim.players.size()==2,"Template synchronized two airport operators")
	await until(func(): return game.sim.bags.has(2),15)
	# Explicit additive 28 kg fixture to exercise the >24 kg shared-carry rule.
	game.sim.bags[2].shell_mass_kg = 26.0
	game.sim.ensure_bag_physics(game.sim.bags[2])
	await until(func(): return game.sim.handled==1,35)
	check(game.sim.money>=18,"Client routing generated server-owned airport funds")
	var point: Vector3 = game.sim.bag_position(game.sim.bags[2])
	await walk(Vector3(3.5,0,1.7),point)
	await walk(Vector3(3.5,0,-0.35),point)
	await until(func(): return game.sim.bags[2].location=="held",15)
	check(game.sim.carry_speed(game.sim.bags[2].held_by)==0.0,"Heavy primary carrier waits for a helper")
	game.request_action("join_carry",2)
	check(game.sim.bags[2].carry_helpers==[game.local_id],"Second real peer joined shared physical ownership")
	check(game.sim.carry_speed(game.sim.bags[2].held_by)>0,"Helper enabled heavy carry movement")
	var client_id: int = game.sim.bags[2].held_by
	check(game.sim.snapshot_for(client_id).players[game.local_id].lock_game.is_empty(),"Other inspector lock solution stays private")
	await wait(0.6)
	game.request_action("leave_carry",2)
	check(game.sim.bags[2].location=="floor" and game.sim.bags[2].carry_helpers.is_empty(),"Shared lowering atomically cleared bag ownership")
	check(game.sim.players[client_id].held_kind=="" and game.sim.players[client_id].carry_partner==0,"Shared lowering released both operators")
	await until(func(): return game.sim.players.size()==1,15)
	check(game.sim.dog.held_by==0 and game.sim.dog.location=="floor","Client departure safely released the carried dog")
	finish(true,"Airport ENet host completed")

func _client() -> void:
	await until(func(): return game.sim.players.has(game.local_id) and game.sim.bags.has(1),15)
	check(game.sim.players.size()==2,"Client received both operators and arrivals")
	check(game.sim.bags[1].category=="unknown" and game.sim.bags[1].items[0].kind=="unknown" and no_truth(),"Uninspected ENet snapshot redacts kinds, categories and all host truth")
	game.request_action("pickup_bag",1)
	await until(func(): return game.feedback=="Move closer to that station or object.")
	check(game.feedback=="Move closer to that station or object.","Server rejected a client bag pickup outside range")
	await until(func(): return game.sim.bags.has(2) and game.sim.bags[2].t>=0.64,20)
	var point: Vector3 = game.sim.bag_position(game.sim.bags[1])
	await walk(Vector3(3.5,0,1.7),point)
	await walk(Vector3(3.5,0,-0.35),point)
	await solve_lock(1,KEY_2)
	check(no_truth() and game.sim.bags[1].items[0].kind=="clothes","Inspection reveals labels but never host truth")
	await key(KEY_C)
	await until(func(): return not game.sim.bags[1].opened)
	await key(KEY_R)
	await until(func(): return not game.sim.bags[1].unlocked)
	check(not game.sim.bags[1].unlocked,"Normal C/R closed and resealed the inspected bag")
	await solve_lock(1,KEY_2)
	await walk(Vector3(3.5,0,-0.35),game.sim.bag_position(game.sim.bags[2]))
	await solve_lock(2,KEY_3)
	var moved_id: int = game.sim.bags[1].items[0].id
	game.request_action("take_item",1,0)
	await until(func(): return game.sim.players[game.local_id].held_kind=="item")
	game.request_action("return_item",2)
	await until(func(): return game.sim.bags[2].items.size()==3)
	check(game.sim.bags[1].items.size()==1 and game.sim.bags[2].items.back().id==moved_id,"Cross-bag repacking synchronized unique item identity")
	check(no_truth(),"Repacked inspected recipient state still omits host truth")
	game.request_action("pickup_bag",1)
	await until(func(): return game.sim.players[game.local_id].held_kind=="bag")
	check(game.sim.bags[1].held_by==game.local_id,"Client owns the actual synchronized bag")
	await walk(Vector3(3.5,0,2),AirportRoom.ROUTES.gate_a)
	await walk(Vector3(-7,0,2),AirportRoom.ROUTES.gate_a)
	await walk(Vector3(-7,0,3.15),AirportRoom.ROUTES.gate_a)
	game.request_action("route",1,"gate_a")
	await until(func(): return game.sim.handled==1)
	check(game.sim.money>=18 and game.sim.bags[1].location=="sorted","Client received shared money and sorted-bag state")
	await walk(Vector3(-7,0,2),point)
	await walk(Vector3(3.5,0,2),point)
	await walk(Vector3(3.5,0,-0.35),game.sim.bag_position(game.sim.bags[2]))
	game.request_action("pickup_bag",2)
	await until(func(): return not game.sim.bags[2].carry_helpers.is_empty())
	check(game.sim.players[game.local_id].carry_partner==1,"Recipient synchronized two-person carrier links")
	await until(func(): return game.sim.bags[2].location=="floor")
	check(game.sim.players[game.local_id].held_kind=="" and game.sim.players[game.local_id].carry_partner==0,"Recipient observed atomic shared-carry release")
	await walk(Vector3(3.5,0,1.5),Vector3(0,0.3,1.5))
	await walk(Vector3(0,0,1.5),Vector3(0,0.3,1.5))
	game.request_action("call_dog",-1,game.chef.position+Vector3(0,0.3,0))
	await until(func(): return game.sim.dog.position.distance_to(game.chef.position)<1.5)
	game.request_action("pickup_dog")
	await until(func(): return game.sim.players[game.local_id].held_kind=="dog")
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
