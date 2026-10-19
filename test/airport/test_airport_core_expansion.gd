extends GutTest

const Simulation = preload("res://scripts/airport/airport_simulation.gd")
const Catalog = preload("res://scripts/airport/airport_catalog.gd")
var sim

func before_each():
	sim = Simulation.new()
	sim.set_seed(81234)
	sim.add_player(7)

func _fixtures():
	sim.set_fixture_mode()
	sim.update(50.01)
	sim.belt_running = false

func _open(id: int):
	sim.act(7, "tool", -1, 2)
	sim.act(7, "unlock", id)
	if not sim.players[7].lock_game.is_empty():
		var sequence: Array = sim.players[7].lock_game.sequence.duplicate()
		for symbol in sequence:
			sim.act(7, "lock_input", id, symbol)
	sim.act(7, "open", id)

func _roundtrip(state: Dictionary):
	var restored = Simulation.new()
	restored.apply_snapshot(bytes_to_var(var_to_bytes(state)))
	return restored

func test_default_random_arrivals_seed_reproducible_and_fixture_is_opt_in():
	assert_false(sim.fixture_mode)
	var other = Simulation.new()
	other.set_seed(81234)
	other.add_player(7)
	sim.update(23.3)
	other.update(23.3)
	assert_eq(sim.snapshot(), other.snapshot())
	var different = Simulation.new()
	different.set_seed(99)
	different.update(23.3)
	assert_ne(sim.bags, different.bags)
	assert_eq(sim.bags.size(), 3)

func test_catalogue_explicit_complete_taxonomy_and_probabilistic_truth():
	var categories: Array = []
	var legal_lookalikes: int = 0
	var actual_restricted: int = 0
	var weights: Array = []
	for spec in Catalog.ENTRIES:
		if spec.category not in categories:
			categories.append(spec.category)
		assert_ne(spec.kind, "adult_silhouette")
	for category in ["legal", "narcotics", "organic", "weapons", "explosives", "dangerous", "wildlife", "customs", "pet"]:
		assert_has(categories, category)
	for index in range(100):
		var item: Dictionary = Catalog.instantiate(Catalog.entry("narcotics"), sim.rng, index + 1)
		weights.append(item.mass_kg)
		if item.category == "legal":
			legal_lookalikes += 1
		else:
			actual_restricted += 1
	assert_gt(legal_lookalikes, 0)
	assert_gt(actual_restricted, 0)
	assert_ne(weights.min(), weights.max())

func test_random_generation_can_spawn_every_current_category_and_real_pet_species():
	var categories: Array = []
	for id in range(1, 301):
		var bag: Dictionary = sim._random_bag(id)
		sim.ensure_bag_physics(bag)
		for item in bag.items:
			if item.category not in categories:
				categories.append(item.category)
			assert_ne(item.kind, "adult_silhouette")
		if bag.carrier:
			assert_has(["cat", "rabbit", "cloud_lizard"], bag.pet.species)
	for category in ["legal", "narcotics", "organic", "weapons", "explosives", "dangerous", "wildlife", "customs", "pet"]:
		assert_has(categories, category)

func test_peer_snapshots_redact_uninspected_truth_even_when_scanned():
	_fixtures()
	sim.bags[2].scanned = true
	var peer: Dictionary = sim.snapshot_for(7)
	assert_false(peer.has("_rng_seed"))
	assert_false(peer.has("_rng_state"))
	assert_eq(peer.bags[2].category, "unknown")
	for bag in peer.bags.values():
		assert_false(bag.has("truth"))
		for item in bag.items:
			assert_false(item.has("truth"))
			assert_eq(item.kind, "unknown")
			assert_eq(item.category, "unknown")
			assert_eq(item.label, "Uninspected item")
	var restored = _roundtrip(peer)
	assert_eq(restored.bags, peer.bags)
	assert_eq(restored.players, peer.players)
	assert_eq(sim.bags[2].items[0].category, "narcotics")
	assert_true(sim.snapshot().bags[2].items[0].has("truth"))
	_open(2)
	sim.act(7, "close", 2)
	peer = sim.snapshot_for(7)
	assert_eq(peer.bags[2].items[0].kind, "narcotics")
	assert_eq(peer.bags[2].category, "narcotics")
	assert_false(peer.bags[2].items[0].has("truth"))
	assert_eq(_roundtrip(peer).bags, peer.bags)

func test_full_snapshot_restores_rng_and_next_random_arrival_exactly():
	sim.update(12.1)
	var restored = _roundtrip(sim.snapshot())
	assert_eq(restored.snapshot(), sim.snapshot())
	sim.update(12.3)
	restored.update(12.3)
	assert_eq(restored.snapshot(), sim.snapshot())

func test_timed_lock_sequence_durability_wrong_input_timeout_and_restock():
	_fixtures()
	sim.act(7, "tool", -1, 1)
	sim.act(7, "unlock", 1)
	assert_false(sim.bags[1].unlocked)
	assert_eq(sim.players[7].key_durability, 7)
	assert_eq(sim.players[7].lock_game.sequence.size(), 3)
	var state: Dictionary = sim.snapshot()
	assert_eq(_roundtrip(state).snapshot(), state)
	var wrong: int = (int(sim.players[7].lock_game.sequence[0]) + 1) % 3
	sim.act(7, "lock_input", 1, wrong)
	assert_true(sim.players[7].lock_game.is_empty())
	assert_false(sim.bags[1].unlocked)
	sim.act(7, "unlock", 1)
	sim.update(8.0)
	assert_true(sim.players[7].lock_game.is_empty())
	assert_false(sim.bags[1].unlocked)
	_open(1)
	assert_true(sim.bags[1].opened)
	assert_eq(sim.players[7].pliers_durability, 4)
	sim.players[7].pliers_durability = 0
	sim.act(7, "unlock", 2)
	assert_true(sim.players[7].lock_game.is_empty())
	sim.money = 12
	sim.act(7, "restock_tools")
	assert_eq(sim.money, 0)
	assert_eq(sim.players[7].pliers_durability, 5)
	assert_eq(sim.players[7].key_durability, 8)

func test_shift_end_cancels_lock_challenges_without_refunding_consumables():
	_fixtures()
	sim.act(7, "tool", -1, 1)
	sim.act(7, "unlock", 1)
	assert_false(sim.players[7].lock_game.is_empty())
	var remaining_uses: int = sim.players[7].key_durability
	sim.time_left = 0.05
	sim.update(0.1)
	assert_true(sim.shift_finished)
	assert_true(sim.players[7].lock_game.is_empty())
	assert_eq(sim.players[7].key_durability, remaining_uses)
	assert_false(sim.bags[1].unlocked)
	assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())
	assert_true(sim.next_shift())
	assert_eq(sim.day, 2)
	sim.act(7, "unlock", 1)
	assert_false(sim.players[7].lock_game.is_empty())

func test_foreign_locks_reject_key_and_tool_change_does_not_cheat_challenge():
	_fixtures()
	sim.act(7, "tool", -1, 1)
	sim.act(7, "unlock", 2)
	assert_eq(sim.players[7].key_durability, 8)
	assert_true(sim.players[7].lock_game.is_empty())
	sim.act(7, "tool", -1, 2)
	sim.act(7, "unlock", 2)
	var sequence: Array = sim.players[7].lock_game.sequence.duplicate()
	sim.act(7, "tool", -1, 0)
	for symbol in sequence:
		sim.act(7, "lock_input", 2, symbol)
	assert_eq(sim.bags[2].lock, "cut")
	assert_true(sim.bags[2].unlocked)
	assert_eq(sim.players[7].pliers_durability, 4)

func test_close_relock_consumes_seal_and_retains_inspection():
	_fixtures()
	_open(1)
	sim.act(7, "relock", 1)
	assert_true(sim.bags[1].unlocked)
	sim.act(7, "close", 1)
	sim.act(7, "relock", 1)
	assert_eq(sim.players[7].seals, 2)
	assert_false(sim.bags[1].unlocked)
	assert_false(sim.bags[1].opened)
	assert_true(sim.bags[1].inspected)
	sim.act(7, "open", 1)
	assert_false(sim.bags[1].opened)

func test_additive_mass_and_arbitrary_repacking_preserve_unique_item_and_truth():
	_fixtures()
	_open(1)
	_open(2)
	var item: Dictionary = sim.bags[2].items[0]
	var truth: Dictionary = item.truth.duplicate(true)
	var source_mass: float = sim.bags[2].mass_kg
	var target_mass: float = sim.bags[1].mass_kg
	sim.act(7, "take_item", 2, 0)
	assert_almost_eq(sim.bags[2].mass_kg, source_mass - item.mass_kg, 0.00001)
	sim.act(7, "return_item", 1)
	assert_eq(item.location, "bag")
	assert_eq(sim.bags[2].items.size(), 1)
	assert_eq(sim.bags[1].items.size(), 3)
	assert_almost_eq(sim.bags[1].mass_kg, target_mass + item.mass_kg, 0.00001)
	assert_eq(sim.bags[1].category, "narcotics")
	assert_eq(sim.bags[2].category, "legal")
	assert_eq(item.truth, truth)
	assert_eq(sim.get_item(item.id), item)
	assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())

func test_disposal_accepts_only_three_danger_categories_once_and_removes_mass():
	_fixtures()
	_open(1)
	sim.act(7, "take_item", 1, 0)
	sim.act(7, "dispose_item")
	assert_eq(sim.players[7].held_kind, "item")
	assert_eq(sim.money, 0)
	sim.act(7, "return_item", 1)
	for kind in ["weapon_prop", "explosive_prop", "hazard_canister"]:
		var item: Dictionary = Catalog.instantiate(Catalog.entry(kind), sim.rng, sim._next_item_id, true)
		sim._next_item_id += 1
		sim.bags[1].items.append(item)
		sim.ensure_bag_physics(sim.bags[1])
		sim.act(7, "take_item", 1, sim.bags[1].items.size() - 1)
		sim.act(7, "dispose_item")
		assert_eq(item.location, "disposed")
		assert_true(item.deposited)
		sim.act(7, "dispose_item")
	assert_eq(sim.items_seized, 3)
	assert_eq(sim.money, 30)
	assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())

func test_pet_carrier_hungry_route_requires_food_water_and_no_animal_throw():
	_fixtures()
	_open(4)
	var pet: Dictionary = sim.bags[4].pet
	assert_eq(pet.species, "cat")
	sim.act(7, "take_item", 4, 0)
	assert_eq(sim.players[7].held_kind, "")
	sim.bags[4].scanned = true
	sim.act(7, "pickup_bag", 4)
	sim.act(7, "route", 4, "rescue")
	assert_eq(sim.handled, 0)
	sim.act(7, "throw_bag", 4, {"origin": Vector3(0, 1, 0), "direction": Vector3.FORWARD})
	assert_eq(sim.bags[4].location, "held")
	var food: int = sim.players[7].food
	var water: int = sim.players[7].water
	sim.act(7, "feed_pet", 4)
	assert_eq(sim.players[7].food, food - 1)
	assert_eq(sim.players[7].water, water - 1)
	assert_true(pet.fed)
	sim.act(7, "feed_pet", 4)
	assert_eq(sim.players[7].food, food - 1)
	sim.act(7, "route", 4, "rescue")
	assert_eq(sim.rescues, 1)
	assert_eq(sim.bags[4].location, "sorted")
	assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())

func test_pet_care_missing_portion_is_atomic_and_needs_increase_without_harm():
	_fixtures()
	_open(4)
	sim.players[7].water = 0
	var food: int = sim.players[7].food
	var hunger: float = sim.bags[4].pet.hunger
	sim.act(7, "feed_pet", 4)
	assert_eq(sim.players[7].food, food)
	assert_false(sim.bags[4].pet.fed)
	sim.update(1)
	assert_gt(sim.bags[4].pet.hunger, hunger)
	assert_false(sim.bags[4].pet.has("health"))

func test_kennel_requires_earned_money_and_harmless_scan_count_with_xp():
	sim.money = 35
	sim.act(7, "upgrade_kennel")
	assert_eq(sim.upgrades.kennel, 0)
	assert_eq(sim.money, 35)
	sim.act(7, "pickup_dog")
	sim.act(7, "place_dog", -1, {"location": "belt", "t": 0.35})
	sim.update(1.6)
	assert_eq(sim.dog_scan_count, 1)
	assert_eq(sim.dog.xp, 10)
	sim.act(7, "upgrade_kennel")
	assert_eq(sim.upgrades.kennel, 1)
	assert_eq(sim.money, 0)

func test_extended_item_and_dog_flight_snapshots_continue_without_hidden_rng_leak():
	_fixtures()
	_open(1)
	sim.act(7, "take_item", 1, 0)
	var item_id: int = sim.players[7].held_id
	sim.act(7, "throw_item", item_id, {"origin": Vector3(0, 1, 0), "direction": Vector3.FORWARD})
	sim.act(7, "pickup_dog")
	sim.act(7, "throw_dog", -1, {"origin": Vector3(0, 1, 0), "direction": Vector3.FORWARD})
	assert_eq(sim.dog.location, "airborne")
	assert_eq(sim.get_item(item_id).location, "airborne")
	var restored = _roundtrip(sim.snapshot())
	assert_eq(restored.snapshot(), sim.snapshot())
	var peer: Dictionary = sim.snapshot_for(7)
	assert_eq(_roundtrip(peer).bags, peer.bags)
	sim.update(2)
	restored.update(2)
	assert_eq(restored.snapshot(), sim.snapshot())
	assert_eq(sim.dog.location, "floor")

func test_snapshot_validation_rejects_extended_state_atomically():
	_fixtures()
	var original: Dictionary = sim.snapshot()
	var corruptions: Array = [
		["player", "health", NAN], ["player", "stamina", -1.0], ["player", "food", 99],
		["player", "key_durability", -1], ["player", "carry_partner", 99],
		["bag", "damage", 101.0], ["bag", "shell_mass_kg", -1.0], ["bag", "mass_kg", 44.0],
		["bag", "carry_helpers", [99]], ["bag", "pet", {"species":"human"}],
		["item", "mass_kg", 0.0], ["item", "velocity", Vector3(INF, 0, 0)],
		["item", "flight_age", -1.0], ["dog", "hunger", -1.0], ["dog", "mode", "attack"]
	]
	for corruption in corruptions:
		var bad: Dictionary = original.duplicate(true)
		var target: Dictionary
		match corruption[0]:
			"player": target = bad.players[7]
			"bag": target = bad.bags[1]
			"item": target = bad.bags[1].items[0]
			"dog": target = bad.dog
		target[corruption[1]] = corruption[2]
		sim.apply_snapshot(bad)
		assert_eq(sim.snapshot(), original, str(corruption))
	var peer: Dictionary = sim.snapshot_for(7)
	peer.bags[1].items[0].truth = original.bags[1].items[0].truth
	sim.apply_snapshot(peer)
	assert_eq(sim.snapshot(), original)

func test_heavy_carry_multiplier_helper_snapshot_and_disconnect_cleanup():
	_fixtures()
	sim.add_player(8)
	sim.bags[1].shell_mass_kg = 30.0
	sim.ensure_bag_physics(sim.bags[1])
	sim.act(7, "pickup_bag", 1)
	assert_eq(sim.carry_speed(7), 0.0)
	sim.act(8, "join_carry", 1)
	assert_gt(sim.carry_speed(7), 0.0)
	assert_eq(sim.bags[1].carry_helpers, [8])
	assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())
	sim.remove_player(8)
	assert_eq(sim.bags[1].location, "floor")
	assert_eq(sim.players[7].held_kind, "")
	assert_eq(sim.players[7].carry_partner, 0)
	assert_eq(sim.bags[1].carry_helpers, [])
	assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())

func test_recipient_carry_speed_is_read_only_and_never_reconstructs_truth():
	_fixtures()
	sim.act(7, "pickup_bag", 2)
	var peer: Dictionary = sim.snapshot_for(7)
	var view = _roundtrip(peer)
	var before: Dictionary = view.bags.duplicate(true)
	assert_gt(view.carry_speed(7), 0.0)
	assert_eq(view.bags, before)
	assert_eq(view.bags[2].category, "unknown")
	assert_false(view.bags[2].has("truth"))

func test_seeded_random_shift_action_loop_keeps_full_and_redacted_snapshots_valid():
	for index in range(12):
		if sim.players[7].pliers_durability == 0:
			sim.act(7, "restock_tools")
		sim.belt_running = true
		sim.update(10.01)
		var id: int = index + 1
		if not sim.bags.has(id):
			fail_test("Missing randomized arrival %d" % id)
			return
		sim.belt_running = false
		_open(id)
		var bag: Dictionary = sim.bags[id]
		if bag.carrier:
			sim.set_player_position(7, Vector3(-7.5, 0.5, 0.5))
			sim.act(7, "take_food")
			sim.act(7, "take_water")
			sim.act(7, "feed_pet", id)
		for item_index in range(bag.items.size()):
			var item: Dictionary = bag.items[item_index]
			if item.category in ["narcotics", "organic", "customs"] or item.category in Catalog.DISPOSAL_CATEGORIES:
				sim.act(7, "take_item", id, item_index)
				sim.act(7, "dispose_item" if item.category in Catalog.DISPOSAL_CATEGORIES else "seize_item")
		assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())
		var peer: Dictionary = sim.snapshot_for(7)
		assert_eq(_roundtrip(peer).bags, peer.bags)
		sim.act(7, "pickup_bag", id)
		if not bag.scanned:
			sim.act(7, "place_bag", -1, {"location":"belt", "t":0.45})
			sim.belt_running = true
			sim.update(1.1)
			sim.belt_running = false
			sim.act(7, "pickup_bag", id)
		sim.act(7, "route", id, sim.expected_route(bag))
		assert_eq(bag.location, "sorted", "Randomized case %d" % id)
		assert_eq(_roundtrip(sim.snapshot()).snapshot(), sim.snapshot())
	assert_eq(sim.handled, 12)

func test_redacted_snapshot_real_reliable_enet_packet_roundtrip():
	_fixtures()
	_open(1)
	sim.act(7, "take_item", 1, 0)
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var started: bool = false
	for port in range(20140, 20160):
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
	var state: Dictionary = sim.snapshot_for(7)
	client.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	client.set_target_peer(1)
	assert_eq(client.put_packet(var_to_bytes(state)), OK)
	for index in range(200):
		client.poll()
		server.poll()
		if server.get_available_packet_count() > 0:
			break
		await get_tree().create_timer(0.01).timeout
	assert_gt(server.get_available_packet_count(), 0)
	if server.get_available_packet_count() > 0:
		var received: Dictionary = bytes_to_var(server.get_packet())
		var restored = _roundtrip(received)
		assert_eq(restored.snapshot_for(7), state)
		assert_false(received.has("_rng_state"))
		assert_eq(received.bags[2].items[0].category, "unknown")
	client.close()
	server.close()
