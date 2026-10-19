extends GutTest

const Simulation = preload("res://scripts/airport/airport_simulation.gd")
var sim

func before_each():
	sim = Simulation.new()
	# This suite verifies known lifecycle/economy cases; production randomness is
	# covered by test_airport_core_expansion.gd, not overridden in the model.
	sim.set_fixture_mode()
	sim.add_player(7)

func _arrivals():
	sim.update(50.01)

func _open(id: int):
	sim.act(7, "tool", -1, 1 if sim.bags[id].lock == "approved" else 2)
	sim.act(7, "unlock", id)
	_complete_lock()
	sim.act(7, "open", id)
	assert_true(sim.bags[id].opened, "Inspection opened bag %d" % id)

func _complete_lock():
	if not sim.players[7].lock_game.is_empty():
		var sequence: Array = sim.players[7].lock_game.sequence.duplicate()
		for symbol in sequence:
			sim.act(7, "lock_input", -1, symbol)

func _scan_dog():
	sim.act(7, "pickup_dog")
	sim.act(7, "place_dog", -1, {"location": "belt", "t": 0.35})
	sim.update(1.6)
	assert_gt(sim.dog_scan_count, 0)
	sim.act(7, "pickup_dog")
	sim.act(7, "place_dog", -1, {"location": "floor", "position": Vector3(0, 0.3, 0)})

func _route(id: int, route: String = ""):
	_open(id)
	if sim.bags[id].carrier:
		sim.act(7, "feed_pet", id)
		assert_true(sim.bags[id].pet.fed)
	sim.bags[id].scanned = true
	sim.act(7, "pickup_bag", id)
	sim.act(7, "route", id, sim.expected_route(sim.bags[id]) if route == "" else route)

func test_initial_contract_and_immediate_arrival():
	assert_eq(sim.money, 0)
	assert_eq(sim.time_left, 240.0)
	assert_eq(sim.upgrades, {"scanner": 0, "kennel": 0, "evidence": 0, "bio_lab": 0, "belt": 0, "terminal": 0})
	assert_false(sim.next_shift())
	sim.update(0.01)
	assert_eq(sim.bags.size(), 1)
	assert_eq(sim.bags[1].location, "belt")
	assert_eq(sim.players[7].held_kind, "")

func test_arrival_scanner_fifo_queue_and_pause_conserve_all_bags():
	sim.update(8.1)
	assert_true(sim.bags[1].scanned)
	sim.update(80.0)
	assert_eq(sim.bags.size(), 6)
	var previous: float = 1.0
	for bag in sim.bags.values():
		assert_lte(bag.t, 0.72001)
		assert_lt(bag.t, previous)
		previous = bag.t
	sim.belt_running = false
	var frozen: Dictionary = sim.bags.duplicate(true)
	var arrival_left: float = sim._arrival_left
	sim.update(15.0)
	assert_eq(sim.bags.size(), frozen.size())
	assert_eq(sim._arrival_left, arrival_left)
	for id in frozen:
		assert_eq(sim.bags[id].t, frozen[id].t)
		assert_eq(sim.bags[id].position, frozen[id].position)
		assert_eq(sim.bags[id].scan_left, frozen[id].scan_left)
		assert_eq(sim.bags[id].items, frozen[id].items)
	assert_gt(sim.bags[4].pet.hunger, frozen[4].pet.hunger)
	assert_gt(sim.bags[4].pet.thirst, frozen[4].pet.thirst)
	sim.belt_running = true
	sim.act(7, "pickup_bag", 1)
	sim.update(0.1)
	assert_eq(sim.bags.size(), 7)
	assert_eq(sim.bags[1].location, "held")
	assert_eq(sim.bags[7].id, 7)

func test_templates_have_variety_and_all_three_organic_kinds():
	_arrivals()
	assert_eq(sim.bags.size(), 6)
	assert_eq(sim.bags[1].color, 0)
	assert_eq(sim.bags[1].lock, "approved")
	assert_eq(sim.bags[2].lock, "foreign")
	assert_eq(sim.bags[3].lock, "none")
	assert_eq(sim.bags[4].size, 2)
	assert_eq(sim.bags[4].category, "pet")
	assert_true(sim.bags[4].carrier)
	assert_eq(sim.bags[4].pet.species, "cat")
	assert_eq(sim.bags[5].flight, 1)
	assert_eq(sim.bags[6].category, "organic")
	var kinds: Array = []
	var ids: Array = []
	for bag in sim.bags.values():
		for item in bag.items:
			assert_false(ids.has(item.id))
			ids.append(item.id)
			if item.category == "organic":
				kinds.append(item.kind)
	for kind in ["fruit", "vegetable", "seeds"]:
		assert_has(kinds, kind)

func test_key_and_pliers_lock_rules():
	_arrivals()
	sim.act(7, "open", 1)
	assert_false(sim.bags[1].opened)
	sim.act(7, "unlock", 1)
	assert_false(sim.bags[1].unlocked)
	sim.act(7, "tool", -1, 1)
	sim.act(7, "unlock", 1)
	assert_false(sim.bags[1].unlocked)
	assert_eq(sim.players[7].key_durability, 7)
	assert_eq(sim.players[7].lock_game.sequence.size(), 3)
	_complete_lock()
	assert_true(sim.bags[1].unlocked)
	sim.act(7, "unlock", 2)
	assert_false(sim.bags[2].unlocked)
	sim.act(7, "tool", -1, 2)
	sim.act(7, "unlock", 2)
	assert_false(sim.bags[2].unlocked)
	assert_eq(sim.players[7].pliers_durability, 4)
	assert_eq(sim.players[7].lock_game.sequence.size(), 4)
	_complete_lock()
	assert_eq(sim.bags[2].lock, "cut")
	sim.act(7, "open", 2)
	assert_true(sim.bags[2].opened)
	assert_true(sim.bags[3].unlocked)

func test_bag_ownership_place_and_invalid_shapes():
	_arrivals()
	sim.add_player(8)
	sim.add_player(7)
	sim.act(7, "pickup_bag", 1)
	sim.act(8, "pickup_bag", 1)
	assert_eq(sim.bags[1].held_by, 7)
	assert_eq(sim.players[8].held_kind, "")
	sim.act(7, "pickup_bag", 2)
	assert_eq(sim.players[7].held_id, 1)
	for invalid in [null, "table", {"location": "sorted"}, {"location": "floor", "position": "oops"}]:
		sim.act(7, "place_bag", -1, invalid)
		assert_eq(sim.players[7].held_kind, "bag")
	sim.act(7, "place_bag", -1, {"location": "table"})
	assert_eq(sim.bags[1].location, "table")
	assert_eq(sim.bag_position(sim.bags[1]), Vector3(2, 1.15, 0))
	assert_eq(sim.players[7].held_kind, "")
	sim.act(7, "tool", -1, 99)
	assert_eq(sim.players[7].tool, 0)
	sim.act(7, "tool", -1, "1")
	assert_eq(sim.players[7].tool, 0)

func test_items_repack_into_any_open_bag_and_keep_unique_identity():
	_arrivals()
	sim.act(7, "take_item", 1, 0)
	assert_eq(sim.players[7].held_kind, "")
	_open(1)
	sim.act(7, "take_item", 1, 0)
	var item: Dictionary = sim.bags[1].items[0]
	var original_mass: float = sim.bags[1].shell_mass_kg + item.mass_kg + sim.bags[1].items[1].mass_kg
	assert_eq(sim.players[7].held_id, item.id)
	assert_eq(sim.bags[1].items.size(), 2)
	assert_almost_eq(sim.bags[1].mass_kg, original_mass - item.mass_kg, 0.00001)
	sim.act(7, "return_item", 2)
	assert_eq(item.location, "held")
	_open(2)
	var target_mass: float = sim.bags[2].mass_kg
	sim.act(7, "return_item", 2)
	assert_eq(item.location, "bag")
	assert_eq(sim.players[7].held_kind, "")
	assert_eq(sim.bags[1].items.size(), 1)
	assert_eq(sim.bags[2].items.size(), 3)
	assert_eq(sim.bags[2].items[2].id, item.id)
	assert_almost_eq(sim.bags[2].mass_kg, target_mass + item.mass_kg, 0.00001)
	sim.act(7, "take_item", 2, 2)
	sim.act(7, "drop_item", -1, Vector3(3, 0.2, 4))
	assert_eq(item.location, "floor")
	sim.act(7, "pickup_item", item.id)
	assert_eq(item.location, "held")
	assert_eq(sim.get_item(item.id), item)

func test_seizure_bonus_is_once_only_and_legal_adult_props_are_ordinary():
	_arrivals()
	_open(1)
	sim.act(7, "take_item", 1, 1)
	assert_eq(sim.get_item(sim.players[7].held_id).kind, "dildo")
	sim.act(7, "seize_item")
	assert_eq(sim.money, 0)
	assert_eq(sim.players[7].held_kind, "item")
	sim.act(7, "return_item", 1)
	_open(2)
	sim.act(7, "take_item", 2, 0)
	var id: int = sim.players[7].held_id
	sim.act(7, "seize_item")
	sim.act(7, "seize_item")
	assert_eq(sim.money, 8)
	assert_eq(sim.items_seized, 1)
	assert_eq(sim.get_item(id).location, "evidence")
	assert_true(sim.get_item(id).deposited)
	# Evidence remains in the item ledger, but no longer determines this bag's route.
	assert_eq(sim.bags[2].category, "legal")
	assert_eq(sim.expected_route(sim.bags[2]), "gate_b")
	sim.act(7, "pickup_item", id)
	assert_eq(sim.players[7].held_kind, "")
	assert_eq(sim.bags[5].items[0].kind, "vibrator")
	assert_eq(sim.bags[5].items[0].category, "legal")

func test_routing_requires_holding_scan_open_and_preserves_wrong_bag():
	_arrivals()
	sim.money = 5
	sim.act(7, "route", 2, "security")
	assert_eq(sim.handled, 0)
	sim.act(7, "pickup_bag", 2)
	sim.bags[2].scanned = false
	sim.act(7, "route", 2, "security")
	assert_eq(sim.handled, 0)
	sim.bags[2].scanned = true
	sim.act(7, "route", 2, "security")
	assert_eq(sim.handled, 0)
	_open(2)
	sim.act(7, "route", 2, "gate_b")
	assert_eq(sim.money, 0)
	assert_eq(sim.reputation, -1)
	assert_eq(sim.mistakes, 1)
	assert_eq(sim.players[7].held_id, 2)
	sim.act(7, "route", 2, "security")
	assert_eq(sim.money, 32)
	assert_eq(sim.narcotics, 1)
	assert_eq(sim.handled, 1)
	assert_eq(sim.correct, 1)
	assert_eq(sim.bags[2].location, "sorted")
	assert_eq(sim.players[7].held_kind, "")
	sim.act(7, "pickup_bag", 2)
	assert_eq(sim.players[7].held_kind, "")

func test_category_routes_override_flight_and_oversize_only_after_expansion():
	_arrivals()
	assert_eq(sim.expected_route(sim.bags[1]), "gate_a")
	assert_eq(sim.expected_route(sim.bags[2]), "security")
	assert_eq(sim.expected_route(sim.bags[3]), "bio")
	assert_eq(sim.expected_route(sim.bags[4]), "rescue")
	assert_eq(sim.expected_route(sim.bags[5]), "gate_b")
	var legal: Dictionary = sim.bags[1].duplicate(true)
	legal.size = 2
	assert_eq(sim.expected_route(legal), "gate_a")
	sim.airport_level = 2
	assert_eq(sim.expected_route(legal), "oversize")
	legal.size = 0
	legal.flight = 2
	assert_eq(sim.expected_route(legal), "gate_c")

func test_pet_rescue_requires_care_is_not_collectible_and_bonus_once():
	_arrivals()
	_open(4)
	sim.act(7, "take_item", 4, 0)
	assert_eq(sim.players[7].held_kind, "")
	assert_eq(sim.bags[4].items[0].kind, "pet_cat")
	sim.bags[4].scanned = true
	sim.act(7, "pickup_bag", 4)
	sim.act(7, "route", 4, "rescue")
	assert_eq(sim.rescues, 0)
	assert_eq(sim.money, 0)
	assert_eq(sim.players[7].held_id, 4)
	var food: int = sim.players[7].food
	var water: int = sim.players[7].water
	_route(4)
	assert_eq(sim.players[7].food, food - 1)
	assert_eq(sim.players[7].water, water - 1)
	assert_eq(sim.rescues, 1)
	assert_eq(sim.money, 95)
	assert_true(sim.contracts.rescue)
	sim.act(7, "route", 4, "rescue")
	assert_eq(sim.money, 95)

func test_organic_and_legal_milestones_only_once_and_bio_lab_bonus():
	_arrivals()
	_route(3)
	_route(6)
	assert_eq(sim.money, 115)
	assert_eq(sim.organics, 2)
	assert_true(sim.contracts.organic)
	_route(1)
	_route(5)
	# Free belt space creates the deterministic legal number seven.
	sim.update(10.0)
	assert_true(sim.bags.has(7))
	assert_true(sim.bags[7].items.any(func(item): return item.kind == "snacks" and item.category == "legal"))
	_route(7)
	assert_eq(sim.legals, 3)
	assert_true(sim.contracts.legal)
	assert_eq(sim.money, 199)
	sim.money = 70
	sim.act(7, "upgrade_bio_lab")
	sim.update(10.0)
	_route(8)
	assert_eq(sim.money, 60)

func test_dog_alerts_once_per_bag_false_positive_never_changes_category():
	_arrivals()
	sim.bags[2].location = "floor"
	sim.bags[2].position = Vector3(0, 0.3, 0)
	sim.dog.position = sim.bags[2].position
	sim.dog_goal = sim.dog.position
	for attempt in range(30):
		sim.dog.scent_left = 0.0
		sim._update_dog(0.001)
	assert_true(sim.bags[2].dog_alert)
	var alerts: int = sim.dog.alerts
	for attempt in range(30):
		sim.dog.scent_left = 0.0
		sim._update_dog(0.001)
	assert_eq(sim.dog.alerts, alerts)
	sim.bags[1].location = "floor"
	sim.bags[1].position = Vector3(8, 0.3, 0)
	sim.bags[1].items[0].kind = "snacks"
	sim.dog.position = sim.bags[1].position
	sim.dog_goal = sim.dog.position
	for attempt in range(60):
		sim.dog.scent_left = 0.0
		sim._update_dog(0.001)
	assert_true(sim.bags[1].dog_alert)
	assert_eq(sim.expected_route(sim.bags[1]), "gate_a")
	_route(1, "security")
	assert_eq(sim.money, 0)
	assert_eq(sim.mistakes, 1)

func test_kennel_range_training_and_floor_follow():
	_arrivals()
	_scan_dog()
	sim.bags[2].location = "floor"
	sim.bags[2].position = Vector3(4.5, 0.3, 0)
	sim.bags[2].dog_alert = false
	for attempt in range(30):
		sim.dog.scent_left = 0.0
		sim._update_dog(0.001)
	assert_false(sim.bags[2].dog_alert)
	sim.money = 35
	sim.act(7, "upgrade_kennel")
	assert_eq(sim.upgrades.kennel, 1)
	for attempt in range(30):
		sim.dog.scent_left = 0.0
		sim._update_dog(0.001)
	assert_true(sim.bags[2].dog_alert)
	sim.act(7, "call_dog", -1, Vector3(0, 0.3, 4))
	sim.update(1.0)
	assert_almost_eq(sim.dog.position.z, 1.8, 0.001)

func test_dog_carry_and_fictional_scanner_crossing_is_harmless_once():
	sim.add_player(8)
	sim.act(7, "pickup_dog")
	sim.act(8, "pickup_dog")
	assert_eq(sim.dog.held_by, 7)
	sim.act(7, "place_dog", -1, {"location": "belt", "t": 0.35})
	assert_eq(sim.players[7].held_kind, "")
	sim.update(1.6)
	assert_eq(sim.dog_scan_count, 1)
	assert_true(sim.dog.scanned)
	assert_string_contains(sim.last_event, "VERY GOOD BOY")
	sim.update(5.0)
	assert_eq(sim.dog_scan_count, 1)
	assert_eq(sim.dog.location, "floor")
	sim.act(7, "pickup_dog")
	sim.act(7, "place_dog", -1, {"location": "belt", "t": 0.35})
	assert_false(sim.dog.scanned)
	sim.update(1.6)
	assert_eq(sim.dog_scan_count, 2)

func test_all_upgrades_costs_single_purchase_and_terminal_prerequisites():
	var costs: Dictionary = {"scanner": 45, "kennel": 35, "evidence": 30, "bio_lab": 70, "belt": 55, "terminal": 120}
	for key in costs:
		sim.act(7, "upgrade_" + key)
		assert_eq(sim.upgrades[key], 0)
	sim.money = 1000
	# Money alone cannot buy training: earn the harmless scan prerequisite.
	sim.act(7, "upgrade_kennel")
	assert_eq(sim.upgrades.kennel, 0)
	assert_eq(sim.money, 1000)
	_scan_dog()
	sim.act(7, "upgrade_terminal")
	assert_eq(sim.upgrades.terminal, 0)
	sim.handled = 5
	sim.act(7, "upgrade_terminal")
	assert_eq(sim.upgrades.terminal, 0)
	sim.reputation = 5
	for key in costs:
		var before: int = sim.money
		sim.act(7, "upgrade_" + key)
		assert_eq(sim.money, before - costs[key])
		sim.act(7, "upgrade_" + key)
		assert_eq(sim.money, before - costs[key])
		assert_eq(sim.upgrades[key], 1)
	assert_eq(sim.airport_level, 2)
	assert_eq(sim.arrival_interval, 7.5)
	sim.update(10.0)
	assert_eq(sim.bags[2].flight, 2)
	assert_eq(sim.bags[2].category, "legal")
	assert_eq(sim.expected_route(sim.bags[2]), "gate_c")

func test_scanner_and_evidence_upgrades_have_real_effects():
	_arrivals()
	sim.money = 75
	sim.act(7, "upgrade_scanner")
	sim.act(7, "upgrade_evidence")
	# Isolate this bag at the scanner without teleporting it into the FIFO queue.
	for id in range(2, 7):
		sim.bags[id].location = "floor"
		sim.bags[id].position = Vector3(20, 0, 20)
	sim.bags[1].t = 0.449
	sim.bags[1].scanned = false
	sim.bags[1].scan_left = 0.0
	sim.update(0.4)
	assert_true(sim.bags[1].scanned)
	_open(2)
	sim.act(7, "take_item", 2, 0)
	sim.act(7, "seize_item")
	assert_eq(sim.money, 16)

func test_belt_upgrade_capacity_ten_and_active_unsorted_cap():
	sim.money = 55
	sim.act(7, "upgrade_belt")
	sim.update(150.0)
	assert_eq(sim.bags.size(), 10)
	sim.act(7, "pickup_bag", 1)
	sim.act(7, "place_bag", -1, {"location": "floor", "position": Vector3.ZERO})
	sim.update(10.0)
	assert_eq(sim.bags.size(), 10)
	_route(1)
	sim.update(0.1)
	assert_eq(sim.bags.size(), 11)
	assert_eq(sim.bags[1].location, "sorted")

func test_disconnect_releases_bag_item_dog_and_is_idempotent():
	_arrivals()
	for kind in ["bag", "item", "dog"]:
		sim.add_player(7)
		sim.players[7].position = Vector3(3, 0.3, 5)
		if kind == "bag":
			sim.act(7, "pickup_bag", 1)
		elif kind == "item":
			_open(2)
			sim.act(7, "take_item", 2, 0)
		else:
			sim.act(7, "pickup_dog")
		var id: int = sim.players[7].held_id
		sim.remove_player(7)
		sim.remove_player(7)
		var entity: Dictionary = sim.bags[id] if kind == "bag" else (sim.get_item(id) if kind == "item" else sim.dog)
		assert_eq(entity.location, "floor")
		assert_eq(entity.held_by, 0)
		assert_eq(entity.position, Vector3(3, 0.3, 5))

func test_snapshot_is_deep_restores_integer_keys_vectors_and_continuation():
	_arrivals()
	var state: Dictionary = sim.snapshot()
	state.bags[1].items[0].label = "copy"
	assert_ne(sim.bags[1].items[0].label, "copy")
	state = sim.snapshot()
	state.bags["1"] = state.bags[1]
	state.bags.erase(1)
	state.players["7"] = state.players[7]
	state.players.erase(7)
	var restored = Simulation.new()
	restored.apply_snapshot(state)
	assert_true(restored.bags.has(1))
	assert_true(restored.players.has(7))
	assert_typeof(restored.bags[1].position, TYPE_VECTOR3)
	assert_eq(restored.snapshot(), sim.snapshot())
	state.bags["1"].items[0].label = "mutated"
	assert_ne(restored.bags[1].items[0].label, "mutated")
	sim.update(1.0)
	restored.update(1.0)
	assert_eq(restored.snapshot(), sim.snapshot())

func test_invalid_actions_and_snapshot_fail_closed():
	sim.update(0.01)
	for action in ["pickup_bag", "open", "unlock", "pickup_item", "take_item", "route"]:
		sim.act(7, action, 999999, "bad")
	assert_eq(sim.money, 0)
	assert_eq(sim.players[7].held_kind, "")
	var state: Dictionary = sim.snapshot()
	sim.apply_snapshot({"bags": {"bad": {"location": "evil"}}})
	assert_eq(sim.snapshot(), state)
	sim.update(-1.0)
	sim.update(NAN)
	assert_eq(sim.snapshot(), state)

func test_shift_freezes_and_next_shift_preserves_progress_and_held_objects():
	sim.update(0.01)
	sim.act(7, "pickup_bag", 1)
	sim.money = 123
	sim.time_left = 0.2
	sim.update(4.0)
	assert_true(sim.shift_finished)
	assert_eq(sim.time_left, 0.0)
	var frozen: Dictionary = sim.snapshot()
	sim.update(50.0)
	assert_eq(sim.snapshot(), frozen)
	sim.act(7, "place_bag", -1, {"location": "table"})
	assert_eq(sim.bags[1].location, "held")
	assert_true(sim.next_shift())
	assert_eq(sim.day, 2)
	assert_eq(sim.time_left, 240.0)
	assert_eq(sim.money, 123)
	assert_eq(sim.players[7].held_id, 1)
	assert_false(sim.next_shift())

func test_arrival_and_scanner_timing_are_frame_partition_independent():
	var other = Simulation.new()
	other.set_fixture_mode()
	other.add_player(7)
	sim.update(23.3)
	for index in range(233):
		other.update(0.1)
	assert_eq(sim.bags.size(), 3)
	assert_eq(other.bags.size(), 3)
	for id in sim.bags:
		assert_almost_eq(sim.bags[id].t, other.bags[id].t, 0.00001)
		assert_eq(sim.bags[id].scanned, other.bags[id].scanned)
		assert_eq(sim.bags[id].items, other.bags[id].items)
	assert_almost_eq(sim.time_left, other.time_left, 0.00001)

func test_paused_belt_freezes_partial_scans_dog_and_arrival_clock():
	sim.update(7.2)
	assert_gt(sim.bags[1].scan_left, 0.0)
	sim.act(7, "pickup_dog")
	sim.act(7, "place_dog", -1, {"location": "belt", "t": 0.35})
	sim.belt_running = false
	var t: float = sim.dog.t
	var scan_left: float = sim.bags[1].scan_left
	sim.update(12.0)
	assert_eq(sim.bags.size(), 1)
	assert_eq(sim.dog.t, t)
	assert_eq(sim.bags[1].scan_left, scan_left)
	sim.belt_running = true
	sim.update(2.9)
	assert_eq(sim.bags.size(), 2)
	assert_true(sim.bags[1].scanned)

func test_kennel_reduces_but_does_not_eliminate_probabilistic_false_positives():
	_arrivals()
	_scan_dog()
	sim.belt_running = false
	for id in range(1, 7):
		sim.bags[id].location = "floor"
		sim.bags[id].position = Vector3(0, 0.3, 0)
	sim.bags[1].items[0].kind = "snacks"
	sim.dog.position = Vector3(0, 0.3, 0)
	sim.dog_goal = sim.dog.position
	var untrained: Dictionary = {}
	var trained: Dictionary = {}
	for training in range(2):
		if training == 1:
			sim.money = 35
			sim.act(7, "upgrade_kennel")
			assert_eq(sim.upgrades.kennel, 1)
			sim.dog.xp = 100
		for id in sim.bags:
			(untrained if training == 0 else trained)[id] = 0
		for trial in range(200):
			# Paired seeds sample the same rolls with different training thresholds.
			sim.set_seed(1000 + trial)
			sim.dog.scent_left = 0.0
			for bag in sim.bags.values():
				bag.dog_alert = false
			sim._update_dog(0.001)
			for id in sim.bags:
				if sim.bags[id].dog_alert:
					(untrained if training == 0 else trained)[id] += 1
	for id in [1, 5]:
		assert_gt(trained[id], 0, "Training is not certainty for legal bag %d" % id)
		assert_lt(trained[id], untrained[id])
		assert_eq(sim.bags[id].category, "legal")
	for id in [2, 3, 4, 6]:
		assert_gt(trained[id], untrained[id])
		assert_lt(trained[id], 200, "Even trained dogs can miss bag %d" % id)

func test_repeated_milestones_do_not_pay_twice_and_sorted_data_survives():
	_arrivals()
	for id in [1, 2, 3, 4, 5, 6]:
		_route(id)
	assert_eq(sim.money, 278)
	for id in [7, 8, 9, 10, 11]:
		sim.update(10.0)
		_route(id)
	assert_eq(sim.money, 456)
	assert_eq(sim.legals, 4)
	assert_eq(sim.organics, 4)
	assert_eq(sim.bags.size(), 11)
	for bag in sim.bags.values():
		assert_eq(bag.location, "sorted")
		assert_gt(bag.items.size(), 0)

func test_snapshot_rejects_invalid_enums_shapes_and_dangling_ownership_atomically():
	sim.update(0.1)
	var original: Dictionary = sim.snapshot()
	var bad: Dictionary = original.duplicate(true)
	bad.bags[1].location = "deleted"
	sim.apply_snapshot(bad)
	assert_eq(sim.snapshot(), original)
	bad = original.duplicate(true)
	bad.bags[1].items[0].position = "bad"
	sim.apply_snapshot(bad)
	assert_eq(sim.snapshot(), original)
	bad = original.duplicate(true)
	bad.players[7].held_kind = "bag"
	bad.players[7].held_id = 999
	sim.apply_snapshot(bad)
	assert_eq(sim.snapshot(), original)
	bad = original.duplicate(true)
	bad.dog.location = "evidence"
	sim.apply_snapshot(bad)
	assert_eq(sim.snapshot(), original)
	bad = original.duplicate(true)
	bad.bags[1].items[1].id = bad.bags[1].items[0].id
	sim.apply_snapshot(bad)
	assert_eq(sim.snapshot(), original)

func test_snapshot_real_enet_packet_roundtrip():
	_arrivals()
	_route(1)
	_open(2)
	sim.act(7, "take_item", 2, 0)
	sim.act(7, "seize_item")
	sim.act(7, "pickup_dog")
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var started := false
	for port in range(19840, 19860):
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
	# Client sends a reliable snapshot; ENet fragments this full state as needed.
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
		var received: Dictionary = bytes_to_var(server.get_packet())
		var restored = Simulation.new()
		restored.apply_snapshot(received)
		assert_eq(restored.snapshot(), sim.snapshot())
		assert_typeof(restored.bags[1].position, TYPE_VECTOR3)
		assert_true(restored.players.has(7))
	client.close()
	server.close()
