extends Node
## Coordinated normal-input demo on two actual ENet peers. No cloned actors,
## seeded bags/currency, teleporting catches or predetermined flight outcomes.
var game
var role = "host"
var peer_id = 1
var other_peer = 0
var elapsed = 0.0
var ready_client = false
var finished = false
var checks: Array[String] = []
var acknowledgements: Dictionary = {}
var sequence = 0
var track_bag = -1
var track_peer = 0
var measurements: Array[Dictionary] = []
var quick = OS.get_cmdline_user_args().has("--airport-throw-quick")

func _ready() -> void:
	peer_id = game.local_id
	role = "host" if game.multiplayer.is_server() else "client"
	game.chef.automated = true
	game.hud.set_throw_demo("PLAYER 1" if peer_id == 1 else "PLAYER 2")
	if role == "host": _host.call_deferred()
	else: _client_ready.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 225 and not finished: fail("Throw demo exceeded 225 seconds")
	if track_bag > 0 and game.sim.bags.has(track_bag):
		game.chef.aim_target = game.sim.bag_position(game.sim.bags[track_bag])+Vector3(0,0.2,0)
		game.chef.aiming = true
	elif track_peer > 0 and game.poses.has(track_peer):
		game.chef.aim_target = game.poses[track_peer].position+Vector3(0,1.1,0)
		game.chef.aiming = true

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func synchronize(predicate: Callable, timeout: float = 3.0) -> void:
	var start = elapsed
	while not predicate.call() and elapsed-start < timeout and not finished:
		await get_tree().process_frame
	await get_tree().process_frame

func check(ok: bool,text: String) -> void:
	if finished: return
	if not ok:
		fail(text)
		return
	checks.append(text)
	print("THROW_PASS ",role," ",text)

func fail(text: String) -> void:
	if finished:return
	print("THROW_STATE ",role," left=",game.sim.time_left," wall=",Time.get_ticks_msec()," feedback=",game.feedback)
	for bag in game.sim.bags.values():
		if bag.off_belt: print("THROW_BAG ",bag.id," ",bag.location," age=",bag.flight_age," pos=",bag.position)
	push_error("THROW_FAIL "+role+" "+text)
	_write_report(false,text)
	finished=true
	get_tree().quit(1)

func key(code: Key) -> void:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await wait(0.035)

func walk(at: Vector3,look: Vector3) -> void:
	game.chef.navigate(at,look)
	var start=elapsed
	while game.chef.walking and elapsed-start<12:
		await get_tree().physics_frame
	check(game.chef.position.distance_to(at)<0.24,"Walked to "+str(at)+(" (stopped at "+str(game.chef.position)+")" if game.chef.position.distance_to(at)>=0.24 else ""))
	await wait(0.2)

func aim(at: Vector3) -> void:
	track_bag=-1
	track_peer=0
	game.chef.aim_target=at
	game.chef.aiming=true
	await wait(0.55)

func pickup(id: int) -> void:
	var bag: Dictionary=game.sim.bags[id]
	track_bag=id
	track_peer=0
	if bag.location=="belt":
		await walk(Vector3(3.5,0,1.7),game.sim.bag_position(bag))
		await walk(Vector3(3.5,0,-0.35),game.sim.bag_position(bag))
	else:
		var at: Vector3=game.sim.bag_position(bag)
		await walk(Vector3(game.chef.position.x,0,2),at)
		await walk(Vector3(at.x,0,2),at)
		await walk(Vector3(at.x,0,at.z+1.1),at)
	await key(KEY_1)
	await wait(0.25)
	game.chef.face(game.sim.bag_position(bag)+Vector3(0,0.2,0))
	await get_tree().process_frame
	check(game.interaction_target().get("id",-1)==id,"Look target selected bag #%d"%id)
	await key(KEY_E)
	await synchronize(func(): return game.sim.players[peer_id].held_kind=="bag" and game.sim.players[peer_id].held_id==id)
	check(game.sim.players[peer_id].held_kind=="bag" and game.sim.players[peer_id].held_id==id,"Picked up bag #%d through E"%id)
	check(game.sim.bags[id].off_belt,"Belt-removed bag retained yellow-outline state")
	check(game.carry_rig.visible,"Two-hand camera rig is visible while carrying")

func stage_bag(id: int,at: Vector3) -> void:
	await pickup(id)
	track_bag=-1
	await walk(Vector3(3.5,0,2),at)
	await walk(Vector3(at.x,0,2),at)
	await walk(at,at+Vector3(2,1.2,0))
	await aim(game.chef.camera.global_position+Vector3(3,0,0))
	await key(KEY_Q)
	await synchronize(func(): return game.sim.bags[id].location=="floor")
	check(game.sim.bags[id].location=="floor","Gently staged a real incoming bag on the floor")

func _client_ready() -> void:
	while not game.sim.players.has(peer_id): await wait(0.05)
	_ready_for_commands.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _ready_for_commands() -> void:
	if role=="host":
		other_peer=game.multiplayer.get_remote_sender_id()
		ready_client=true

func dispatch(peer: int,payload: Dictionary) -> int:
	sequence+=1
	var id=sequence
	acknowledgements[id]={"done":false,"peer":peer,"ok":false,"data":{}}
	if peer==peer_id: _command_local.call_deferred(id,payload)
	else: _command.rpc_id(peer,id,payload)
	return id

func await_command(id: int,timeout: float=22.0) -> Dictionary:
	var start=elapsed
	while not acknowledgements[id].done and elapsed-start<timeout:
		await wait(0.025)
	check(acknowledgements[id].done and acknowledgements[id].ok,"Both peers acknowledged action %d"%id)
	return acknowledgements[id].data

func order(peer: int,payload: Dictionary) -> Dictionary:
	var id=dispatch(peer,payload)
	return await await_command(id)

@rpc("authority","call_remote","reliable")
func _command(id: int,payload: Dictionary) -> void:
	_command_local(id,payload)

func _command_local(id: int,payload: Dictionary) -> void:
	var data: Dictionary={}
	match payload.type:
		"walk":
			track_bag=-1
			track_peer=int(payload.get("watch",0))
			if absf(game.chef.position.x-payload.at.x)>2.0:
				await walk(Vector3(game.chef.position.x,0,2),payload.at)
				await walk(Vector3(payload.at.x,0,2),payload.at)
			await walk(payload.at,payload.get("look",payload.at+Vector3(1,1,0)))
		"stage": await stage_bag(int(payload.bag),payload.at)
		"pickup": await pickup(int(payload.bag))
		"watch":
			track_bag=int(payload.get("bag",-1))
			track_peer=int(payload.get("peer",0))
		"ground_throw":
			var bag_id=int(payload.bag)
			var mass=float(game.sim.bags[bag_id].mass_kg)
			track_bag=-1
			await walk(Vector3(-4.8,0,2),Vector3(3,1.1,2))
			await aim(game.chef.camera.global_position+Vector3(10,-1.5,0))
			await screenshot("carry-%dkg"%int(mass))
			await wait(0.8)
			var before=int(game.sim.landings)
			var origin: Vector3=game.chef.position
			await key(KEY_G)
			track_bag=bag_id
			var started=elapsed
			while (game.sim.bags[bag_id].location!="floor" or game.sim.landings<=before) and elapsed-started<8:
				await wait(0.025)
			check(game.sim.bags[bag_id].location=="floor" and game.sim.landings>before,"%.0f kg bag really landed after a G throw"%mass)
			var landed: Vector3=game.sim.bags[bag_id].position
			data={"bag_id":bag_id,"mass_kg":mass,"ground_range":Vector2(landed.x-origin.x,landed.z-origin.z).length(),"position":landed}
			await screenshot("ground-%dkg"%int(mass))
			await wait(1.0)
		"throw":
			var other=int(payload.to)
			track_bag=-1
			track_peer=0
			var to: Vector3=game.poses[other].position+Vector3(0,1.1,0)
			await aim(to)
			await wait(0.6)
			var before=int(game.sim.throws)
			await key(KEY_G)
			await synchronize(func(): return game.sim.throws>before)
			check(game.sim.throws>before,"G sent a real weighted airborne bag to the other player")
			track_peer=other
		"receive":
			var bag_id=int(payload.bag)
			var sender=int(payload.from)
			track_peer=sender
			track_bag=-1
			var start=elapsed
			while elapsed-start<7:
				var bag: Dictionary=game.sim.bags[bag_id]
				if bag.location=="airborne" and bag.last_thrower==sender:
					track_bag=bag_id
					track_peer=0
					var center: Vector3=bag.position+Vector3(0,0.2,0)
					game.chef.face(center)
					var reach=(game.chef.position+Vector3(0,1.1,0)).distance_to(center)
					if reach<1.62 and bag.position.y>0.12 and bag.flight_age>=0.08:
						if game.interaction_target().get("id",-1)==bag_id: await key(KEY_E)
				if game.sim.players[peer_id].held_kind=="bag" and game.sim.players[peer_id].held_id==bag_id: break
				await get_tree().process_frame
			check(game.sim.players[peer_id].held_kind=="bag" and game.sim.players[peer_id].held_id==bag_id,"PLAYER %d caught bag #%d before it reached the floor"%[1 if peer_id==1 else 2,bag_id])
			var event: Dictionary={}
			for caught in game.sim.catch_events:
				if int(caught.peer_id)==peer_id and int(caught.bag_id)==bag_id:event=caught
			check(not event.is_empty() and event.height>0.12,"Authoritative catch event recorded positive airborne height")
			data=event
			track_bag=-1
			track_peer=sender
			await screenshot("catch-%dkg"%int(game.sim.bags[bag_id].mass_kg))
		"finish":
			check(game.sim.catches>=(2 if quick else 6),"Client observed all real mid-air ownership transfers")
			if finished: return
			_write_report(true,"Weighted ground throws and both players catching")
	if role=="host":
		acknowledgements[id]={"done":true,"peer":peer_id,"ok":not finished,"data":data}
	else:
		_ack.rpc_id(1,id,not finished,data)
	if payload.type=="finish" and role=="client":
		finished=true
		await wait(0.3)
		get_tree().quit(0)

@rpc("any_peer","call_remote","reliable")
func _ack(id: int,ok: bool,data: Dictionary) -> void:
	if role!="host" or not acknowledgements.has(id):return
	if acknowledgements[id].peer!=game.multiplayer.get_remote_sender_id():return
	acknowledgements[id].done=true
	acknowledgements[id].ok=ok
	acknowledgements[id].data=data

@rpc("authority","call_remote","reliable")
func _chapter(text: String) -> void:
	game.hud.chapter.text="AUTOMATED REAL-PEER PLAYTEST\n"+text

func chapter(text: String) -> void:
	_chapter(text)
	_chapter.rpc_id(other_peer,text)

func _host() -> void:
	while not ready_client or game.sim.players.size()<2: await wait(0.05)
	check(game.sim.players.size()==2,"Two actual ENet peers joined the ordinary airport scene")
	chapter("Warm-up: collecting real automatic arrivals")
	while not game.sim.bags.has(1) or game.sim.bags[1].t<0.719:await wait(0.05)
	await order(1,{"type":"stage","bag":1,"at":Vector3(-7,0,2)})
	if not quick:
		while not game.sim.bags.has(2) or game.sim.bags[2].t<0.719:await wait(0.05)
		await order(other_peer,{"type":"stage","bag":2,"at":Vector3(-7,0,2.8)})
		while not game.sim.bags.has(5) or not game.sim.bags[5].scanned:await wait(0.05)
		await order(1,{"type":"stage","bag":5,"at":Vector3(-7,0,1.2)})
	await walk(Vector3(-1.2,0,1.5),AirportRoom.SCAN_CONSOLE)
	await aim(AirportRoom.SCAN_CONSOLE)
	if game.sim.belt_running:await key(KEY_E)
	await synchronize(func(): return not game.sim.belt_running)
	check(not game.sim.belt_running,"Paused intake through its normal console after collecting bags")
	if not quick: check([game.sim.bags[1].mass_kg,game.sim.bags[2].mass_kg,game.sim.bags[5].mass_kg]==[8.0,16.0,28.0],"Actual arrivals supplied 8 / 16 / 28 kg loads")
	await order(1,{"type":"walk","at":Vector3(-4.8,0,2),"watch":other_peer})
	await order(other_peer,{"type":"walk","at":Vector3(4.8,0,2.8),"watch":1})
	chapter("Two players / yellow off-belt bags / weighted handling")
	print("THROW_CAPTURE_READY")
	while not FileAccess.file_exists("res://artifacts/throw-start.flag"): await wait(0.05)
	await wait(1.0)
	for index in range(1 if quick else 3):
		var bag_id=[1,2,5][index]
		var owner=other_peer if index==1 else 1
		var observer=1 if owner==other_peer else other_peer
		var mass=float(game.sim.bags[bag_id].mass_kg)
		chapter("%.0f KG / SAME THROW STRENGTH / REAL GROUND IMPACT"%mass)
		await order(observer,{"type":"walk","at":Vector3(4.8,0,2.8),"watch":owner})
		await order(owner,{"type":"pickup","bag":bag_id})
		await order(observer,{"type":"watch","bag":bag_id})
		measurements.append(await order(owner,{"type":"ground_throw","bag":bag_id}))
	if not quick: check(measurements[0].ground_range>measurements[1].ground_range+0.3 and measurements[1].ground_range>measurements[2].ground_range+0.3,"Matched throws showed decreasing range as mass increased")
	for index in range(1 if quick else 3):
		var bag_id=[1,2,5][index]
		var mass=float(game.sim.bags[bag_id].mass_kg)
		var receiver_x=[4.2,3.0,1.9][index]
		chapter("%.0f KG RELAY / PLAYER 1 → PLAYER 2 MID-AIR CATCH"%mass)
		await order(1,{"type":"pickup","bag":bag_id})
		await order(1,{"type":"walk","at":Vector3(-0.7,0,2),"watch":other_peer})
		await order(other_peer,{"type":"walk","at":Vector3(receiver_x,0,2),"watch":1})
		await wait(0.8)
		var receive_id=dispatch(other_peer,{"type":"receive","bag":bag_id,"from":1})
		await wait(0.25)
		await order(1,{"type":"throw","to":other_peer})
		await await_command(receive_id,9)
		await wait(1.25)
		chapter("%.0f KG RETURN / PLAYER 2 → PLAYER 1 MID-AIR CATCH"%mass)
		receive_id=dispatch(1,{"type":"receive","bag":bag_id,"from":other_peer})
		await wait(0.25)
		await order(other_peer,{"type":"throw","to":1})
		await await_command(receive_id,9)
		await wait(1.25)
		# Use normal Q, not a model teleport, to put each completed relay bag down.
		await order(1,{"type":"walk","at":Vector3(-0.7,0,3.0),"watch":other_peer})
		await key(KEY_Q)
		await wait(0.2)
	check(game.sim.catches>=(2 if quick else 6),"Both distinct players caught each weight class in mid-air")
	var owners: Dictionary={}
	for caught in game.sim.catch_events:owners[int(caught.peer_id)]=true
	check(owners.has(1) and owners.has(other_peer),"Catch events identify both real connected peer IDs")
	chapter("PASS / %d WEIGHT CLASSES / BOTH PLAYERS CAUGHT IN MID-AIR"%(1 if quick else 3))
	await wait(2)
	# Client writes its own received-state report before disconnecting.
	await order(other_peer,{"type":"finish"})
	_write_report(true,"Two real players threw and caught weighted bags")
	finished=true
	print("THROW_CAPTURE_COMPLETE")
	await wait(0.4)
	get_tree().quit(0)

func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	get_viewport().get_texture().get_image().save_png("res://artifacts/throw-"+role+"-"+name+".png")

func _write_report(passed: bool,message: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var data={"passed":passed,"message":message,"role":role,"peer_id":peer_id,"automated_inputs":true,"real_enet_peers":true,"quick_regression":quick,"simulation_time_scale":Engine.time_scale,"elapsed_seconds":elapsed,"checks":checks,"throws":game.sim.throws,"landings":game.sim.landings,"catches":game.sim.catches,"catch_events":game.sim.catch_events,"throw_events":game.sim.throw_events,"landing_events":game.sim.landing_events,"range_measurements":measurements}
	var file=FileAccess.open("res://artifacts/throw-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	print("THROW_RESULT ",role," passed=",passed," checks=",checks.size()," catches=",game.sim.catches)
