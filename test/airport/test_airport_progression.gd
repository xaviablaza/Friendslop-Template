extends GutTest
const Simulation = preload("res://scripts/airport/airport_simulation.gd")

func test_console_pause_and_resume_preserve_intake_and_scan_progress():
	var sim = Simulation.new()
	sim.set_fixture_mode()
	sim.add_player(1)
	sim.update(3)
	var before = sim.bags.duplicate(true)
	sim.act(1,"toggle_belt")
	assert_false(sim.belt_running)
	sim.update(5)
	assert_eq(sim.bags,before)
	sim.act(1,"toggle_belt")
	assert_true(sim.belt_running)
	sim.update(6)
	assert_true(sim.bags[1].scanned)

func test_terminal_unlocks_generated_oversize_contract_after_first_flight_c():
	var sim = Simulation.new()
	sim.set_fixture_mode()
	sim.add_player(1)
	sim.update(50.01)
	# Earn the terminal prerequisites through real inspection and routing.
	for id in range(1, 6):
		sim.act(1, "tool", -1, 1 if sim.bags[id].lock == "approved" else 2)
		sim.act(1, "unlock", id)
		if not sim.players[1].lock_game.is_empty():
			var sequence: Array = sim.players[1].lock_game.sequence.duplicate()
			for symbol in sequence:
				sim.act(1, "lock_input", id, symbol)
		sim.act(1, "open", id)
		assert_true(sim.bags[id].inspected)
		if sim.bags[id].carrier:
			sim.act(1, "feed_pet", id)
		sim.act(1, "pickup_bag", id)
		if not sim.bags[id].scanned:
			# Later FIFO bags have not reached the scanner at the initial stop.
			sim.act(1, "place_bag", -1, {"location": "belt", "t": 0.45})
			sim.update(1.1)
			assert_true(sim.bags[id].scanned)
			sim.act(1, "pickup_bag", id)
		sim.act(1, "route", id, sim.expected_route(sim.bags[id]))
		assert_eq(sim.bags[id].location, "sorted")
	assert_eq(sim.handled, 5)
	assert_eq(sim.reputation, 5)
	var earned: int = sim.money
	sim.act(1,"upgrade_terminal")
	assert_eq(sim.upgrades.terminal, 1)
	assert_eq(sim.money, earned - 120)
	sim.update(10)
	assert_eq(sim.bags[7].flight,2)
	assert_eq(sim.expected_route(sim.bags[7]),"gate_c")
	sim.update(10)
	assert_true(sim.bags.has(8))
	assert_eq(sim.bags[8].category,"legal")
	assert_eq(sim.bags[8].size,2)
	assert_eq(sim.bags[8].kind,3)
	assert_eq(sim.expected_route(sim.bags[8]),"oversize")
