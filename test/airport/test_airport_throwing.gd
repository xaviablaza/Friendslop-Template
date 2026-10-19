extends GutTest

const Simulation = preload("res://scripts/airport/airport_simulation.gd")
var sim
const ORIGIN = Vector3(0, 1.25, 0.55)

func before_each():
	sim = Simulation.new()
	sim.set_fixture_mode()
	sim.add_player(7)
	sim.add_player(8)
	sim.set_player_position(7, Vector3(0, 0.3, 0))
	sim.update(50.01)
	sim.belt_running = false
	# Explicit additive fixtures isolate weighted physics from randomized loot.
	for id in [1, 2, 4, 5]:
		var target_mass: float = {1:8.0, 2:16.0, 4:28.0, 5:23.0}[id]
		sim.bags[id].shell_mass_kg = target_mass - sim.bags[id].items.size()
		sim.ensure_bag_physics(sim.bags[id])

func _open(id: int):
	sim.act(7, "tool", -1, 2)
	sim.act(7, "unlock", id)
	var sequence: Array = sim.players[7].lock_game.get("sequence", []).duplicate()
	for value in sequence:
		sim.act(7, "lock_input", id, value)
	sim.act(7, "open", id)
	assert_true(sim.bags[id].opened)

func _throw(id: int = 1, peer: int = 7, origin: Vector3 = ORIGIN, direction: Vector3 = Vector3.FORWARD):
	sim.act(peer, "pickup_bag", id)
	sim.act(peer, "throw_bag", id, {"origin": origin, "direction": direction})

func _in_reach(peer: int = 8, id: int = 1):
	sim.set_player_position(peer, sim.bags[id].position - Vector3.UP * 0.6)

func test_spawned_bags_have_explicit_mass_including_dense_small_electronics():
	assert_eq(sim.bags[1].get("mass_kg", -1.0), 8.0)
	assert_eq(sim.bags[2].get("mass_kg", -1.0), 16.0)
	assert_eq(sim.bags[4].get("mass_kg", -1.0), 28.0)
	assert_eq(sim.bags[5].size, 0)
	assert_eq(sim.bags[5].get("mass_kg", -1.0), 23.0) # Co-op throwable load below shared-carry threshold.
	for bag in sim.bags.values():
		for key in ["velocity", "rotation", "angular_velocity", "off_belt", "flight_age", "last_thrower"]:
			assert_true(bag.has(key), "Missing physics field: " + key)

func test_throw_closes_open_bag_preserves_unlock_and_host_calculates_impulse():
	_open(1)
	sim.act(7, "pickup_bag", 1)
	sim.act(7, "throw_bag", -1, {"origin": ORIGIN, "direction": Vector3.FORWARD, "velocity": Vector3.ONE * 999})
	var bag: Dictionary = sim.bags[1]
	assert_eq(bag.location, "airborne")
	assert_eq(bag.position, ORIGIN)
	assert_eq(bag.velocity, Vector3(0, 35.0 / 8.0, -9))
	assert_true(bag.unlocked)
	assert_false(bag.opened)
	assert_true(bag.off_belt)
	assert_eq(bag.held_by, 0)
	assert_eq(bag.last_thrower, 7)
	assert_eq(bag.flight_age, 0.0)
	assert_eq(sim.players[7].held_kind, "")
	assert_eq(sim.throws, 1)
	assert_eq(sim.throw_events[0].mass_kg, 8.0)
	assert_eq(sim.throw_events[0].velocity, bag.velocity)
	assert_eq(sim.money, 0)

func test_matched_throws_heavy_bag_has_shorter_first_landing_range():
	var ranges: Array = []
	for id in [1, 2, 5]:
		sim.set_player_position(7, Vector3(-8, 0.3, 0))
		_throw(id, 7, Vector3(-8, 1.25, 0), Vector3.RIGHT)
		assert_eq(sim.bags[id].location, "airborne")
		sim.update(2.0)
		ranges.append(sim.landing_events.back().distance)
	assert_gt(ranges[0], ranges[1])
	assert_gt(ranges[1], ranges[2])
	assert_eq(sim.landings, 3)

func test_carry_speed_depends_on_mass_and_empty_hands_restore_speed():
	assert_eq(sim.carry_speed(7), 1.0)
	assert_eq(sim.carry_speed(999), 1.0)
	var speeds: Array = []
	for id in [1, 2, 5]:
		sim.act(7, "pickup_bag", id)
		speeds.append(sim.carry_speed(7))
		sim.act(7, "place_bag", -1, {"location": "floor", "position": Vector3(0, 0.04, 0)})
	assert_gt(speeds[0], speeds[1])
	assert_gt(speeds[1], speeds[2])
	assert_almost_eq(speeds[0], 1.0 - 8.0 / 70.0, 0.00001)
	assert_eq(sim.carry_speed(7), 1.0)

func test_common_gravity_updates_actual_position_even_with_belt_paused():
	_throw()
	var initial: Vector3 = sim.bags[1].velocity
	sim.update(0.1)
	assert_almost_eq(sim.bags[1].velocity.y, initial.y - 9.81 * 0.1, 0.0001)
	assert_almost_eq(sim.bags[1].position.y, ORIGIN.y + initial.y * 0.1 - 0.5 * 9.81 * 0.01, 0.0001)
	assert_gt(sim.bags[1].flight_age, 0.09)
	assert_ne(sim.bags[1].rotation, Vector3.ZERO)
	for id in [2, 5]:
		_throw(id)
		var heavy_initial: Vector3 = sim.bags[id].velocity
		sim.update(0.1)
		assert_almost_eq(sim.bags[id].velocity.y, heavy_initial.y - 9.81 * 0.1, 0.0001)

func test_ground_bounce_settles_once_and_remains_retrievable_off_belt():
	_throw()
	sim.update(5.0)
	var bag: Dictionary = sim.bags[1]
	assert_eq(bag.location, "floor")
	assert_almost_eq(bag.position.y, 0.04, 0.00001)
	assert_eq(bag.velocity, Vector3.ZERO)
	assert_eq(bag.angular_velocity, Vector3.ZERO)
	assert_eq(sim.landings, 1)
	assert_eq(sim.landing_events.size(), 1)
	assert_gt(sim.landing_events[0].distance, 0.1)
	assert_eq(sim.landing_events[0].mass_kg, 8.0)
	assert_almost_eq(sim.landing_events[0].ground_position.y, 0.04, 0.00001)
	sim.update(2.0)
	assert_eq(sim.landings, 1)
	sim.act(8, "catch_bag", 1)
	assert_eq(sim.players[8].held_kind, "")
	sim.act(8, "pickup_bag", 1)
	assert_eq(bag.held_by, 8)
	assert_true(bag.off_belt)

func test_fallback_room_bounds_and_callback_collision_reflect_velocity():
	_throw(1, 7, Vector3(0, 1.25, 0.55), Vector3.RIGHT)
	sim.update(3.0)
	assert_between(sim.bags[1].position.x, -10.0, 10.0)
	assert_between(sim.bags[1].position.z, -4.9, 6.0)
	var calls: Array = []
	sim.collision_query = func(from: Vector3, to: Vector3, bag: Dictionary) -> Dictionary:
		calls.append([from, to, bag.get("id", -1)]) # Dog sweeps share this callback.
		if from.x < 1.0 and to.x >= 1.0:
			var contact: Vector3 = from.lerp(to, (1.0 - from.x) / (to.x - from.x))
			return {"position": contact, "normal": Vector3.LEFT}
		return {}
	_throw(2, 7, ORIGIN, Vector3.RIGHT)
	sim.update(0.3)
	assert_gt(calls.size(), 30)
	assert_lte(sim.bags[2].position.x, 1.0)
	assert_lt(sim.bags[2].velocity.x, 0.0)
	for call in calls:
		assert_lte((call[1] as Vector3).distance_to(call[0]), 0.1)

func test_fallback_each_wall_reflects_and_ground_friction_allows_sliding():
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var model = Simulation.new()
		model.set_fixture_mode()
		model.add_player(7)
		var start: Vector3 = Vector3(direction.x * 9.8, 1.25, direction.z * (5.8 if direction.z > 0.0 else 4.7))
		model.set_player_position(7, start - Vector3.UP)
		model.update(0.0)
		model.belt_running = false
		model.act(7, "pickup_bag", 1)
		model.act(7, "throw_bag", 1, {"origin": start, "direction": direction})
		model.update(0.1)
		assert_lt((model.bags[1].velocity as Vector3).dot(direction), 0.0)
		assert_between(model.bags[1].position.x, -10.0, 10.0)
		assert_between(model.bags[1].position.z, -4.9, 6.0)
	_throw(5, 7, ORIGIN, Vector3.RIGHT)
	# By 1.0 s this heavy bag is sliding after its small final rebound.
	sim.update(1.0)
	var previous_x: float = sim.bags[5].position.x
	sim.update(0.05)
	assert_gt(sim.bags[5].position.x, previous_x)
	sim.update(4.0)
	assert_eq(sim.bags[5].location, "floor")

func test_off_belt_flag_full_pickup_place_throw_cycle():
	assert_false(sim.bags[1].off_belt)
	sim.act(7, "pickup_bag", 1)
	assert_true(sim.bags[1].off_belt)
	sim.act(7, "place_bag", -1, {"location": "table"})
	assert_true(sim.bags[1].off_belt)
	sim.act(7, "pickup_bag", 1)
	# Existing belt-capacity rules still apply: make room before returning it.
	sim.act(8, "pickup_bag", 6)
	sim.act(8, "place_bag", -1, {"location": "floor", "position": Vector3(3, 0.04, 0)})
	sim.act(7, "place_bag", -1, {"location": "belt", "t": 0.0})
	assert_false(sim.bags[1].off_belt)
	_throw()
	assert_true(sim.bags[1].off_belt)

func test_two_distinct_peers_can_relay_midair_with_atomic_one_winner():
	_throw()
	sim.update(0.12)
	_in_reach()
	sim.add_player(9)
	_in_reach(9)
	sim.act(8, "catch_bag", 1)
	sim.act(9, "catch_bag", 1)
	assert_eq(sim.bags[1].held_by, 8)
	assert_eq(sim.players[9].held_kind, "")
	assert_eq(sim.bags[1].velocity, Vector3.ZERO)
	assert_eq(sim.catches, 1)
	var event: Dictionary = sim.catch_events[0]
	assert_eq(event.peer_id, 8)
	assert_eq(event.last_thrower, 7)
	assert_eq(event.bag_id, 1)
	assert_eq(event.mass_kg, 8.0)
	assert_gt(event.height, 0.12)
	assert_gte(event.flight_age, 0.08)
	var origin: Vector3 = sim.players[8].position + Vector3.UP * 0.95
	sim.act(8, "throw_bag", 1, {"origin": origin, "direction": Vector3.BACK})
	sim.update(0.12)
	_in_reach(7)
	sim.act(7, "catch_bag", 1)
	assert_eq(sim.bags[1].held_by, 7)
	assert_eq(sim.catches, 2)
	assert_eq(sim.catch_events[1].last_thrower, 8)
	assert_eq(sim.landings, 0)

func test_catch_rejects_too_young_far_occupied_low_floor_unknown_and_own_early():
	_throw()
	_in_reach()
	sim.act(8, "catch_bag", 1)
	assert_eq(sim.bags[1].location, "airborne")
	sim.update(0.1)
	_in_reach(7)
	sim.act(7, "catch_bag", 1)
	assert_eq(sim.bags[1].location, "airborne")
	sim.set_player_position(8, Vector3(8, 0.3, 5))
	sim.act(8, "catch_bag", 1)
	assert_eq(sim.bags[1].location, "airborne")
	_in_reach()
	sim.act(8, "pickup_bag", 2)
	sim.act(8, "catch_bag", 1)
	assert_eq(sim.bags[1].location, "airborne")
	sim.act(8, "place_bag", -1, {"location": "table"})
	var actual: Vector3 = sim.bags[1].position
	sim.bags[1].position.y = 0.1
	_in_reach()
	sim.act(8, "catch_bag", 1)
	assert_eq(sim.bags[1].location, "airborne")
	sim.bags[1].position = actual
	sim.act(8, "catch_bag", 999)
	sim.act(8, "pickup_bag", 1)
	assert_eq(sim.players[8].held_kind, "")
	sim.update(0.3)
	_in_reach(7)
	sim.act(7, "catch_bag", 1)
	assert_eq(sim.bags[1].held_by, 7)
	assert_eq(sim.catches, 1)
	sim.act(8, "catch_bag", 1)
	assert_eq(sim.catches, 1)

func test_invalid_throw_payload_and_wrong_owner_preserve_bag_cash_and_hands():
	sim.act(7, "pickup_bag", 1)
	var before: Dictionary = sim.bags.duplicate(true)
	var hands: Dictionary = sim.players.duplicate(true)
	for payload in [null, {}, {"origin": ORIGIN}, {"origin": ORIGIN, "direction": Vector3.ZERO}, {"origin": ORIGIN, "direction": Vector3(NAN, 0, 0)}, {"origin": Vector3(INF, 0, 0), "direction": Vector3.FORWARD}, {"origin": ORIGIN, "direction": Vector3.FORWARD * 2.0}, {"origin": Vector3(20, 1, 0), "direction": Vector3.FORWARD}, {"origin": ORIGIN, "direction": "forward"}]:
		sim.act(7, "throw_bag", 1, payload)
		assert_eq(sim.bags, before)
		assert_eq(sim.players, hands)
	sim.act(8, "throw_bag", 1, {"origin": ORIGIN, "direction": Vector3.FORWARD})
	sim.act(7, "throw_bag", 2, {"origin": ORIGIN, "direction": Vector3.FORWARD})
	assert_eq(sim.bags, before)
	assert_eq(sim.players, hands)
	assert_eq(sim.throws, 0)
	assert_eq(sim.money, 0)

func test_bag_throw_rejects_held_dog_item_and_pet_carrier():
	sim.act(7, "pickup_dog")
	sim.act(7, "throw_bag", -1, {"origin": ORIGIN, "direction": Vector3.FORWARD})
	assert_eq(sim.dog.location, "held")
	sim.act(7, "place_dog", -1, {"location": "floor", "position": Vector3.ZERO})
	_open(1)
	sim.act(7, "take_item", 1, 0)
	sim.act(7, "throw_bag", -1, {"origin": ORIGIN, "direction": Vector3.FORWARD})
	assert_eq(sim.players[7].held_kind, "item")
	sim.act(7, "drop_item", -1, Vector3.ZERO)
	sim.act(7, "pickup_bag", 4)
	sim.act(7, "throw_bag", 4, {"origin": ORIGIN, "direction": Vector3.FORWARD})
	assert_eq(sim.bags[4].location, "held")
	assert_eq(sim.bags[4].held_by, 7)
	assert_eq(sim.throws, 0)

func test_snapshot_flight_and_catch_roundtrip_are_deep_and_disconnect_is_safe():
	_throw()
	sim.update(0.12)
	var restored = Simulation.new()
	var state: Dictionary = bytes_to_var(var_to_bytes(sim.snapshot()))
	restored.apply_snapshot(state)
	assert_eq(restored.snapshot(), sim.snapshot())
	state.bags[1].velocity = Vector3.ONE
	assert_ne(restored.bags[1].velocity, Vector3.ONE)
	sim.update(0.1)
	restored.update(0.1)
	assert_eq(restored.snapshot(), sim.snapshot())
	_in_reach()
	sim.act(8, "catch_bag", 1)
	restored.apply_snapshot(bytes_to_var(var_to_bytes(sim.snapshot())))
	assert_eq(restored.snapshot(), sim.snapshot())
	restored.remove_player(8)
	assert_eq(restored.bags[1].location, "floor")
	assert_eq(restored.bags[1].held_by, 0)
	assert_eq(restored.bags[1].velocity, Vector3.ZERO)
	assert_eq(restored.bags[1].angular_velocity, Vector3.ZERO)
	assert_true(restored.bags[1].off_belt)
	var dropped = Simulation.new()
	dropped.apply_snapshot(restored.snapshot())
	assert_eq(dropped.snapshot(), restored.snapshot())

func test_snapshots_reject_invalid_physics_events_and_airborne_ownership_atomically():
	_throw()
	var original: Dictionary = sim.snapshot()
	for pair in [["mass_kg", -1.0], ["mass_kg", INF], ["velocity", Vector3(NAN, 0, 0)], ["rotation", Vector3(INF, 0, 0)], ["angular_velocity", "spin"], ["flight_age", -0.1], ["last_thrower", -7], ["held_by", 8], ["off_belt", false], ["location", "space"]]:
		var invalid: Dictionary = original.duplicate(true)
		invalid.bags[1][pair[0]] = pair[1]
		sim.apply_snapshot(invalid)
		assert_eq(sim.snapshot(), original)
	var invalid: Dictionary = original.duplicate(true)
	invalid.throw_events[0].velocity = Vector3(INF, 0, 0)
	sim.apply_snapshot(invalid)
	assert_eq(sim.snapshot(), original)
	invalid = original.duplicate(true)
	invalid.throws = -1
	sim.apply_snapshot(invalid)
	assert_eq(sim.snapshot(), original)

func test_physics_helper_recomputes_additive_mass_without_overwriting_shell():
	var legacy: Dictionary = {"size": 1, "items": [], "position": Vector3.ZERO}
	sim.ensure_bag_physics(legacy)
	assert_eq(legacy.mass_kg, 3.5)
	assert_eq(legacy.velocity, Vector3.ZERO)
	legacy.shell_mass_kg = 28.0
	legacy.mass_kg = 999.0 # Cached totals are not host truth.
	sim.ensure_bag_physics(legacy)
	assert_eq(legacy.shell_mass_kg, 28.0)
	assert_eq(legacy.mass_kg, 28.0)

func test_event_history_is_bounded_with_monotonic_serials():
	for index in range(70):
		sim.set_player_position(7, Vector3(0, 0.3, 0))
		_throw()
		sim.update(0.1)
		_in_reach()
		sim.act(8, "catch_bag", 1)
		sim.act(8, "place_bag", -1, {"location": "floor", "position": Vector3(0, 0.04, 0)})
	assert_eq(sim.throws, 70)
	assert_eq(sim.catches, 70)
	assert_eq(sim.throw_events.size(), 64)
	assert_eq(sim.catch_events.size(), 64)
	assert_eq(sim.throw_events[0].serial, 7)
	assert_eq(sim.catch_events.back().serial, 70)
	var restored = Simulation.new()
	restored.apply_snapshot(sim.snapshot())
	assert_eq(restored.snapshot(), sim.snapshot())

func test_landing_history_is_bounded_and_thrower_disconnect_does_not_cancel_flight():
	_throw(5)
	sim.remove_player(7)
	assert_eq(sim.bags[5].location, "airborne")
	sim.update(3.0)
	assert_eq(sim.landings, 1)
	sim.add_player(7)
	for index in range(65):
		sim.time_left = 240.0
		sim.set_player_position(7, Vector3(0, 0.3, 0))
		_throw(5)
		sim.update(3.0)
	assert_eq(sim.landings, 66)
	assert_eq(sim.landing_events.size(), 64)
	assert_eq(sim.landing_events[0].serial, 3)
	assert_eq(sim.landing_events.back().serial, 66)
	var restored = Simulation.new()
	restored.apply_snapshot(bytes_to_var(var_to_bytes(sim.snapshot())))
	assert_eq(restored.snapshot(), sim.snapshot())

func test_airborne_state_survives_real_reliable_enet_packet():
	_throw()
	sim.update(0.12)
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var started := false
	for port in range(19860, 19880):
		if server.create_server(port, 1) == OK:
			assert_eq(client.create_client("127.0.0.1", port), OK)
			started = true
			break
	assert_true(started)
	if not started:
		return
	for index in range(200):
		server.poll()
		client.poll()
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
		await get_tree().create_timer(0.01).timeout
	assert_eq(client.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	client.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	client.set_target_peer(1)
	assert_eq(client.put_packet(var_to_bytes(sim.snapshot())), OK)
	for index in range(200):
		client.poll()
		server.poll()
		if server.get_available_packet_count() > 0:
			break
		await get_tree().create_timer(0.01).timeout
	assert_gt(server.get_available_packet_count(), 0)
	if server.get_available_packet_count() > 0:
		var restored = Simulation.new()
		restored.apply_snapshot(bytes_to_var(server.get_packet()))
		assert_eq(restored.snapshot(), sim.snapshot())
		assert_eq(restored.bags[1].location, "airborne")
	client.close()
	server.close()
