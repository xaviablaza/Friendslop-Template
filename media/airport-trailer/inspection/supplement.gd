extends SceneTree
const OUT = "/home/administrator/Friendslop-Template-airport-baggage/artifacts/trailer-v2/inspection/"
var g
var cat
var checks=[]
var timeline=[]
var start=0
var rendered=false
func _initialize(): run.call_deferred()
func wait_s(t):
	for i in range(roundi(t*24)): await process_frame
func refresh(): g._process(0.0)
func key(code):
	var e=InputEventKey.new()
	e.physical_keycode=code
	e.pressed=true
	Input.parse_input_event(e)
	await process_frame
	e=InputEventKey.new()
	e.physical_keycode=code
	Input.parse_input_event(e)
	await process_frame
	refresh()
func move(at,look):
	g.chef.position=at
	g.chef.velocity=Vector3.ZERO
	g.chef.face(look)
	g.poses[1]={"position":at,"yaw":g.chef.rotation.y}
	g.sim.set_player_position(1,at+Vector3(0,0.3,0))
	refresh()
func check(ok,text,data={}):
	checks.append({"passed":ok,"assertion":text,"data":data,"frame":Engine.get_process_frames()-start})
	print("SUPPLEMENT_CHECK ",ok," ",text," ",data)
func snap(name):
	if rendered:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+name+".png")
func bag(id,kinds,at):
	var b=g.sim._random_bag(id)
	b.items.clear()
	for i in range(kinds.size()): b.items.append(cat.instantiate(cat.entry(kinds[i]),g.sim.rng,20000+id*10+i,true))
	b.position=at
	b.location="table"
	b.scanned=true
	b.lock="none"
	b.unlocked=true
	b.opened=false
	b.carrier=false
	b.pet={}
	b.shell_mass_kg=3.0
	b.size=1
	b.kind=0
	g.sim.ensure_bag_physics(b)
	g.sim.bags[id]=b
	refresh()
	return b
func run():
	await process_frame
	rendered=DisplayServer.get_name()!="headless"
	root.get_multiplayer().multiplayer_peer=OfflineMultiplayerPeer.new()
	g=load("res://scenes/level/airport/AirportBaggage.tscn").instantiate()
	root.add_child(g)
	await wait_s(0.25)
	cat=load("res://scripts/airport/airport_catalog.gd")
	g.chef.set_physics_process(false)
	g.chef.automated=true
	g.sim=load("res://scripts/airport/airport_simulation.gd").new()
	g.sim.set_seed(20261020)
	g.sim.add_player(1)
	g.sim.belt_running=false
	g.sim.collision_query=g._bag_collision
	g.sim.dog.mode="stay"
	g.sim.dog.position=Vector3(-8,0.3,0)
	g.sim.dog_goal=g.sim.dog.position
	g.hud.chapter.hide()
	g.hud.dog_label.get_parent().hide()
	for n in g.room.get_children():
		if n is Label3D and ("CHECKED CHAOS" in n.text or "AIRPORT BAGGAGE /" in n.text): n.hide()
	start=Engine.get_process_frames()
	var b=bag(1,["books","clothes"],Vector3(2,1.1,0))
	move(Vector3(2,0.03,1.35),Vector3(2,1.3,0))
	g.selected_id=1
	await key(KEY_O)
	await key(KEY_I)
	await wait_s(2)
	g.hud.browser_rows.get_child(0).pressed.emit()
	refresh()
	await key(KEY_I)
	move(Vector3(3,0.03,2),Vector3(-4,1.6,2))
	await wait_s(2)
	var item=b.items[0]
	await key(KEY_G)
	check(item.location=="airborne","Individual holiday books launched by normal G",{"mass_kg":item.mass_kg})
	await wait_s(0.15)
	g.chef.face(item.position)
	refresh()
	await snap("supplement-item-flight")
	await wait_s(2)
	check(item.location=="floor","Individual item completes real flight and surface landing",{"position":str(item.position)})
	g.chef.face(item.position)
	refresh()
	await wait_s(2)
	timeline.append({"id":"clear_individual_item_flight","start_frame":0,"end_frame":Engine.get_process_frames()-start,"visible_result":"Real browser chooses holiday books; visible held book, G launch through open aisle, actual gravity landing; no equipped tool obscures action.","crop_suggestion":"Central game action plus left held-item inventory"})
	g.sim.bags[1].location="sorted"
	var sf=Engine.get_process_frames()-start
	var bottom=bag(2,["clothes"],Vector3(-0.5,0.04,2))
	var mid=bag(3,["books"],Vector3(-0.5,0.8,2))
	var top=bag(4,["electronics"],Vector3(-0.5,2.3,2))
	bottom.location="floor"
	mid.location="floor"
	top.location="airborne"
	top.velocity=Vector3.ZERO
	move(Vector3(-0.5,0.03,4.2),Vector3(-0.5,1.4,2))
	g.selected_id=4
	await wait_s(3)
	g.chef.face(top.position+Vector3(0,0.25,0))
	refresh()
	await wait_s(2)
	check(top.damage>0 and g.selected_id==4,"Impact damage shown on selected TOP bag manifest",{"damage":top.damage,"selected_id":g.selected_id,"manifest":g.hud.case_label.text})
	await snap("supplement-visible-damage")
	await wait_s(2)
	timeline.append({"id":"visible_top_bag_impact_damage","start_frame":sf,"end_frame":Engine.get_process_frames()-start,"visible_result":"Top bag falls on genuine stack; camera aims at top so actual damage value is readable in top-right manifest (not middle bag).","crop_suggestion":"Center stack AND top-right manifest"})
	for id in [2,3,4]: g.sim.bags[id].location="sorted"
	sf=Engine.get_process_frames()-start
	move(Vector3(7.2,0.03,2),Vector3(7.2,2.8,1.8))
	b=bag(5,["books","electronics"],Vector3(7.2,3.2,2))
	b.location="airborne"
	b.velocity=Vector3.ZERO
	b.last_thrower=0
	b.flight_age=1.0
	await wait_s(2)
	move(Vector3(7.2,0.03,2),b.position+Vector3(0,0.15,0))
	await wait_s(2)
	check(g.sim.players[1].health<100 and g.sim.players[1].health>0,"Health visibly reduced after real luggage impact",{"health":g.sim.players[1].health})
	await snap("supplement-injury-health")
	await wait_s(2)
	timeline.append({"id":"injury_health_after_actual_impact","start_frame":sf,"end_frame":Engine.get_process_frames()-start,"visible_result":"Falling bag hits player; follow-down view holds actual reduced health and landed bag before first aid in main capture.","crop_suggestion":"Left health panel plus landed luggage at center"})
	var ok=checks.all(func(c): return c.passed)
	FileAccess.open(OUT+"supplement-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":ok,"assertion_count":checks.size(),"checks":checks},"\t"))
	FileAccess.open(OUT+"supplement-timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":24,"shots":timeline,"end_frame":Engine.get_process_frames()-start,"fixture_provenance":"Same exact bag fixture helper as main: _random_bag with certain catalogue contents; positions/lock/size explicitly in supplement.gd; seed20261020; no money or health seeded; no gameplay results overwritten."},"\t"))
	quit(0 if ok else 1)
