extends "res://scripts/airport/airport_throw_playtest.gd"
## Isolated trailer fixture: additive masses and initial floor positions only.
## All pickup, helper join, walking, throw, catch and release use normal inputs.
var markers: Array[Dictionary] = []
var shared_samples: Array[Dictionary] = []
var sampling_shared = false
var sample_clock = 0.0

func mark(label: String) -> void:
	markers.append({"label":label,"ticks_msec":Time.get_ticks_msec(),"game_elapsed":elapsed})
	print("COOP_MARK ",label," ",Time.get_ticks_msec())

func _process(delta: float) -> void:
	super._process(delta)
	if sampling_shared and role == "host":
		sample_clock += delta
		if sample_clock > 0.05:
			sample_clock = 0
			var b: Dictionary = game.sim.bags[2]
			shared_samples.append({"time":elapsed,"primary":game.sim.players[1].position,"helper":game.sim.players[other_peer].position,"bag":game.sim.bag_position(b),"linked":b.carry_helpers.has(other_peer),"location":b.location})

func _command_local(id: int,payload: Dictionary) -> void:
	var custom = true
	match payload.type:
		"join":
			track_bag = int(payload.bag)
			track_peer = 0
			await aim(game.sim.bag_position(game.sim.bags[payload.bag])+Vector3(0,0.2,0))
			game.selected_id = int(payload.bag)
			await key(KEY_H)
			await synchronize(func(): return int(game.sim.players[peer_id].carry_bag)==int(payload.bag))
			check(int(game.sim.players[peer_id].carry_bag)==int(payload.bag),"Normal H joined the real primary carrier")
		"shared_walk":
			track_bag = int(payload.bag)
			track_peer = 0
			await walk(payload.at,game.sim.bag_position(game.sim.bags[payload.bag])+Vector3(0,0.2,0))
			check(game.sim.players[peer_id].carry_partner>0,"Shared carry stayed linked after collision-aware walking")
		"drop":
			await key(KEY_Q)
			await synchronize(func(): return game.sim.bags[payload.bag].location=="floor")
			check(game.sim.bags[payload.bag].location=="floor","Normal Q lowered shared baggage gently")
		_:
			custom = false
			await super._command_local(id,payload)
	if custom:
		if role=="host": acknowledgements[id]={"done":true,"peer":peer_id,"ok":not finished,"data":{}}
		else: _ack.rpc_id(1,id,not finished,{})

func fixture(id: int,mass: float,at: Vector3) -> void:
	_set_mass_fixture(id,mass)
	var b: Dictionary = game.sim.bags[id]
	b.location="floor"
	b.position=at
	b.off_belt=true
	b.velocity=Vector3.ZERO
	b.angular_velocity=Vector3.ZERO

func _host() -> void:
	while not ready_client or game.sim.players.size()<2: await wait(0.05)
	check(game.sim.players.size()==2,"Two independent ENet processes joined ordinary readiness")
	while not game.sim.bags.has(2): await wait(0.05)
	# Pause the intake using the ordinary console key, not a simulation mutation.
	await walk(Vector3(-1.2,0,1.5),AirportRoom.SCAN_CONSOLE)
	await aim(AirportRoom.SCAN_CONSOLE)
	await key(KEY_E)
	await synchronize(func(): return not game.sim.belt_running)
	check(not game.sim.belt_running,"Normal console action paused intake")
	fixture(1,8.0,Vector3(-1.5,0.12,2))
	fixture(2,32.0,Vector3(-3,0.12,0.9))
	await order(1,{"type":"walk","at":Vector3(-3,0,2.0)})
	await order(other_peer,{"type":"walk","at":Vector3(-1.8,0,2.8),"watch":1})
	print("THROW_CAPTURE_READY")
	while not FileAccess.file_exists("res://artifacts/throw-start.flag"): await wait(0.05)
	mark("capture_cue")
	await wait(0.7)
	mark("heavy_pickup")
	await pickup(2)
	check(game.sim.carry_speed(1)<=0.001,"32kg primary correctly waits for helper")
	mark("primary_waiting_for_helper")
	await wait(1.0)
	await order(other_peer,{"type":"walk","at":Vector3(-1.9,0,2.0),"watch":1})
	mark("helper_join_start")
	await order(other_peer,{"type":"join","bag":2})
	await synchronize(func(): return game.sim.bags[2].carry_helpers.has(other_peer))
	check(game.sim.bags[2].carry_helpers.has(other_peer),"32kg bag has one distinct real ENet helper")
	var p0: Vector3 = game.sim.players[1].position
	var h0: Vector3 = game.sim.players[other_peer].position
	await wait(0.7)
	mark("shared_walking_start")
	sampling_shared=true
	# Parallel controller navigation preserves the normal carry reach constraint.
	var a=dispatch(1,{"type":"shared_walk","bag":2,"at":Vector3(0.2,0,2.0)})
	var b=dispatch(other_peer,{"type":"shared_walk","bag":2,"at":Vector3(1.3,0,2.0)})
	await await_command(a)
	await await_command(b)
	await wait(0.6)
	a=dispatch(1,{"type":"shared_walk","bag":2,"at":Vector3(3.4,0,2.0)})
	b=dispatch(other_peer,{"type":"shared_walk","bag":2,"at":Vector3(4.5,0,2.0)})
	await await_command(a)
	await await_command(b)
	sampling_shared=false
	mark("shared_walking_end")
	check(game.sim.players[1].position.distance_to(p0)>6.0,"Primary walked over six metres with shared 32kg bag")
	check(game.sim.players[other_peer].position.distance_to(h0)>6.0,"Independent helper walked over six metres alongside primary")
	check(shared_samples.all(func(s): return s.linked and s.location=="held"),"Recorded walking samples retained real held ownership and helper link")
	await screenshot("heavy-shared-walk")
	await wait(0.8)
	mark("gentle_drop")
	await order(other_peer,{"type":"drop","bag":2})
	check(game.sim.players[1].carry_partner==0 and game.sim.players[other_peer].carry_partner==0,"Gentle shared drop cleared both carrier links")
	await wait(0.8)
	mark("relay_setup")
	await pickup(1)
	await order(1,{"type":"walk","at":Vector3(-0.7,0,2),"watch":other_peer})
	await order(other_peer,{"type":"walk","at":Vector3(4.2,0,2),"watch":1})
	await wait(0.8)
	mark("relay_outbound")
	var receive_id=dispatch(other_peer,{"type":"receive","bag":1,"from":1})
	await wait(0.25)
	await order(1,{"type":"throw","to":other_peer})
	await await_command(receive_id,9)
	mark("client_airborne_catch")
	await wait(1.0)
	mark("relay_return")
	receive_id=dispatch(1,{"type":"receive","bag":1,"from":other_peer})
	await wait(0.25)
	await order(other_peer,{"type":"throw","to":1})
	await await_command(receive_id,9)
	mark("host_airborne_catch")
	check(game.sim.catches>=2,"Both distinct real peers caught the 8kg relay in mid-air")
	await wait(1.5)
	mark("complete")
	await order(other_peer,{"type":"finish"})
	_write_report(true,"Visible 32kg shared walking and real two-way 8kg airborne relay")
	finished=true
	print("THROW_CAPTURE_COMPLETE")
	await wait(0.3)
	get_tree().quit(0)

func _write_report(passed: bool,message: String) -> void:
	super._write_report(passed,message)
	var path="res://artifacts/throw-"+role+".json"
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report["markers"]=markers
	report["shared_samples"]=shared_samples
	report["fixture_disclosure"]="Only additive shell masses (8kg / 32kg) and initial floor staging. Actual normal E/H/G/Q input, controller walking, ENet transport, authoritative flight and catch outcomes."
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
