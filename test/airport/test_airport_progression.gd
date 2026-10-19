extends GutTest
const Simulation = preload("res://scripts/airport/airport_simulation.gd")

func test_console_pause_and_resume_preserve_intake_and_scan_progress():
	var sim = Simulation.new()
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
	sim.add_player(1)
	sim.update(50.01)
	for id in range(1,6):
		sim.bags[id].location="sorted"
	sim.money=120
	sim.handled=5
	sim.reputation=5
	sim.act(1,"upgrade_terminal")
	sim.update(10)
	assert_eq(sim.bags[7].flight,2)
	assert_eq(sim.expected_route(sim.bags[7]),"gate_c")
	sim.update(10)
	assert_true(sim.bags.has(8))
	assert_eq(sim.bags[8].category,"legal")
	assert_eq(sim.bags[8].size,2)
	assert_eq(sim.bags[8].kind,3)
	assert_eq(sim.expected_route(sim.bags[8]),"oversize")
